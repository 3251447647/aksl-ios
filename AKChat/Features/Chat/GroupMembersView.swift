import SwiftUI

struct GroupMembersView: View {
    let groupId: Int64
    let myRole: Int
    let myUid: Int64

    @State private var members: [GroupMember] = []
    @State private var actionTarget: GroupMember?
    @State private var showActions = false
    @State private var tipText: String?
    @State private var requests: [GroupJoinRequest] = []
    @State private var groupName: String = ""
    @State private var showTransfer = false
    @State private var confirmDissolve = false
    @State private var dissolveName = ""
    @State private var settings: GroupSettings?

    private var canManage: Bool { myRole == 1 || myRole == 2 }

    var body: some View {
        List {
            if let s = settings {
                Section("群等级") {
                    HStack {
                        Text("群主").font(.system(size: 13)).foregroundColor(AKColor.sub)
                        Spacer()
                        Text(s.ownerVipLabel.isEmpty ? "普通用户" : s.ownerVipLabel)
                            .font(.system(size: 13))
                            .foregroundColor(s.ownerVipLevel > 0 ? AKColor.gold : AKColor.hint)
                    }
                    HStack {
                        Text("当前人数").font(.system(size: 13)).foregroundColor(AKColor.sub)
                        Spacer()
                        Text("\(s.memberCount) / \(s.maxMember) 人")
                            .font(.system(size: 13))
                            .foregroundColor(s.memberCount >= s.maxMember ? AKColor.red : AKColor.text)
                    }
                    if s.ownerVipLevel > 0 {
                        Text(s.ownerUpgradeLeft > 0 ? "还可升级 \(s.ownerUpgradeLeft) 个群聊" : "暂无可升级群聊")
                            .font(.system(size: 11.5))
                            .foregroundColor(s.ownerUpgradeLeft > 0 ? AKColor.gold : AKColor.hint)
                    } else {
                        Text("开通 VIP / SVIP 后可提升群人数上限")
                            .font(.system(size: 11.5))
                            .foregroundColor(AKColor.hint)
                    }
                    if s.canUpgrade == 1 {
                        Button {
                            Task { await upgrade() }
                        } label: {
                            Text("升级群人数上限到 \(s.upgradeMaxMember) 人")
                                .font(.system(size: 14))
                                .foregroundColor(AKColor.brand)
                        }
                    }
                }
            }

            if canManage && !requests.isEmpty {
                Section("入群申请（\(requests.count)）") {
                    ForEach(requests) { r in
                        HStack(spacing: 10) {
                            AvatarView(url: r.avatar, name: r.nickname, size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.nickname).font(.system(size: 14)).foregroundColor(AKColor.text)
                                if !r.reason.isEmpty {
                                    Text(r.reason).font(.system(size: 11.5)).foregroundColor(AKColor.muted).lineLimit(1)
                                }
                            }
                            Spacer()
                            Button("拒绝") { Task { await handle(r, agree: false) } }
                                .font(.system(size: 13)).foregroundColor(AKColor.hint)
                            Button("同意") { Task { await handle(r, agree: true) } }
                                .font(.system(size: 13)).foregroundColor(AKColor.brand)
                        }
                    }
                }
            }

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
        .toolbar {
            if myRole == 1 {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("转让群主") { showTransfer = true }
                        Button("解散群聊", role: .destructive) { confirmDissolve = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showTransfer) {
            NavigationStack {
                List(members.filter { $0.uid != myUid }) { m in
                    Button {
                        Task { await transfer(m) }
                    } label: {
                        HStack(spacing: 10) {
                            AvatarView(url: m.avatar, name: m.name ?? "成员", size: 36)
                            Text(m.name ?? "成员").foregroundColor(AKColor.text)
                        }
                    }
                }
                .navigationTitle("转让群主")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .alert("解散群聊", isPresented: $confirmDissolve) {
            TextField("输入群名称确认", text: $dissolveName)
            Button("取消", role: .cancel) { dissolveName = "" }
            Button("解散", role: .destructive) { Task { await dissolve() } }
        } message: {
            Text("解散后群聊与成员关系将全部删除，需输入群名称「\(groupName)」确认")
        }
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
            groupName = info.name ?? ""
        }
        if canManage {
            requests = (try? await APIClient.shared.groupJoinRequests(gid: groupId))?.list ?? []
        }
        settings = try? await APIClient.shared.groupSettings(gid: groupId)
    }

    private func upgrade() async {
        do {
            try await APIClient.shared.upgradeGroup(gid: groupId)
            tipText = "已升级群人数上限"
            await load()
        } catch {
            tipText = error.localizedDescription
        }
    }

    private func handle(_ r: GroupJoinRequest, agree: Bool) async {
        do {
            try await APIClient.shared.handleGroupRequest(gid: groupId, requestId: r.rid, act: agree ? "agree" : "refuse")
            tipText = agree ? "已同意 \(r.nickname) 入群" : "已拒绝 \(r.nickname)"
            await load()
        } catch {
            tipText = error.localizedDescription
        }
    }

    private func transfer(_ m: GroupMember) async {
        do {
            try await APIClient.shared.transferGroup(gid: groupId, toUid: m.uid)
            tipText = "已转让群主给 \(m.name ?? "成员")"
            showTransfer = false
            await load()
        } catch {
            tipText = error.localizedDescription
        }
    }

    private func dissolve() async {
        do {
            try await APIClient.shared.dissolveGroup(gid: groupId, name: dissolveName)
            tipText = "群聊已解散"
            dissolveName = ""
        } catch {
            tipText = error.localizedDescription
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
