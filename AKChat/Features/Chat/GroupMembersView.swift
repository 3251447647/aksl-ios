import SwiftUI

/// 群成员：群等级 → 入群申请 → 成员列表 → 群主操作（对齐安卓 GroupMembersScreen / GroupAdminScreen）
struct GroupMembersView: View {
    let groupId: Int64
    let myRole: Int
    let myUid: Int64

    @State private var members: [GroupMember] = []
    @State private var requests: [GroupJoinRequest] = []
    @State private var settings: GroupSettings?
    @State private var loading = true
    @State private var keyword = ""
    @State private var groupName = ""
    @State private var allowInvite = 1
    @State private var tipText: String?
    @State private var showTransfer = false
    @State private var confirmDissolve = false
    @State private var confirmUpgrade = false
    @State private var dissolveName = ""

    private var canManage: Bool { myRole == 1 || myRole == 2 }
    private var isOwner: Bool { myRole == 1 }

    private var shown: [GroupMember] {
        let k = keyword.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty else { return members }
        return members.filter { ($0.name ?? "").range(of: k, options: .caseInsensitive) != nil }
    }

    var body: some View {
        List {
            if let s = settings {
                block(top: true, bottom: true) { levelCard(s) }
            }

            if canManage && !requests.isEmpty {
                block(top: true, bottom: true) { requestsCard }
            }

            if loading && members.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else if members.isEmpty {
                Text("暂无成员")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.hint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                block(top: true, bottom: false) { searchField }
                ForEach(shown) { m in
                    block(top: false, bottom: false) {
                        memberRow(m, last: m.id == shown.last?.id && allowInvite != 1)
                    }
                }
                if allowInvite == 1 {
                    block(top: false, bottom: true) { inviteRow }
                }
            }

            if isOwner {
                sectionLabel("群主操作")
                block(top: true, bottom: true) { ownerCard }
            }

            Color.clear
                .frame(height: 10)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AKColor.bg.ignoresSafeArea())
        .navigationTitle("群成员（\(members.count)）")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showTransfer) {
            transferSheet
        }
        .alert("升级群人数上限", isPresented: $confirmUpgrade) {
            Button("取消", role: .cancel) {}
            Button("确认升级") { Task { await upgrade() } }
        } message: {
            Text("升级后群人数上限提升到 \(settings?.upgradeMaxMember ?? 0) 人，现有成员不受影响。")
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

    // MARK: - 群等级

    private func levelCard(_ s: GroupSettings) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("群等级").font(.system(size: 14.5, weight: .medium)).foregroundColor(AKColor.text)
                Spacer(minLength: 6)
                Text("群主 \(s.ownerVipLabel.isEmpty ? "普通用户" : s.ownerVipLabel)")
                    .font(.system(size: 12))
                    .foregroundColor(s.ownerVipLevel > 0 ? AKColor.gold : AKColor.hint)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)

            line(leading: 14)

            VStack(alignment: .leading, spacing: 6) {
                Text(levelHint(s))
                    .font(.system(size: 11.5))
                    .foregroundColor(s.ownerVipLevel > 0 && s.ownerUpgradeLeft > 0 ? AKColor.gold : AKColor.hint)
                HStack {
                    Text("当前人数").font(.system(size: 13)).foregroundColor(AKColor.sub)
                    Spacer()
                    Text("\(s.memberCount) / \(s.maxMember) 人")
                        .font(.system(size: 13))
                        .foregroundColor(s.memberCount > s.maxMember ? AKColor.red : AKColor.text)
                }
                if s.memberCount > s.maxMember {
                    Text("成员数已超过群主当前等级上限（\(s.maxMember) 人），现有成员不受影响，新成员暂时无法加入。群主续费或升级会员后自动恢复。")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.red)
                }
                if s.groupMaxMember != s.maxMember {
                    Text("群已开通上限 \(s.groupMaxMember) 人，受群主当前等级限制")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.hint)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if isOwner {
                line(leading: 0)
                if s.canUpgrade == 1 {
                    Button {
                        confirmUpgrade = true
                    } label: {
                        Text("升级到 \(s.ownerVipLabel.isEmpty ? "会员" : s.ownerVipLabel) 群（\(s.upgradeMaxMember) 人）")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(AKColor.brand)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                } else {
                    Text(s.ownerVipLevel == 0
                         ? "群主开通 VIP / SVIP 后可将群人数上限升级到 \(s.upgradeMaxMember) 人"
                         : "已是当前等级最高档位（\(s.groupMaxMember) 人）")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.hint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
            }
        }
    }

    private func levelHint(_ s: GroupSettings) -> String {
        if s.ownerVipLevel > 0 {
            let left = s.ownerUpgradeLeft > 0 ? "还可升级 \(s.ownerUpgradeLeft) 个群聊" : "暂无可升级群聊"
            return "当前 \(s.ownerVipLabel.isEmpty ? "会员" : s.ownerVipLabel) · \(left)"
        }
        return "当前普通用户 · 开通 VIP / SVIP 后可升级群聊"
    }

    // MARK: - 入群申请

    private var requestsCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("入群申请").font(.system(size: 14.5, weight: .medium)).foregroundColor(AKColor.text)
                Spacer(minLength: 6)
                Text("\(requests.count) 条待处理").font(.system(size: 12)).foregroundColor(AKColor.red)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)

            ForEach(requests) { r in
                line(leading: 14)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        AvatarView(url: r.avatar, name: r.nickname, size: 36)
                        Text(r.nickname)
                            .font(.system(size: 14.5))
                            .foregroundColor(AKColor.text)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text(TimeText.short(r.createdAt))
                            .font(.system(size: 10.5))
                            .foregroundColor(AKColor.hint)
                    }
                    Text(r.reason.isEmpty ? "未填写理由" : r.reason)
                        .font(.system(size: 12.5))
                        .foregroundColor(AKColor.sub)
                        .lineLimit(2)
                    HStack(spacing: 16) {
                        Button("拒绝") { Task { await handle(r, agree: false) } }
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.hint)
                        Button("同意") { Task { await handle(r, agree: true) } }
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.brand)
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                if r.id != requests.last?.id { line(leading: 14) }
            }
        }
    }

    // MARK: - 成员列表

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(AKColor.hint)
            TextField("搜索群成员昵称", text: $keyword)
                .font(.system(size: 13.5))
                .foregroundColor(AKColor.text)
                .autocorrectionDisabled()
            if !keyword.isEmpty {
                Button {
                    keyword = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AKColor.placeholder)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 36)
        .background(AKColor.fill)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func memberRow(_ m: GroupMember, last: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                AvatarView(url: m.avatar, name: m.name ?? "成员", size: 40)
                HStack(spacing: 4) {
                    Text(m.name ?? "成员")
                        .font(.system(size: 14.5))
                        .foregroundColor(akNameColor(vipLevel: m.vipLevel, isPretty: m.isPretty, isGroup: false))
                        .lineLimit(1)
                    if m.role == 1 {
                        BadgeView(text: "群主", color: AKColor.gold, background: AKColor.goldSoft)
                    } else if m.role == 2 {
                        BadgeView(text: "管理员", color: AKColor.link, background: AKColor.blueSoft)
                    }
                    if m.isPretty == 1, let no = m.prettyNo, !no.isEmpty {
                        PrettyBadge(number: no)
                    }
                    if m.vipLevel > 0 {
                        VipBadge(level: m.vipLevel)
                    }
                }
                Spacer(minLength: 6)
                if canManage && m.uid != myUid {
                    memberMenu(m)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 50)

            if !last {
                line(leading: 70)
            }
        }
    }

    private func memberMenu(_ m: GroupMember) -> some View {
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
            Image(systemName: "ellipsis")
                .font(.system(size: 15))
                .foregroundColor(AKColor.muted)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
    }

    private var inviteRow: some View {
        NavigationLink {
            InviteMembersView(groupId: groupId)
        } label: {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AKColor.fill)
                    RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(AKColor.line, lineWidth: 1)
                    Image(systemName: "plus")
                        .font(.system(size: 18))
                        .foregroundColor(AKColor.muted)
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("邀请好友").font(.system(size: 14.5)).foregroundColor(AKColor.text)
                    Text("多选好友加入本群").font(.system(size: 11.5)).foregroundColor(AKColor.hint)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.placeholder)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 群主操作

    private var ownerCard: some View {
        VStack(spacing: 0) {
            Button {
                showTransfer = true
            } label: {
                HStack(spacing: 6) {
                    Text("转让群主").font(.system(size: 14.5)).foregroundColor(AKColor.text)
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.placeholder)
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            line(leading: 14)

            Button {
                confirmDissolve = true
            } label: {
                Text("解散群聊")
                    .font(.system(size: 14.5))
                    .foregroundColor(AKColor.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var transferSheet: some View {
        NavigationStack {
            List {
                ForEach(members.filter { $0.uid != myUid }) { m in
                    Button {
                        Task { await transfer(m) }
                    } label: {
                        HStack(spacing: 10) {
                            AvatarView(url: m.avatar, name: m.name ?? "成员", size: 36)
                            Text(m.name ?? "成员")
                                .font(.system(size: 14.5))
                                .foregroundColor(AKColor.text)
                            Spacer()
                        }
                        .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle("转让群主")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showTransfer = false }
                }
            }
        }
    }

    // MARK: - 卡片骨架

    @ViewBuilder
    private func block<Content: View>(top: Bool, bottom: Bool, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CardCorners(top: top, bottom: bottom).fill(AKColor.card))
            .padding(.horizontal, 10)
            .padding(.top, top ? 10 : 0)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(AKColor.hint)
            .padding(.leading, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    private func line(leading: CGFloat) -> some View {
        Rectangle()
            .fill(AKColor.line)
            .frame(height: 0.5)
            .padding(.leading, leading)
    }

    // MARK: - 数据

    private func load() async {
        loading = true
        defer { loading = false }
        if let info = try? await APIClient.shared.groupInfo(id: groupId) {
            members = info.members
            groupName = info.name ?? ""
            allowInvite = info.allowInvite
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

/// 卡片背景：首行圆上角、末行圆下角，逐行拼成一张圆角 12 的卡片
private struct CardCorners: Shape {
    var top: Bool
    var bottom: Bool
    var radius: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        let r = radius
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: top ? rect.minY + r : rect.minY))
        if top {
            p.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r,
                     startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
            p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r,
                     startAngle: .degrees(270), endAngle: .degrees(360), clockwise: false)
        } else {
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
        if bottom {
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
            p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r,
                     startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
            p.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r,
                     startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        } else {
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        p.closeSubpath()
        return p
    }
}
