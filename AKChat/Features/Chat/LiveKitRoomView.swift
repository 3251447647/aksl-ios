import SwiftUI
import LiveKit
import UIKit

/// LiveKit 视频轨渲染（群通话宫格 / 直播间画面共用）。
/// refreshToken 变化时把渲染器重新挂到轨道上：回前台或重新订阅后，
/// 旧渲染视图可能停在最后一帧，只重设同一个 track 不会触发新的关键帧。
struct LiveKitVideoTile: UIViewRepresentable {
    let track: VideoTrack
    var refreshToken: Int = 0
    /// 首帧后卡住时自动重挂渲染器（直播间开启，群通话不开启避免多路重复重挂）
    var recoversFromStall: Bool = false
    /// 回前台是否由渲染视图自己重挂。直播间由 LiveRoomView 先重连再重建，
    /// 这里必须关掉，否则旧轨会在重连完成前先被挂回去。
    var observesForeground: Bool = true

    final class Coordinator {
        var token = Int.min
        var track: VideoTrack?
        weak var view: LiveKit.VideoView?
        var monitor: Task<Void, Never>?
        private var activeObserver: NSObjectProtocol?

        deinit {
            monitor?.cancel()
            if let activeObserver {
                NotificationCenter.default.removeObserver(activeObserver)
            }
        }

        /// iOS 回前台后渲染器可能停在最后一帧：把 track 先摘掉再挂回，强制要新关键帧。
        /// 群通话与直播间共用这个视图，所以放在这里统一处理。
        func startForegroundRefresh() {
            guard activeObserver == nil else { return }
            activeObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.reattach() }
            }
        }

        func reattach() {
            // 不在窗口上时不能摘 track，否则可能一直挂不回去
            guard let view, let track, view.window != nil else { return }
            view.track = nil
            DispatchQueue.main.async {
                view.track = track
                view.setNeedsLayout()
            }
        }

        /// 首帧之后渲染标记掉下来（画面卡住）时重新挂一次渲染器。
        /// VideoView 自己的冻结检测只会把 isRendering 置 false，不会恢复。
        func startMonitor() {
            monitor?.cancel()
            monitor = Task { @MainActor [weak self] in
                var stalled = 0
                var attempts = 0
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    guard let self, let view = self.view, view.window != nil,
                          view.didRenderFirstFrame else {
                        stalled = 0
                        continue
                    }
                    guard !view.isRendering else {
                        stalled = 0
                        attempts = 0
                        continue
                    }
                    stalled += 1
                    guard stalled >= 2, attempts < 3, let latest = self.track else { continue }
                    stalled = 0
                    attempts += 1
                    view.track = nil
                    DispatchQueue.main.async {
                        guard view.window != nil else { return }
                        view.track = latest
                        view.setNeedsLayout()
                    }
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> LiveKit.VideoView {
        let view = LiveKit.VideoView()
        context.coordinator.token = refreshToken
        context.coordinator.track = track
        context.coordinator.view = view
        if observesForeground {
            context.coordinator.startForegroundRefresh()
        }
        if recoversFromStall {
            context.coordinator.startMonitor()
        }
        view.track = track
        return view
    }

    func updateUIView(_ uiView: LiveKit.VideoView, context: Context) {
        context.coordinator.track = track
        context.coordinator.view = uiView
        guard context.coordinator.token != refreshToken else {
            uiView.track = track
            return
        }
        context.coordinator.token = refreshToken
        let latest = track
        uiView.track = nil
        DispatchQueue.main.async {
            guard uiView.window != nil else { return }
            uiView.track = latest
            uiView.setNeedsLayout()
        }
    }

    static func dismantleUIView(_ uiView: LiveKit.VideoView, coordinator: Coordinator) {
        coordinator.monitor?.cancel()
        coordinator.view = nil
        uiView.track = nil
    }
}

/// 记录远端视频轨最近一帧的时间。
/// 诊断面板靠它区分「收到屏幕轨但扩展没在出新帧」和「根本没收到轨」。
final class ScreenFrameProbe: NSObject, VideoRenderer, @unchecked Sendable {
    private let lock = NSLock()
    private var lastAt: Date?

    var lastFrameAt: Date? {
        lock.lock()
        defer { lock.unlock() }
        return lastAt
    }

    func reset() {
        lock.lock()
        lastAt = nil
        lock.unlock()
    }

    var isAdaptiveStreamEnabled: Bool { false }
    var adaptiveStreamSize: CGSize { .zero }

    @objc func render(frame: VideoFrame) {
        lock.lock()
        lastAt = Date()
        lock.unlock()
    }
}

/// 房间事件桥：把订阅、退订与连接状态变化转成 SwiftUI 可观察的刷新信号，
/// 并在回调里带上当前远端视频轨，避免只靠遍历 remoteParticipants 拿不到最新轨道。
final class LiveKitRoomObserver: NSObject, ObservableObject, RoomDelegate {
    @Published private(set) var remoteVideo: VideoTrack?
    @Published private(set) var revision = 0
    /// 是否已收到 source=screenShare 的轨道（收到轨但没新帧时要分开看）
    @Published private(set) var screenTrackReceived = false
    /// 连接被意外断开（自动重连失败/服务端踢掉）：UI 需要给出人工重连入口
    @Published private(set) var mediaInterrupted = false

    private let frameProbe = ScreenFrameProbe()
    private var probedTrack: VideoTrack?

    /// 远端画面最近一帧到达时间；nil 表示还没收到帧
    var lastScreenFrameAt: Date? { frameProbe.lastFrameAt }

    private weak var room: Room?

    func attach(_ room: Room) {
        if self.room === room {
            refreshTracks()
            return
        }
        detach()
        self.room = room
        room.add(delegate: self)
        refreshTracks()
    }

    func detach() {
        if let room {
            room.remove(delegate: self)
        }
        room = nil
        DispatchQueue.main.async {
            self.attachProbe(nil)
            self.remoteVideo = nil
            self.screenTrackReceived = false
            self.mediaInterrupted = false
        }
    }

    /// 主动要求重建渲染：回前台、重连完成、换轨之后调用
    func refresh() {
        refreshTracks()
        DispatchQueue.main.async {
            self.revision &+= 1
        }
    }

    /// 重新计算远端视频：退订/换轨/参与者断开后只靠回调容易拿到旧轨道。
    private func refreshTracks() {
        let participants = room.map { Array($0.remoteParticipants.values) } ?? []
        var screenVideo: VideoTrack?
        var anyVideo: VideoTrack?

        for participant in participants {
            for publication in participant.videoTracks {
                guard let track = publication.track as? VideoTrack else { continue }
                if anyVideo == nil { anyVideo = track }
                if publication.source == .screenShareVideo
                    || publication.name == Track.screenShareVideoName
                    || publication.name == "screen" {
                    screenVideo = track
                }
            }
        }

        let chosen = screenVideo ?? anyVideo
        DispatchQueue.main.async {
            let trackChanged = self.remoteVideo !== chosen
            self.attachProbe(chosen)
            self.remoteVideo = chosen
            self.screenTrackReceived = screenVideo != nil
            // 只有轨道真的换了才重建渲染视图；音频/参与者回调也走这里，
            // 每条都 bump 会让画面反复重挂并制造卡帧。
            if trackChanged { self.revision &+= 1 }
        }
    }

    /// 只在主线程切换探测轨；VideoRenderer 可以和其他渲染器共存。
    private func attachProbe(_ track: VideoTrack?) {
        guard probedTrack !== track else { return }
        probedTrack?.remove(videoRenderer: frameProbe)
        frameProbe.reset()
        track?.add(videoRenderer: frameProbe)
        probedTrack = track
    }

    /// 诊断：卡帧时同时记录「订阅还在不在」和「有没有轨道」，
    /// 用来区分 track 丢失（sub/track=false）与渲染器不刷新（sub/track=true 但无新帧）。
    func videoDiagnosticsText() -> String {
        guard let room else { return "room=nil" }
        var parts: [String] = []
        for participant in room.remoteParticipants.values {
            let identity = participant.identity?.stringValue ?? "?"
            for publication in participant.videoTracks {
                let hasTrack = (publication.track as? VideoTrack) != nil
                let dims = publication.dimensions.map { "\($0.width)x\($0.height)" } ?? "?"
                parts.append("id=\(identity) sid=\(publication.sid.stringValue) "
                             + "sub=\(publication.isSubscribed) track=\(hasTrack) muted=\(publication.isMuted) dim=\(dims)")
            }
        }
        return "state=\(room.connectionState) remoteVideo=\(remoteVideo != nil) "
            + "screen=\(screenTrackReceived) pubs=[\(parts.joined(separator: "; "))]"
    }

    /// LiveKit Swift SDK 没有公开的 requestKeyFrame。
    /// 对远端轨先退订再订阅，SFU 会按新订阅重新下发关键帧。返回是否重新拿到可渲染的轨道。
    func resubscribeVideo() async -> Bool {
        guard let room else { return false }
        let targets = videoTargets(in: room)
        guard let target = targets.first else { return false }
        let publication = target.publication
        let before = publication.track as? VideoTrack

        do {
            if publication.isSubscribed {
                try await publication.set(subscribed: false)
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            try await publication.set(subscribed: true)
        } catch {
            return false
        }

        // 订阅协商与首帧都要时间，最多等 1.5 秒再判定失败
        for _ in 0..<5 {
            try? await Task.sleep(nanoseconds: 300_000_000)
            refreshTracks()
            if let now = publication.track as? VideoTrack {
                if let before {
                    if now !== before { return true }
                } else {
                    return true
                }
            }
            if publication.isSubscribed, publication.track != nil { return true }
        }
        refreshTracks()
        return publication.track != nil
    }

    private struct VideoTarget {
        let publication: RemoteTrackPublication
        let score: Int
    }

    private func videoTargets(in room: Room) -> [VideoTarget] {
        var out: [VideoTarget] = []
        for participant in room.remoteParticipants.values {
            for publication in participant.videoTracks {
                guard let publication = publication as? RemoteTrackPublication else { continue }
                let isScreen = publication.source == .screenShareVideo
                    || publication.name == Track.screenShareVideoName
                    || publication.name == "screen"
                out.append(VideoTarget(publication: publication, score: isScreen ? 2 : 1))
            }
        }
        return out.sorted { $0.score > $1.score }
    }

    func room(_ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) {
        refreshTracks()
        // SDK 的 publication.track 在回调瞬间可能还没落到 participant 列表里
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.refreshTracks() }
    }

    func room(_ room: Room, participant: RemoteParticipant, didUnsubscribeTrack publication: RemoteTrackPublication) {
        refreshTracks()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.refreshTracks() }
    }

    func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        refreshTracks()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.refreshTracks() }
    }

    func room(_ room: Room, participant: RemoteParticipant, trackPublication: RemoteTrackPublication,
              didUpdateStreamState streamState: StreamState) {
        refresh()
    }

    func room(_ room: Room, didUpdateConnectionState connectionState: ConnectionState,
              from oldConnectionState: ConnectionState) {
        switch connectionState {
        case .connected:
            DispatchQueue.main.async { self.mediaInterrupted = false }
        case .disconnected:
            if oldConnectionState == .connected || oldConnectionState == .reconnecting {
                DispatchQueue.main.async { self.mediaInterrupted = true }
            }
        default:
            break
        }
        refresh()
    }
}
