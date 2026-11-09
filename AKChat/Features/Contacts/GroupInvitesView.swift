import SwiftUI

/// 群通知：邀请我入群的记录，可同意 / 拒绝（对齐安卓 GroupNoticeScreen 的「邀请我入群」）
struct GroupInvitesView: View {
    @State private var list: [GroupInvite] = []
    @State private var toastText: String?

    private var pending: Int { list.filter { $0.status == 0 }.count }

    var body: some View {
        VStack(spacing: 0) {
            if list.isEmpty {
                Text("暂时没有群邀请")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.hint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(list.enumerated()), id: \.element.id) { idx, inv in
                        inviteRow(inv, isLast: idx == list.count - 1)
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
                    Text("群通知")
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
        .refreshable { await load() }
        .task { await load() }
    }

    private func inviteRow(_ inv: GroupInvite, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                NavigationLink {
                    GroupPreviewView(groupId: inv.groupId)
                } label: {
                    HStack(spacing: 12) {
                        AvatarView(url: inv.groupAvatar, name: inv.groupName ?? "群聊", size: 46)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(inv.groupName ?? "群聊")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AKColor.text)
                                    .lineLimit(1)
                                if let no = inv.groupNo, !no.isEmpty {
                                    Text("群号 \(no)")
                                        .font(.system(size: 10.5))
                                        .foregroundColor(AKColor.hint)
                                        .lineLimit(1)
                                }
                            }
                            Text("\(inv.inviterName ?? "好友") 邀请你加入群聊")
                                .font(.system(size: 12))
                                .foregroundColor(AKColor.sub)
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                statusTag(inv.status)
                                if inv.memberCount > 0 {
                                    Text("\(inv.memberCount) 人")
                                        .font(.system(size: 10.5))
                                        .foregroundColor(AKColor.hint)
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if inv.status == 0 {
                    Button {
                        Task { await handle(inv, false) }
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
                        Task { await handle(inv, true) }
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

    private func statusTag(_ status: Int) -> some View {
        let text: String
        let color: Color
        let background: Color
        switch status {
        case 1:
            text = "已同意"
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

    private func load() async {
        if let data = try? await APIClient.shared.groupInvites() {
            list = data.list
        }
    }

    private func handle(_ inv: GroupInvite, _ pass: Bool) async {
        do {
            let msg = try await APIClient.shared.postRaw(
                "api/v1/group/invites/handle",
                body: ["id": inv.id, "pass": pass ? 1 : 0]
            )
            showToast(msg.isEmpty ? (pass ? "已同意" : "已拒绝") : msg)
            await load()
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

struct BlacklistView: View {
    @State private var list: [BlockedUser] = []

    var body: some View {
        List {
            ForEach(list) { u in
                HStack(spacing: 12) {
                    AvatarView(url: u.avatar, name: u.nickname ?? "用户", size: 38)
                    Text(u.nickname ?? "用户").foregroundColor(AKColor.text)
                    Spacer()
                    Button("解除") {
                        Task {
                            await APIClient.shared.blockUser(uid: u.uid, act: "remove")
                            await load()
                        }
                    }
                    .font(.system(size: 13)).foregroundColor(AKColor.brand)
                }
            }
            if list.isEmpty {
                Text("黑名单为空").font(.system(size: 13)).foregroundColor(AKColor.muted)
            }
        }
        .navigationTitle("黑名单")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        if let data = try? await APIClient.shared.blacklist() {
            list = data.list
        }
    }
}
