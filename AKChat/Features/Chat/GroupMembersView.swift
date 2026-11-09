import SwiftUI

/// 群管理：群等级 → 群管理员 → 入群申请 → 成员列表 → 群主操作
/// 分区顺序、文案与颜色对齐安卓 GroupAdminScreen.kt / GroupMembersScreen.kt
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
    @State private var maxMember = 0
    @State private var tipText: String?
    @State private var showTransfer = false
    @State private var showAdminPicker = false
    @State private var confirmDissolve = false
    @State private var confirmUpgrade = false
    @State private var dissolveName = ""
    @State private var adminKeyword = ""

    private var canManage: Bool { myRole == 1 || myRole == 2 }
    private var isOwner: Bool { myRole == 1 }
    private var admins: [GroupMember] { members.filter { $0.role == 2 } }
    private var memberCount: Int { settings?.memberCount ?? members.count }

    private var shown: [GroupMember] {
        let k = keyword.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty else { return members }
        return members.filter { ($0.name ?? "").range(of: k, options: .caseInsensitive) != nil }
    }

    private var adminShown: [GroupMember] {
        let k = adminKeyword.trimmingCharacters(in: .whitespaces)
        let list = members.filter { $0.role != 1 }
        guard !k.isEmpty else { return list }
        return list.filter { ($0.name ?? "").range(of: k, options: .caseInsensitive) != nil }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let s = settings {
                    levelCard(s)
                } else if loading {
                    ProgressView().padding(.top, 60)
                }
                if canManage {
                    adminCard
                    requestsCard
                }
                memberCard
                if isOwner {
                    sectionLabel("群主操作")
                    ownerCard
                }
                Color.clear.frame(height: 20)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .navigationTitle(canManage ? "群管理" : "群成员（\(members.count)）")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showTransfer) { transferSheet }
        .sheet(isPresented: $showAdminPicker) { adminPickerSheet }
        .alert("升级群人数上限", isPresented: $confirmUpgrade) {
            Button("取消", role: .cancel) {}
            Button("确认升级") { Task { await upgrade() } }
        } message: {
            Text("升级后群人数上限提升到 \(settings?.upgradeMaxMember ?? 0) 人，现有成员不受影响。确定升级吗？")
        }
        .alert("解散群聊", isPresented: $confirmDissolve) {
            TextField("输入群名称确认", text: $dissolveName)
            Button("取消", role: .cancel) { dissolveName = "" }
            Button("解散", role: .destructive) { Task { await dissolve() } }
        } message: {
            Text("解散后所有成员将被移出，且不可恢复。需输入群名称「\(groupName)」确认")
        }
        .overlay(alignment: .bottom) {
            if let tipText {
                Text(tipText)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.72))
                    .clipShape(Capsule())
                    .padding(.bottom, 18)
            }
        }
    }

    // MARK: - 群等级

    private func levelCard(_ s: GroupSettings) -> some View {
        card {
            HStack(spacing: 6) {
                Text("群等级")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AKColor.text)
                Spacer(minLength: 6)
                Text("群主 \(s.ownerVipLabel.isEmpty ? "普通用户" : s.ownerVipLabel)")
                    .font(.system(size: 12))
                    .foregroundColor(s.ownerVipLevel > 0 ? AKColor.gold : AKColor.hint)
            }
            .padding(.horizontal, 16)
            .frame(height: 50)

            divider()

            VStack(alignment: .leading, spacing: 6) {
                Text(levelHint(s))
                    .font(.system(size: 11.5))
                    .foregroundColor(s.ownerVipLevel > 0 && s.ownerUpgradeLeft > 0 ? AKColor.gold : AKColor.hint)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Text("当前人数")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.sub)
                    Spacer()
                    Text("\(s.memberCount) / \(s.maxMember) 人")
                        .font(.system(size: 13))
                        .foregroundColor(s.memberCount > s.maxMember ? AKColor.red : AKColor.text)
                }
                if s.memberCount > s.maxMember {
                    Text("成员数已超过群主当前等级上限（\(s.maxMember) 人），现有成员不受影响，新成员暂时无法加入。群主续费或升级会员后自动恢复。")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if s.groupMaxMember != s.maxMember {
                    Text("群已开通上限 \(s.groupMaxMember) 人，受群主当前等级限制")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.hint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                levelAction(s)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func levelHint(_ s: GroupSettings) -> String {
        if s.ownerVipLevel > 0 {
            let label = s.ownerVipLabel.isEmpty ? "会员" : s.ownerVipLabel
            let left = s.ownerUpgradeLeft > 0 ? "还可升级 \(s.ownerUpgradeLeft) 个群聊" : "暂无可升级群聊"
            return "当前 \(label) · \(left)"
        }
        return "当前普通用户 · 开通 VIP / SVIP 后可升级群聊"
    }

    @ViewBuilder
    private func levelAction(_ s: GroupSettings) -> some View {
        if !isOwner {
            Text("仅群主可以升级群人数上限")
                .font(.system(size: 12))
                .foregroundColor(AKColor.hint)
                .padding(.top, 6)
        } else if s.canUpgrade == 1 {
            Button {
                confirmUpgrade = true
            } label: {
                Text("升级到 \(s.ownerVipLabel.isEmpty ? "会员" : s.ownerVipLabel) 群（\(s.upgradeMaxMember) 人）")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(AKColor.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        } else if s.ownerVipLevel == 0 {
            Text("群主开通 VIP / SVIP 后可将群人数上限升级到 \(s.upgradeMaxMember) 人")
                .font(.system(size: 12))
                .foregroundColor(AKColor.hint)
                .padding(.top, 6)
        } else {
            Text("已是当前等级最高档位（\(s.groupMaxMember) 人）")
                .font(.system(size: 12))
                .foregroundColor(AKColor.hint)
                .padding(.top, 6)
        }
    }

    // MARK: - 群管理员

    private var adminCard: some View {
        card {
            HStack(spacing: 6) {
                Text("群管理员")
                    .font(.system(size: 15))
                    .foregroundColor(AKColor.text)
                Spacer(minLength: 6)
                Text(admins.isEmpty ? "未设置" : admins.compactMap { $0.name }.joined(separator: "、"))
                    .font(.system(size: 13))
                    .foregroundColor(admins.isEmpty ? AKColor.hint : AKColor.sub)
                    .lineLimit(1)
                if isOwner {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.placeholder)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .contentShape(Rectangle())
            .onTapGesture {
                if isOwner { showAdminPicker = true }
            }

            ForEach(admins) { m in
                divider(leading: 60)
                HStack(spacing: 10) {
                    AvatarView(url: m.avatar, name: m.name ?? "成员", size: 36)
                    Text(m.name ?? "成员")
                        .font(.system(size: 14.5))
                        .foregroundColor(akNameColor(vipLevel: m.vipLevel, isPretty: m.isPretty, isGroup: false))
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    if isOwner {
                        Button("取消管理员") { Task { await setRole(m, 0) } }
                            .font(.system(size: 12.5))
                            .foregroundColor(AKColor.hint)
                            .buttonStyle(.plain)
                    } else {
                        Text("管理员")
                            .font(.system(size: 11.5))
                            .foregroundColor(AKColor.link)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
            }

            if isOwner {
                divider()
                Button {
                    showAdminPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Text("设置群管理员")
                            .font(.system(size: 15))
                            .foregroundColor(AKColor.link)
                        Spacer(minLength: 6)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(AKColor.placeholder)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var adminPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("管理员可以撤回成员消息、禁言与审核入群申请。")
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.hint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                searchBar(text: $adminKeyword, placeholder: "搜索成员昵称 / AK号")

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(adminShown.enumerated()), id: \.element.id) { idx, m in
                            HStack(spacing: 10) {
                                AvatarView(url: m.avatar, name: m.name ?? "成员", size: 36)
                                Text(m.name ?? "成员")
                                    .font(.system(size: 14.5))
                                    .foregroundColor(AKColor.text)
                                    .lineLimit(1)
                                Spacer(minLength: 6)
                                Toggle("", isOn: Binding(
                                    get: { m.role == 2 },
                                    set: { on in Task { await setRole(m, on ? 2 : 0) } }
                                ))
                                .labelsHidden()
                                .tint(AKColor.brand)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            if idx < adminShown.count - 1 {
                                Rectangle().fill(AKColor.line).frame(height: 0.5).padding(.leading, 62)
                            }
                        }
                        if adminShown.isEmpty {
                            Text(members.isEmpty ? "暂无成员" : "没有匹配的成员")
                                .font(.system(size: 13))
                                .foregroundColor(AKColor.hint)
                                .padding(.top, 40)
                        }
                    }
                    .background(AKColor.card)
                }
            }
            .background(AKColor.bg.ignoresSafeArea())
            .navigationTitle("设置群管理员")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showAdminPicker = false }
                }
            }
        }
    }

    // MARK: - 入群申请

    private var requestsCard: some View {
        card {
            HStack(spacing: 6) {
                Text("入群申请")
                    .font(.system(size: 15))
                    .foregroundColor(AKColor.text)
                Spacer(minLength: 6)
                Text(requests.isEmpty ? "暂无" : "\(requests.count) 条待处理")
                    .font(.system(size: 13))
                    .foregroundColor(requests.isEmpty ? AKColor.hint : AKColor.red)
            }
            .padding(.horizontal, 16)
            .frame(height: 50)

            if !requests.isEmpty {
                ForEach(requests) { r in
                    divider()
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            AvatarView(url: r.avatar, name: r.nickname, size: 36)
                            Text(r.nickname)
                                .font(.system(size: 14.5))
                                .foregroundColor(AKColor.text)
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            Text(TimeText.full(r.createdAt))
                                .font(.system(size: 10.5))
                                .foregroundColor(AKColor.hint)
                        }
                        Text(r.reason.isEmpty ? "未填写理由" : r.reason)
                            .font(.system(size: 12.5))
                            .foregroundColor(AKColor.sub)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            Button("拒绝") { Task { await handle(r, agree: false) } }
                                .font(.system(size: 13))
                                .foregroundColor(AKColor.hint)
                            Button("同意") { Task { await handle(r, agree: true) } }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AKColor.brand)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - 成员列表

    private var memberCard: some View {
        card {
            HStack(spacing: 6) {
                Text("群成员")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AKColor.text)
                Spacer(minLength: 6)
                Text(maxMember > 0 ? "\(memberCount)/\(maxMember)" : "\(memberCount) 人")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.hint)
            }
            .padding(.horizontal, 16)
            .frame(height: 50)

            searchBar(text: $keyword, placeholder: "搜索群成员昵称 / AK号")

            if shown.isEmpty {
                Text(members.isEmpty ? "暂无成员" : "没有匹配的成员")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.hint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                ForEach(Array(shown.enumerated()), id: \.element.id) { idx, m in
                    if idx > 0 { divider(leading: 66) }
                    memberRow(m)
                }
            }

            if allowInvite == 1 && keyword.isEmpty {
                divider()
                NavigationLink {
                    InviteMembersView(groupId: groupId)
                } label: {
                    HStack(spacing: 11) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AKColor.fill)
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(AKColor.line, lineWidth: 1)
                            Image(systemName: "plus")
                                .font(.system(size: 17))
                                .foregroundColor(AKColor.muted)
                        }
                        .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("邀请好友")
                                .font(.system(size: 15))
                                .foregroundColor(AKColor.text)
                            Text("多选好友加入本群")
                                .font(.system(size: 11.5))
                                .foregroundColor(AKColor.hint)
                        }
                        Spacer(minLength: 6)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func memberRow(_ m: GroupMember) -> some View {
        HStack(spacing: 11) {
            AvatarView(url: m.avatar, name: m.name ?? "成员", size: 40)
            HStack(spacing: 4) {
                Text(m.name ?? "成员")
                    .font(.system(size: 15))
                    .foregroundColor(akNameColor(vipLevel: m.vipLevel, isPretty: m.isPretty, isGroup: false))
                    .lineLimit(1)
                if m.role == 1 || m.role == 2 {
                    RoleBadge(role: m.role)
                }
                if m.isPretty == 1, let no = m.prettyNo, !no.isEmpty {
                    PrettyBadge(number: no)
                }
                if m.vipLevel > 0 {
                    VipBadge(level: m.vipLevel)
                }
            }
            Spacer(minLength: 6)
            if canManage && m.uid != myUid && m.role != 1 {
                memberMenu(m)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }

    private func memberMenu(_ m: GroupMember) -> some View {
        Menu {
            Button("禁言 10 分钟") { Task { await mute(m, 10) } }
            Button("禁言 1 小时") { Task { await mute(m, 60) } }
            Button("禁言 1 天") { Task { await mute(m, 1440) } }
            Button("解除禁言") { Task { await mute(m, 0) } }
            if m.role == 2 {
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

    // MARK: - 群主操作

    private var ownerCard: some View {
        card {
            Button {
                showTransfer = true
            } label: {
                HStack(spacing: 6) {
                    Text("转让群主")
                        .font(.system(size: 15))
                        .foregroundColor(AKColor.text)
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.placeholder)
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            divider()

            Button {
                confirmDissolve = true
            } label: {
                HStack {
                    Text("解散群聊")
                        .font(.system(size: 15))
                        .foregroundColor(AKColor.red)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var transferSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("转让群主")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AKColor.text)
                    Text("转让后你将成为普通成员，仅群主可操作")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 8)

                if members.filter({ $0.uid != myUid }).isEmpty {
                    Text("暂无可转让的成员")
                        .font(.system(size: 12.5))
                        .foregroundColor(AKColor.placeholder)
                        .padding(.top, 40)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(members.filter { $0.uid != myUid }) { m in
                                Button {
                                    Task { await transfer(m) }
                                } label: {
                                    HStack(spacing: 10) {
                                        AvatarView(url: m.avatar, name: m.name ?? "成员", size: 38)
                                        Text(m.name ?? "群成员")
                                            .font(.system(size: 14))
                                            .foregroundColor(AKColor.text)
                                            .lineLimit(1)
                                        Spacer(minLength: 6)
                                    }
                                    .padding(.horizontal, 18)
                                    .frame(height: 50)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .background(AKColor.bg.ignoresSafeArea())
            .navigationTitle("转让群主")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showTransfer = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - 基础件

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AKColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func divider(leading: CGFloat = 14) -> some View {
        Rectangle()
            .fill(AKColor.line)
            .frame(height: 0.5)
            .padding(.leading, leading)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(AKColor.hint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 10)
            .padding(.top, 2)
    }

    private func searchBar(text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(AKColor.hint)
            TextField(placeholder, text: text)
                .font(.system(size: 13.5))
                .foregroundColor(AKColor.text)
                .autocorrectionDisabled()
            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
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

    // MARK: - 数据

    private func load() async {
        loading = true
        defer { loading = false }
        if let info = try? await APIClient.shared.groupInfo(id: groupId) {
            members = info.members
            groupName = info.name ?? ""
            allowInvite = info.allowInvite
            maxMember = info.maxMember
        }
        if canManage {
            requests = (try? await APIClient.shared.groupJoinRequests(gid: groupId))?.list ?? []
        }
        settings = try? await APIClient.shared.groupSettings(gid: groupId)
    }

    private func upgrade() async {
        do {
            try await APIClient.shared.upgradeGroup(gid: groupId)
            tipText = "群人数上限已升级"
            await load()
        } catch {
            tipText = error.localizedDescription
        }
    }

    private func handle(_ r: GroupJoinRequest, agree: Bool) async {
        do {
            try await APIClient.shared.handleGroupRequest(gid: groupId, requestId: r.rid, act: agree ? "agree" : "refuse")
            tipText = agree ? "已同意" : "已拒绝"
            await load()
        } catch {
            tipText = error.localizedDescription
        }
    }

    private func transfer(_ m: GroupMember) async {
        do {
            try await APIClient.shared.transferGroup(gid: groupId, toUid: m.uid)
            tipText = "已转让群主"
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
            confirmDissolve = false
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
