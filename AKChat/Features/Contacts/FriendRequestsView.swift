import SwiftUI

/// 新朋友：收到的申请（待处理可同意/拒绝）+ 我发出的申请（对齐安卓 FriendRequestsScreen）
struct FriendRequestsView: View {
    @EnvironmentObject private var app: AppState

    @State private var tab = 0
    @State private var sent: [FriendRequest] = []
    @State private var loadingSent = false
    @State private var toastText: String?

    private var incoming: [FriendRequest] { app.friendRequests }
    private var pending: Int { incoming.filter { $0.status == 0 }.count }
    private var shown: [FriendRequest] { tab == 0 ? incoming : sent }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            if shown.isEmpty {
                Text(tab == 0 ? "暂时没有新的好友申请" : "还没有主动添加过好友")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.hint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { idx, req in
                        requestRow(req, isLast: idx == shown.count - 1)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(AKColor.card)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(AKColor.bg)
            }
        }
        .background(AKColor.bg)
        .overlay(alignment: .bottom) { toastView }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("新朋友")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AKColor.text)
                    if pending > 0 {
                        Text("\(pending) 条待处理")
                            .font(.system(size: 10.5))
                            .foregroundColor(AKColor.red)
                    }
                }
            }
        }
        .refreshable {
            await app.loadFriendRequests()
            await loadSent()
        }
        .task {
            await app.loadFriendRequests()
            await loadSent()
        }
    }

    private var tabBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabCell("收到的申请", 0)
                tabCell("我添加的", 1)
            }
            Rectangle().fill(AKColor.line).frame(height: 0.6)
        }
        .background(AKColor.card)
    }

    private func tabCell(_ title: String, _ index: Int) -> some View {
        Button {
            tab = index
        } label: {
            VStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 14, weight: tab == index ? .semibold : .regular))
                    .foregroundColor(tab == index ? AKColor.text : AKColor.hint)
                Rectangle()
                    .fill(tab == index ? AKColor.brand : Color.clear)
                    .frame(width: 22, height: 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func requestRow(_ req: FriendRequest, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                NavigationLink {
                    UserProfileView(uid: req.fromUid)
                } label: {
                    requestInfo(req)
                }
                .buttonStyle(.plain)
                if tab == 0 && req.status == 0 {
                    Button {
                        Task { await handle(req, pass: false) }
                    } label: {
                        Text("拒绝")
                            .font(.system(size: 12.5))
                            .foregroundColor(AKColor.sub)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background(AKColor.fill)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    Button {
                        Task { await handle(req, pass: true) }
                    } label: {
                        Text("同意")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 5)
                            .background(AKColor.brand)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            if !isLast {
                Rectangle().fill(AKColor.line).frame(height: 0.6).padding(.leading, 74)
            }
        }
    }

    private func requestInfo(_ req: FriendRequest) -> some View {
        HStack(spacing: 12) {
            AvatarView(url: req.avatar, name: req.nickname ?? "好友", size: 46)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(req.nickname ?? "用户")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AKColor.text)
                        .lineLimit(1)
                    if let yx = req.yxId, !yx.isEmpty {
                        Text("AK号 \(yx)")
                            .font(.system(size: 10.5))
                            .foregroundColor(AKColor.hint)
                            .lineLimit(1)
                    }
                }
                Text(requestMessage(req))
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.sub)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    statusTag(req.status)
                    Text(TimeText.full(req.createdAt))
                        .font(.system(size: 10.5))
                        .foregroundColor(AKColor.hint)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private func requestMessage(_ req: FriendRequest) -> String {
        if let msg = req.message, !msg.isEmpty { return msg }
        return tab == 0 ? "请求添加你为好友" : "请求添加对方为好友"
    }

    private func statusTag(_ status: Int) -> some View {
        let text: String
        let color: Color
        let background: Color
        switch status {
        case 1:
            text = "已通过"
            color = Color(hex: 0x0FB67A)
            background = AKColor.brandSoft
        case 2:
            text = "已拒绝"
            color = AKColor.muted
            background = AKColor.fill
        default:
            text = "待处理"
            color = AKColor.gold
            background = AKColor.goldSoft
        }
        return Text(text)
            .font(.system(size: 9.5, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func loadSent() async {
        if loadingSent { return }
        loadingSent = true
        defer { loadingSent = false }
        if let data = try? await APIClient.shared.friendRequests(box: "out") {
            sent = data.list
        }
    }

    private func handle(_ req: FriendRequest, pass: Bool) async {
        do {
            let msg = try await APIClient.shared.postRaw(
                "api/v1/friend-requests/handle",
                body: ["id": req.id, "pass": pass ? 1 : 0]
            )
            showToast(msg.isEmpty ? (pass ? "已同意" : "已拒绝") : msg)
            await app.loadFriendRequests()
            await loadSent()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    private var toastView: some View {
        Group {
            if let toastText {
                Text(toastText)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color(hex: 0x1A1D26).opacity(0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 40)
                    .padding(.bottom, 28)
            }
        }
    }

    private func showToast(_ message: String) {
        toastText = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if toastText == message { toastText = nil }
        }
    }
}
