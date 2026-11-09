import SwiftUI
import LiveKit
import ReplayKit
import UIKit

/// LiveKit 直播间：主播发布摄像头/麦克风，观众订阅渲染
struct LiveKitRoomView: View {
    let url: String
    let token: String
    let isHost: Bool
    var videoEnabled: Bool = true

    @Environment(\.dismiss) private var dismiss
    @StateObject private var room = Room()
    @State private var connecting = true
    @State private var error: String?
    @State private var micOn = true
    @State private var camOn = false
    @State private var sharingScreen = false
    @State private var screenTrack: LocalVideoTrack?
    @State private var screenPublication: LocalTrackPublication?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if connecting {
                ProgressView().tint(.white)
            } else {
                videoArea
            }

            VStack {
                HStack {
                    Button {
                        Task {
                            await room.disconnect()
                            dismiss()
                        }
                    } label: {
                        Text("关闭").foregroundColor(.white)
                    }
                    Spacer()
                    Text(room.connectionState == .connected ? "直播中" : "连接中…")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                if let error {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .padding(.top, 6)
                }

                Spacer()

                if isHost && !connecting {
                    HStack(spacing: 22) {
                        Button {
                            Task {
                                micOn.toggle()
                                try? await room.localParticipant.setMicrophone(enabled: micOn)
                            }
                        } label: {
                            Image(systemName: micOn ? "mic.fill" : "mic.slash.fill")
                                .font(.system(size: 19))
                                .foregroundColor(.white)
                                .frame(width: 48, height: 48)
                                .background(Color.white.opacity(0.18))
                                .clipShape(Circle())
                        }
                        Button {
                            Task {
                                camOn.toggle()
                                try? await room.localParticipant.setCamera(enabled: camOn)
                            }
                        } label: {
                            Image(systemName: camOn ? "video.fill" : "video.slash.fill")
                                .font(.system(size: 19))
                                .foregroundColor(.white)
                                .frame(width: 48, height: 48)
                                .background(Color.white.opacity(0.18))
                                .clipShape(Circle())
                        }
                        Button {
                            Task {
                                if sharingScreen { await stopScreenShare() } else { await startScreenShare() }
                            }
                        } label: {
                            Image(systemName: sharingScreen ? "rectangle.on.rectangle.fill" : "rectangle.on.rectangle")
                                .font(.system(size: 19))
                                .foregroundColor(.white)
                                .frame(width: 48, height: 48)
                                .background(sharingScreen ? AKColor.red : Color.white.opacity(0.18))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.bottom, 34)
                }
            }
        }
        .task { await connect() }
        .onDisappear {
            if sharingScreen { RPScreenRecorder.shared().stopCapture { _ in } }
            Task { await room.disconnect() }
        }
    }

    private var videoArea: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(Array(room.remoteParticipants.values), id: \.identity) { p in
                    ForEach(p.videoTracks, id: \.sid) { pub in
                        if let track = pub.track as? VideoTrack {
                            TrackVideoView(track: track)
                                .frame(height: 230)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                if let localTrack = room.localParticipant.videoTracks.first?.track as? VideoTrack {
                    TrackVideoView(track: localTrack)
                        .frame(height: 170)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                if room.remoteParticipants.isEmpty && room.localParticipant.videoTracks.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "video.slash").font(.system(size: 26)).foregroundColor(.white.opacity(0.6))
                        Text(isHost ? "摄像头未开启" : "主播还没开画面")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                }
            }
            .padding(12)
        }
    }

    /// 屏幕共享：ReplayKit 采集 → LiveKit BufferCapturer 推帧（App 切后台会停）
    private func startScreenShare() async {
        guard !sharingScreen else { return }
        let track = LocalVideoTrack.createBufferTrack(name: "screen")
        guard let capturer = track.capturer as? BufferCapturer else {
            error = "当前设备不支持屏幕共享"
            return
        }
        screenTrack = track
        RPScreenRecorder.shared().startCapture { sample, type, _ in
            if type == .video { capturer.capture(sample) }
        } completionHandler: { err in
            if err != nil {
                Task { @MainActor in self.error = "屏幕采集失败：\(err?.localizedDescription ?? "")" }
            }
        }
        do {
            let pub = try await room.localParticipant.publish(videoTrack: track)
            screenPublication = pub
            sharingScreen = true
        } catch {
            RPScreenRecorder.shared().stopCapture { _ in }
            screenTrack = nil
            self.error = "共享失败：\(error.localizedDescription)"
        }
    }

    private func stopScreenShare() async {
        RPScreenRecorder.shared().stopCapture { _ in }
        if let pub = screenPublication {
            try? await room.localParticipant.unpublish(publication: pub)
        }
        screenPublication = nil
        screenTrack = nil
        sharingScreen = false
    }

    private func connect() async {
        guard let u = URL(string: url) else {
            error = "直播地址无效"
            connecting = false
            return
        }
        do {
            try await room.connect(url: u.absoluteString, token: token)
            await MainActor.run {
                connecting = false
                error = nil
            }
            if isHost {
                try? await room.localParticipant.setMicrophone(enabled: true)
                if videoEnabled {
                    try? await room.localParticipant.setCamera(enabled: true)
                    await MainActor.run { camOn = true }
                }
            }
        } catch {
            await MainActor.run {
                connecting = false
                self.error = "进入直播间失败：\(error.localizedDescription)"
            }
        }
    }
}

private struct TrackVideoView: UIViewRepresentable {
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
