import SwiftUI

/// 群通话：先向服务端 join 拿 SFU token，再用 LiveKit 进房
struct GroupCallView: View {
    let gid: Int64
    let callType: Int

    @Environment(\.dismiss) private var dismiss
    @State private var data: GroupCallJoinData?
    @State private var error: String?
    @State private var showRoom = false

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: callType == 2 ? "video.fill" : "phone.fill")
                .font(.system(size: 34))
                .foregroundColor(AKColor.brand)

            if let d = data, let sfu = d.sfu, let url = sfu.url, let token = sfu.token,
               sfu.enabled == 1, !url.isEmpty, !token.isEmpty {
                Text(callType == 2 ? "群视频通话" : "群语音通话")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AKColor.text)
                Button {
                    showRoom = true
                } label: {
                    Text("进入通话")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(AKColor.brand)
                        .clipShape(Capsule())
                }
            } else if let error {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            } else {
                ProgressView()
                Text("正在接入通话…")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.muted)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(AKColor.bg)
        .navigationTitle(callType == 2 ? "群视频通话" : "群语音通话")
        .navigationBarTitleDisplayMode(.inline)
        .task { await join() }
        .onDisappear {
            Task { await APIClient.shared.groupCallLeave(gid: gid) }
        }
        .fullScreenCover(isPresented: $showRoom) {
            if let sfu = data?.sfu, let url = sfu.url, let token = sfu.token {
                LiveKitRoomView(
                    url: url,
                    token: token,
                    isHost: true,
                    videoEnabled: callType == 2
                )
            }
        }
    }

    private func join() async {
        do {
            data = try await APIClient.shared.groupCallJoin(gid: gid, callType: callType)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
