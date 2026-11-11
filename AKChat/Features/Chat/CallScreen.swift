import SwiftUI
import WebRTC

/// 一对一通话界面：语音只显示头像，视频显示远端画面
struct CallScreen: View {
    var incoming: IncomingCall? = nil

    @EnvironmentObject private var app: AppState
    @ObservedObject private var call = CallManager.shared
    @Environment(\.dismiss) private var dismiss
    /// 来电已点「接听」：不再回退到来电卡片（MainTabView 的 cover 仍由 app.incomingCall 驱动）
    @State private var acceptedIncoming = false

    var body: some View {
        ZStack {
            Color(hex: 0x121417).ignoresSafeArea()

            if call.callType == 2, call.phase == .connected, call.remoteTrack != nil {
                RTCVideoView(track: call.remoteTrack)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 14) {
                    AKImage(url: call.peerAvatar, size: 96, placeholder: Color.white.opacity(0.12))
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())

                    Text(call.peerName.isEmpty ? "通话中" : call.peerName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    Text(statusText)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.65))

                    if let error = call.error {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
            }

            VStack {
                Spacer()
                HStack(spacing: 26) {
                    Button {
                        call.toggleMute()
                    } label: {
                        circle(call.muted ? "mic.slash.fill" : "mic.fill", active: call.muted)
                    }
                    if call.callType == 2 {
                        Button {
                            call.toggleCamera()
                        } label: {
                            circle(call.cameraOn ? "video.fill" : "video.slash.fill", active: !call.cameraOn)
                        }
                    }
                    Button {
                        call.hangup()
                        app.incomingCall = nil
                        dismiss()
                    } label: {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(width: 62, height: 62)
                            .background(AKColor.red)
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 44)
            }
        }
        .overlay {
            if let incoming, !acceptedIncoming, !call.isActive {
                incomingOverlay(incoming)
            }
        }
        .onChange(of: call.phase) { phase in
            /* 出错时保留界面显示原因，不要直接关掉；正常结束才自动返回 */
            if phase == .ended, call.error == nil {
                app.incomingCall = nil
                dismiss()
            }
        }
    }

    private func incomingOverlay(_ c: IncomingCall) -> some View {
        ZStack {
            Color(hex: 0x121417).ignoresSafeArea()
            VStack(spacing: 14) {
                AKImage(url: c.avatar, size: 96, placeholder: Color.white.opacity(0.12))
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())

                Text(c.name.isEmpty ? "来电" : c.name)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                Text(c.callType == 2 ? "邀请你视频通话" : "邀请你语音通话")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.65))

                Spacer().frame(height: 30)

                HStack(spacing: 60) {
                    Button {
                        Task { await APIClient.shared.callHangup(callId: c.id) }
                        app.incomingCall = nil
                        dismiss()
                    } label: {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(width: 62, height: 62)
                            .background(AKColor.red)
                            .clipShape(Circle())
                    }
                    Button {
                        acceptedIncoming = true
                        Task {
                            await CallManager.shared.accept(
                                callId: c.id,
                                name: c.name,
                                avatar: c.avatar,
                                type: c.callType
                            )
                        }
                    } label: {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(width: 62, height: 62)
                            .background(AKColor.brand)
                            .clipShape(Circle())
                    }
                    .disabled(call.isActive)
                }
            }
            .padding(24)
        }
    }

    private var statusText: String {
        switch call.phase {
        case .calling: return call.callType == 2 ? "正在等待对方接听…" : "正在呼叫…"
        case .connected: return call.callType == 2 ? "视频通话中" : "语音通话中"
        case .ended: return "通话已结束"
        default: return ""
        }
    }

    private func circle(_ icon: String, active: Bool) -> some View {
        Image(systemName: icon)
            .font(.system(size: 20))
            .foregroundColor(.white)
            .frame(width: 54, height: 54)
            .background(active ? Color.white.opacity(0.42) : Color.white.opacity(0.16))
            .clipShape(Circle())
    }
}

private struct RTCVideoView: UIViewRepresentable {
    let track: RTCVideoTrack?

    func makeUIView(context: Context) -> RTCMTLVideoView {
        let v = RTCMTLVideoView()
        v.videoContentMode = .scaleAspectFill
        return v
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        track?.add(uiView)
    }
}
