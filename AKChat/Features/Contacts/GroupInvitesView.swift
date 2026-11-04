import SwiftUI

struct GroupInvitesView: View {
    @State private var list: [GroupInvite] = []
    @State private var tipText: String?

    var body: some View {
        List {
            ForEach(list) { inv in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        AvatarView(url: inv.groupAvatar, name: inv.groupName ?? "群聊", size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(inv.groupName ?? "群聊").foregroundColor(AKColor.text)
                            Text("\(inv.inviterName ?? "好友") 邀请你加入　\(inv.memberCount) 人")
                                .font(.system(size: 11)).foregroundColor(AKColor.muted)
                        }
                        Spacer()
                    }
                    if inv.status == 0 {
                        HStack(spacing: 10) {
                            Button("接受") {
                                Task { await handle(inv, true) }
                            }
                            .font(.system(size: 13)).foregroundColor(.white)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(AKColor.brand).clipShape(Capsule())
                            Button("拒绝") {
                                Task { await handle(inv, false) }
                            }
                            .font(.system(size: 13)).foregroundColor(AKColor.muted)
                        }
                    } else {
                        Text(inv.status == 1 ? "已加入" : "已拒绝")
                            .font(.system(size: 11)).foregroundColor(AKColor.muted)
                    }
                }
                .padding(.vertical, 4)
            }
            if list.isEmpty {
                Text("暂无群邀请").font(.system(size: 13)).foregroundColor(AKColor.muted)
            }
        }
        .navigationTitle("群邀请")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        if let data = try? await APIClient.shared.groupInvites() {
            list = data.list
        }
    }

    private func handle(_ inv: GroupInvite, _ pass: Bool) async {
        await APIClient.shared.handleGroupInvite(id: inv.id, pass: pass)
        await load()
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
