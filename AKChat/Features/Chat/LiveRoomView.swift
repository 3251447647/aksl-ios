import SwiftUI

/// 群直播间：拉取房间信息、开播入口（音视频与评论下一步接入）
struct LiveRoomView: View {
    let gid: Int64

    @State private var room: LiveRoomData?
    @State private var loading = true
    @State private var error: String?
    @State private var title = ""
    @State private var starting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                } else if let live = room?.live {
                    liveCard(live)
                } else {
                    emptyCard
                }
                if let msg = room?.msg, !msg.isEmpty {
                    Text(msg).font(.system(size: 12)).foregroundColor(AKColor.muted)
                }
                if let error {
                    Text(error).font(.system(size: 12)).foregroundColor(AKColor.red)
                }
            }
            .padding(14)
        }
        .background(AKColor.bg)
        .navigationTitle("直播间")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func liveCard(_ live: LiveInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AvatarView(url: live.hostAvatar, name: live.hostName, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(live.title).font(.system(size: 16, weight: .semibold)).foregroundColor(AKColor.text)
                    Text("\(live.hostName) 正在直播 · \(live.viewers) 人观看")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.muted)
                }
                Spacer()
                Text("LIVE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AKColor.red)
                    .clipShape(Capsule())
            }
            Rectangle()
                .fill(AKColor.fill)
                .frame(height: 150)
                .overlay(
                    VStack(spacing: 6) {
                        Image(systemName: "video.fill").font(.system(size: 24)).foregroundColor(AKColor.muted)
                        Text("直播间画面接入中").font(.system(size: 12)).foregroundColor(AKColor.muted)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text("观众 \(live.viewers) · 房间 \(room?.sfu?.room ?? "-")")
                .font(.system(size: 11))
                .foregroundColor(AKColor.muted)
        }
        .padding(14)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("当前没有直播").font(.system(size: 15, weight: .medium)).foregroundColor(AKColor.text)
            Text("仅靓号群可开播，群主和管理员可以开。")
                .font(.system(size: 12))
                .foregroundColor(AKColor.muted)
            if room?.canStart == 1 {
                TextField("直播标题（2~30 字）", text: $title)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AKColor.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Button {
                    Task { await start() }
                } label: {
                    Text(starting ? "开播中…" : "开始直播")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AKColor.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(starting)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            room = try await APIClient.shared.liveRoom(gid: gid)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func start() async {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 2 else { error = "直播标题需 2~30 个字"; return }
        starting = true
        defer { starting = false }
        do {
            room = try await APIClient.shared.startLive(gid: gid, title: t)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
