import SwiftUI
import LiveKit

/// LiveKit 视频轨渲染（群通话宫格 / 直播间画面共用）
struct LiveKitVideoTile: UIViewRepresentable {
    let track: VideoTrack

    func makeUIView(context: Context) -> LiveKit.VideoView {
        let v = LiveKit.VideoView()
        v.track = track
        return v
    }

    func updateUIView(_ uiView: LiveKit.VideoView, context: Context) {
        uiView.track = track
    }
}
