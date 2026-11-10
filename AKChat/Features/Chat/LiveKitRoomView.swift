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
        context.coordinator.startForegroundRefresh()
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

/// 房间事件桥：把订阅、退订与连接状态变化转成 SwiftUI 可观察的刷新信号，
/// 并在回调里带上当前远端视频轨，避免只靠遍历 remoteParticipants 拿不到最新轨道。
final class LiveKitRoomObserver: NSObject, ObservableObject, RoomDelegate {
    @Published private(set) var remoteVideo: VideoTrack?
    /// 是否收到主播的独立系统声音轨（screen_share_audio / host_system_audio）
    @Published private(set) var screenAudioActive = false
    @Published private(set) var revision = 0

    /// 主播自己的扩展音频要在本机静音，否则自己共享出去的声音会从扬声器再放一遍
    var extensionAudioIdentityToMute: String?

    private weak var room: Room?
    private let audioMuteQueue = DispatchQueue(label: "ak.live.extension-audio-mute")
    private var mutedAudioSids = Set<String>()

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
        audioMuteQueue.async { [weak self] in self?.mutedAudioSids.removeAll() }
        DispatchQueue.main.async {
            self.remoteVideo = nil
            self.screenAudioActive = false
        }
    }

    /// 主动要求重建渲染：回前台、重连完成、换轨之后调用
    func refresh() {
        refreshTracks()
        DispatchQueue.main.async {
            self.revision &+= 1
        }
    }

    /// 重新计算远端视频与系统声音：退订/换轨/参与者断开后只靠回调容易拿到旧轨道。
    private func refreshTracks() {
        let participants = room.map { Array($0.remoteParticipants.values) } ?? []
        var screenVideo: VideoTrack?
        var anyVideo: VideoTrack?
        var hasSystemAudio = false

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
            let isExtensionAudioSource = participant.identity?.stringValue.hasSuffix("_bc") == true
            for publication in participant.audioTracks {
                guard publication.track != nil else { continue }
                if isExtensionAudioSource
                    || publication.name == "host_system_audio"
                    || publication.source == .screenShareAudio {
                    hasSystemAudio = true
                }
                muteIfNeeded(participant: participant, publication: publication)
            }
        }

        let chosen = screenVideo ?? anyVideo
        DispatchQueue.main.async {
            self.remoteVideo = chosen
            self.screenAudioActive = hasSystemAudio
            self.revision &+= 1
        }
    }

    private func muteIfNeeded(participant: RemoteParticipant, publication: TrackPublication) {
        guard let identity = extensionAudioIdentityToMute,
              participant.identity?.stringValue == identity,
              let track = publication.track as? RemoteAudioTrack else { return }
        let sid = publication.sid.stringValue
        audioMuteQueue.async { [weak self] in
            guard let self, !self.mutedAudioSids.contains(sid) else { return }
            self.mutedAudioSids.insert(sid)
            track.volume = 0
        }
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
        refresh()
    }
}
