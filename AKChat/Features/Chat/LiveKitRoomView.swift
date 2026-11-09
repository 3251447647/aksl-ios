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

        deinit {
            monitor?.cancel()
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
    @Published private(set) var revision = 0

    private weak var room: Room?

    func attach(_ room: Room) {
        if self.room === room { return }
        detach()
        self.room = room
        room.add(delegate: self)
    }

    func detach() {
        if let room {
            room.remove(delegate: self)
        }
        room = nil
        remoteVideo = nil
    }

    /// 主动要求重建渲染：回前台、重连完成、换轨之后调用
    func refresh() {
        DispatchQueue.main.async {
            self.revision &+= 1
        }
    }

    private func update(_ track: VideoTrack?) {
        DispatchQueue.main.async {
            self.remoteVideo = track
            self.revision &+= 1
        }
    }

    func room(_ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) {
        guard let video = publication.track as? VideoTrack else { return }
        update(video)
    }

    func room(_ room: Room, participant: RemoteParticipant, didUnsubscribeTrack publication: RemoteTrackPublication) {
        guard publication.kind == .video else { return }
        update(nil)
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
