import SwiftUI

struct GroupMembersView: View {
    let groupId: Int64
    let myRole: Int
    let myUid: Int64

    @State private var members: [GroupMember] = []
    @State private var actionTarget: GroupMember?
    @State private var showActions = false
    @State private var tipText: String?

    private var canManage: Bool { myRole == 1 || myRole == 2 }

    var body: some View {
        List {
            ForEach(members) { m in
                HStack(spacing: 12) {
                    AvatarView(url: m.avatar, name: m.name ?? "成员", size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(m.name ?? "成员").foregroundColor(AKColor.text)
                            if m.role == 1 { BadgeView(text: "群主", color: AKColor.gold, background: AKColor.goldSoft) }
                            if m.role == 2 { BadgeView(text: "管理员", color: AKColor.link, background: AKColor.blueSoft) }
                            if m.isPretty == 1, let no = m.prettyNo { BadgeView(text: no) }
                        }
                        if m.vipLevel > 0 {
                            Text(m.vipLevel >= 2 ? "SVIP" : "VIP")
                                .font(.system(size: 10)).foregroundColor(AKColor.gold)
                        }
                    }
                    Spacer()
                    if canManage && m.uid != myUid {
                        Menu {
                            Button("禁言 10 分钟") { Task { await mute(m, 10) } }
                            Button("禁言 1 小时") { Task { await mute(m, 60) } }
                            Button("禁言 1 天") { Task { await mute(m, 1440) } }
                            Button("解除禁言") { Task { await mute(m, 0) } }
                            if m.role == 0 {
                                Button("设为管理员") { Task { await setRole(m, 2) } }
                            } else if m.role == 2 {
                                Button("取消管理员") { Task { await setRole(m, 0) } }
                            }
                            Button("移出群聊", role: .destructive) { Task { await kick(m) } }
                        } label: {
                            Image(systemName: "ellipsis").foregroundColor(AKColor.muted)
                        }
                    }
                }
            }
        }
        .navigationTitle("群成员（\(members.count)）")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .overlay(alignment: .bottom) {
            if let tipText {
                Text(tipText)
                    .font(.system(size: 12)).foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Capsule())
                    .padding(.bottom, 18)
            }
        }
    }

    private func load() async {
        if let info = try? await APIClient.shared.groupInfo(id: groupId) {
            members = info.members
        }
    }

    private func mute(_ m: GroupMember, _ minutes: Int) async {
        await APIClient.shared.muteMember(gid: groupId, uid: m.uid, minutes: minutes)
        tipText = minutes == 0 ? "已解除禁言" : "已禁言 \(minutes) 分钟"
        await load()
    }

    private func setRole(_ m: GroupMember, _ role: Int) async {
        await APIClient.shared.setAdmin(gid: groupId, uid: m.uid, role: role)
        await load()
    }

    private func kick(_ m: GroupMember) async {
        await APIClient.shared.kickMember(gid: groupId, uid: m.uid)
        await load()
    }
}
