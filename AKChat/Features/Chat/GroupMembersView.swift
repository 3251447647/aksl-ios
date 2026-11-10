import SwiftUI
import PhotosUI

/// 群管理设置（含安卓 GroupSettingsResp 的全部字段：四个权限开关、待审批数、成员列表）
struct GroupAdminSettings: Decodable {
    let memberCount: Int
    let maxMember: Int
    let groupMaxMember: Int
    let ownerVipLevel: Int
    let ownerVipLabel: String
    let ownerUpgradeLeft: Int
    let upgradeMaxMember: Int
    let canUpgrade: Int
    let overLimit: Int
    let requestPending: Int
    let isAllMute: Int
    let hideMembers: Int
    let allowInvite: Int
    let needAudit: Int
    let isOwner: Int
    let members: [GroupMember]

    enum CodingKeys: String, CodingKey {
        case members
        case memberCount = "member_count"
        case maxMember = "max_member"
        case groupMaxMember = "group_max_member"
        case ownerVipLevel = "owner_vip_level"
        case ownerVipLabel = "owner_vip_label"
        case ownerUpgradeLeft = "owner_upgrade_left"
        case upgradeMaxMember = "upgrade_max_member"
        case canUpgrade = "can_upgrade"
        case overLimit = "over_limit"
        case requestPending = "request_pending"
        case isAllMute = "is_all_mute"
        case hideMembers = "hide_members"
        case allowInvite = "allow_invite"
        case needAudit = "need_audit"
        case isOwner = "is_owner"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        memberCount = (try? c.decode(Int.self, forKey: .memberCount)) ?? 0
        maxMember = (try? c.decode(Int.self, forKey: .maxMember)) ?? 0
        groupMaxMember = (try? c.decode(Int.self, forKey: .groupMaxMember)) ?? 0
        ownerVipLevel = (try? c.decode(Int.self, forKey: .ownerVipLevel)) ?? 0
        ownerVipLabel = (try? c.decode(String.self, forKey: .ownerVipLabel)) ?? ""
        ownerUpgradeLeft = (try? c.decode(Int.self, forKey: .ownerUpgradeLeft)) ?? 0
        upgradeMaxMember = (try? c.decode(Int.self, forKey: .upgradeMaxMember)) ?? 0
        canUpgrade = (try? c.decode(Int.self, forKey: .canUpgrade)) ?? 0
        overLimit = (try? c.decode(Int.self, forKey: .overLimit)) ?? 0
        requestPending = (try? c.decode(Int.self, forKey: .requestPending)) ?? 0
        isAllMute = (try? c.decode(Int.self, forKey: .isAllMute)) ?? 0
        hideMembers = (try? c.decode(Int.self, forKey: .hideMembers)) ?? 0
        allowInvite = (try? c.decode(Int.self, forKey: .allowInvite)) ?? 1
        needAudit = (try? c.decode(Int.self, forKey: .needAudit)) ?? 0
        isOwner = (try? c.decode(Int.self, forKey: .isOwner)) ?? 0
        members = (try? c.decode([GroupMember].self, forKey: .members)) ?? []
    }
}

/// 群管理：群权限 → 群管理员 / 入群申请 / 聊天背景 → 群等级 → 群主操作（或退出群聊）
/// 分区顺序、文案与颜色对齐安卓 GroupAdminScreen.kt
struct GroupMembersView: View {
    let groupId: Int64
    let myRole: Int
    let myUid: Int64

    @Environment(\.dismiss) private var dismiss
    @State private var members: [GroupMember] = []
    @State private var settings: GroupAdminSettings?
    @State private var loading = true
    @State private var keyword = ""
    @State private var groupName = ""
    @State private var maxMember = 0
    @State private var tipText: String?
    @State private var showTransfer = false
    @State private var showAdminPicker = false
    @State private var confirmDissolve = false
    @State private var confirmUpgrade = false
    @State private var confirmQuit = false
    @State private var adminKeyword = ""
    @State private var overrides: [String: Bool] = [:]
    @State private var chatBg = ""
    @State private var bgItem: PhotosPickerItem?
    @State private var bgMenu = false
    @State private var bgPicker = false

    private var canManage: Bool { myRole == 1 || myRole == 2 }
    private var isOwner: Bool { myRole == 1 }
    private var admins: [GroupMember] { (settings?.members ?? members).filter { $0.role == 2 } }
    private var memberCount: Int { settings?.memberCount ?? members.count }

    private var shown: [GroupMember] {
        let k = keyword.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty else { return members }
        return members.filter { ($0.name ?? "").range(of: k, options: .caseInsensitive) != nil }
    }

    private var adminShown: [GroupMember] {
        let k = adminKeyword.trimmingCharacters(in: .whitespaces)
        let list = (settings?.members ?? members).filter { $0.role != 1 }
        guard !k.isEmpty else { return list }
        return list.filter { ($0.name ?? "").range(of: k, options: .caseInsensitive) != nil }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if canManage {
                    permissionsCard
                }
                if let s = settings {
                    adminCard(s)
                    levelCard(s)
                } else if loading {
                    ProgressView().padding(.top, 60)
                }
                memberCard
                if isOwner {
                    sectionLabel("群主操作")
                    ownerCard
                } else {
                    quitCard
                }
                Color.clear.frame(height: 20)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .reportsDetailPage()
        .navigationTitle("群管理")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .photosPicker(isPresented: $bgPicker, selection: $bgItem, matching: .images)
        .onChange(of: bgItem) { item in
            guard let item else { return }
            Task { await uploadBg(item) }
        }
        .sheet(isPresented: $showTransfer) { transferSheet }
        .sheet(isPresented: $showAdminPicker) { adminPickerSheet }
        .confirmationDialog("聊天背景", isPresented: $bgMenu, titleVisibility: .visible) {
            Button("设置背景") { bgPicker = true }
            if !chatBg.isEmpty {
                Button("恢复默认背景", role: .destructive) { Task { await clearBg() } }
            }
            Button("取消", role: .cancel) {}
        }
        .alert("升级群人数上限", isPresented: $confirmUpgrade) {
            Button("取消", role: .cancel) {}
            Button("确认升级") { Task { await upgrade() } }
        } message: {
            Text("升级后群人数上限提升到 \(settings?.upgradeMaxMember ?? 0) 人，现有成员不受影响。确定升级吗？")
        }
        .alert("解散群聊", isPresented: $confirmDissolve) {
            Button("取消", role: .cancel) {}
            Button("确认解散", role: .destructive) { Task { await dissolve() } }
        } message: {
            Text("解散后所有成员将被移出，且不可恢复。确定解散吗？")
        }
        .alert("退出群聊", isPresented: $confirmQuit) {
            Button("取消", role: .cancel) {}
            Button("退出群聊", role: .destructive) { Task { await quit() } }
        } message: {
            Text("退出后将不再接收「\(groupName)」的消息，聊天记录会一并清除。确定退出吗？")
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

    // MARK: - 群权限

    private var permissionsCard: some View {
        card {
            permissionRow(
                key: "is_all_mute",
                title: "全员禁言",
                subtitle: "开启后仅群主和管理员可以发言",
                server: settings?.isAllMute ?? 0
            )
            divider()
            permissionRow(
                key: "hide_members",
                title: "禁止查看群成员信息",
                subtitle: "开启后普通成员看不到成员列表，也不能查看他人主页",
                server: settings?.hideMembers ?? 0
            )
            divider()
            permissionRow(
                key: "allow_invite",
                title: "允许成员邀请好友进群",
                subtitle: "关闭后仅群主和管理员可以邀请",
                server: settings?.allowInvite ?? 1
            )
            divider()
            permissionRow(
                key: "need_audit",
                title: "进群需要审批",
                subtitle: "开启后申请人需填写理由，由群主或管理员审核",
                server: settings?.needAudit ?? 0
            )
        }
    }

    private func permissionRow(key: String, title: String, subtitle: String, server: Int) -> some View {
        let on = overrides[key] ?? (server == 1)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(AKColor.text)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.hint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Toggle("", isOn: Binding(
                get: { on },
                set: { next in toggle(key, next) }
            ))
            .labelsHidden()
            .tint(AKColor.brand)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 群管理员 / 入群申请 / 聊天背景

    private func adminCard(_ s: GroupAdminSettings) -> some View {
        card {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("群管理员")
                        .font(.system(size: 15))
                        .foregroundColor(AKColor.text)
                    Text(admins.isEmpty ? "未设置" : admins.compactMap { $0.name }.joined(separator: "、"))
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.hint)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                if s.isOwner == 1 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.placeholder)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .contentShape(Rectangle())
            .onTapGesture {
                if s.isOwner == 1 { showAdminPicker = true }
            }

            if s.requestPending > 0 || s.needAudit == 1 {
                divider()
                NavigationLink {
                    GroupRequestsView(groupId: groupId)
                } label: {
                    HStack(spacing: 6) {
                        Text("入群申请")
                            .font(.system(size: 15))
                            .foregroundColor(AKColor.text)
                        Spacer(minLength: 6)
                        Text(s.requestPending > 0 ? "\(s.requestPending) 条待处理" : "暂无")
                            .font(.system(size: 13))
                            .foregroundColor(s.requestPending > 0 ? AKColor.red : AKColor.hint)
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

            divider()
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("聊天背景")
                        .font(.system(size: 15))
                        .foregroundColor(AKColor.text)
                    Text(s.isOwner == 1 ? "群内全员可见，可随时恢复默认" : "由群主设置，全员可见")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.hint)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Text(chatBg.isEmpty ? "默认" : "已设置")
                    .font(.system(size: 13))
                    .foregroundColor(chatBg.isEmpty ? AKColor.hint : AKColor.brand)
                if s.isOwner == 1 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.placeholder)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .contentShape(Rectangle())
            .onTapGesture {
                if s.isOwner == 1 { bgMenu = true }
            }
        }
    }

    // MARK: - 群等级

    private func levelCard(_ s: GroupAdminSettings) -> some View {
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
                        .foregroundColor(s.overLimit == 1 ? AKColor.red : AKColor.text)
                }
                if s.overLimit == 1 {
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

    private func levelHint(_ s: GroupAdminSettings) -> String {
        if s.ownerVipLevel > 0 {
            let label = s.ownerVipLabel.isEmpty ? "会员" : s.ownerVipLabel
            let left = s.ownerUpgradeLeft > 0 ? "还可升级 \(s.ownerUpgradeLeft) 个群聊" : "暂无可升级群聊"
            return "当前 \(label) · \(left)"
        }
        return "当前普通用户 · 开通 VIP / SVIP 后可升级群聊"
    }

    @ViewBuilder
    private func levelAction(_ s: GroupAdminSettings) -> some View {
        if s.isOwner != 1 {
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

    // MARK: - 管理员选择

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
                                    .foregroundColor(m.role == 1 ? AKColor.gold : AKColor.text)
                                    .lineLimit(1)
                                Spacer(minLength: 6)
                                if m.role == 1 {
                                    Text("群主")
                                        .font(.system(size: 11.5))
                                        .foregroundColor(AKColor.gold)
                                } else {
                                    Toggle("", isOn: Binding(
                                        get: { m.role == 2 },
                                        set: { on in Task { await setRole(m, on ? 2 : 0) } }
                                    ))
                                    .labelsHidden()
                                    .tint(AKColor.brand)
                                    .disabled(!isOwner)
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            if idx < adminShown.count - 1 {
                                Rectangle().fill(AKColor.line).frame(height: 0.5).padding(.leading, 62)
                            }
                        }
                        if adminShown.isEmpty {
                            Text((settings?.members ?? members).isEmpty ? "暂无成员" : "没有匹配的成员")
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
                    if idx > 0 { divider(leading: 70) }
                    memberRow(m)
                }
            }

            if (settings?.allowInvite ?? 1) == 1 && keyword.isEmpty {
                divider()
                NavigationLink {
                    InviteMembersView(groupId: groupId)
                } label: {
                    HStack(spacing: 11) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(AKColor.fill)
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
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
            if isOwner {
                if m.role == 2 {
                    Button("取消管理员") { Task { await setRole(m, 0) } }
                } else {
                    Button("设为管理员") { Task { await setRole(m, 2) } }
                }
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

    // MARK: - 群主操作 / 退出

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

    private var quitCard: some View {
        card {
            Button {
                confirmQuit = true
            } label: {
                HStack {
                    Text("退出群聊")
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

                let others = (settings?.members ?? members).filter { $0.role != 1 }
                if others.isEmpty {
                    Text("暂无可转让的成员")
                        .font(.system(size: 12.5))
                        .foregroundColor(AKColor.placeholder)
                        .padding(.top, 40)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(others) { m in
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
            maxMember = info.maxMember
        }
        settings = try? await APIClient.shared.get("api/v1/group/settings", query: ["id": "\(groupId)"])
        if let s = settings {
            maxMember = s.maxMember
            members = s.members.isEmpty ? members : s.members
        }
        if let bg = try? await APIClient.shared.chatBg(convType: "group", convId: groupId) {
            chatBg = bg.bg ?? ""
        }
        overrides = [:]
    }

    private func toggle(_ key: String, _ next: Bool) {
        overrides[key] = next
        Task {
            do {
                _ = try await APIClient.shared.postRaw("api/v1/group/settings", body: [
                    "id": groupId,
                    key: next ? 1 : 0,
                ])
            } catch {
                overrides.removeValue(forKey: key)
                tipText = error.localizedDescription
            }
        }
    }

    private func uploadBg(_ item: PhotosPickerItem) async {
        defer { bgItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let up = try await APIClient.shared.upload(data: data, filename: "bg.jpg", kind: "bg")
            let r = try await APIClient.shared.setChatBg(convType: "group", convId: groupId, url: up.url)
            chatBg = r.bg ?? up.url
            tipText = "群背景已设置"
        } catch {
            tipText = error.localizedDescription
        }
    }

    private func clearBg() async {
        do {
            _ = try await APIClient.shared.setChatBg(convType: "group", convId: groupId, url: "")
            chatBg = ""
            tipText = "已恢复默认背景"
        } catch {
            tipText = error.localizedDescription
        }
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
            try await APIClient.shared.dissolveGroup(gid: groupId, name: groupName)
            tipText = "群聊已解散"
            confirmDissolve = false
        } catch {
            tipText = error.localizedDescription
        }
    }

    private func quit() async {
        await APIClient.shared.quitGroup(id: groupId)
        dismiss()
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

/// 入群申请页：搜索 + 同意 / 拒绝（可填理由）
struct GroupRequestsView: View {
    let groupId: Int64

    @State private var requests: [GroupJoinRequest] = []
    @State private var keyword = ""
    @State private var loading = true
    @State private var tipText: String?
    @State private var refuseTarget: GroupJoinRequest?
    @State private var refuseReason = ""

    private var shown: [GroupJoinRequest] {
        let k = keyword.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty else { return requests }
        return requests.filter { $0.nickname.range(of: k, options: .caseInsensitive) != nil }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(AKColor.hint)
                    TextField("搜索申请人昵称", text: $keyword)
                        .font(.system(size: 13.5))
                        .foregroundColor(AKColor.text)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 11)
                .frame(height: 36)
                .background(AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

                if loading && requests.isEmpty {
                    ProgressView().padding(.top, 50)
                } else if shown.isEmpty {
                    Text(requests.isEmpty ? "暂无待处理的申请" : "没有匹配的申请")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.hint)
                        .padding(.top, 50)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(shown.enumerated()), id: \.element.id) { idx, r in
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
                                    .fixedSize(horizontal: false, vertical: true)
                                HStack(spacing: 8) {
                                    Button("拒绝") {
                                        refuseReason = ""
                                        refuseTarget = r
                                    }
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
                            if idx < shown.count - 1 {
                                Rectangle().fill(AKColor.line).frame(height: 0.5).padding(.leading, 16)
                            }
                        }
                    }
                    .background(AKColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top, 2)
                }
            }
            .padding(.vertical, 4)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .navigationTitle("入群申请")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(item: $refuseTarget) { target in
            VStack(alignment: .leading, spacing: 12) {
                Text("拒绝理由（选填）")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AKColor.text)
                TextField("告诉对方原因，可不填", text: $refuseReason)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(AKColor.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                HStack(spacing: 10) {
                    Button("取消") { refuseTarget = nil }
                        .font(.system(size: 14))
                        .foregroundColor(AKColor.hint)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(AKColor.fill)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .buttonStyle(.plain)
                    Button("拒绝") {
                        let note = refuseReason
                        refuseTarget = nil
                        Task { await handle(target, agree: false, reason: note) }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(AKColor.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .presentationDetents([.height(220)])
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

    private func load() async {
        loading = true
        defer { loading = false }
        requests = (try? await APIClient.shared.groupJoinRequests(gid: groupId))?.list ?? []
    }

    private func handle(_ r: GroupJoinRequest, agree: Bool, reason: String = "") async {
        do {
            try await APIClient.shared.handleGroupRequest(
                gid: groupId, requestId: r.rid, act: agree ? "agree" : "refuse", reason: reason
            )
            tipText = agree ? "已同意" : "已拒绝"
            await load()
        } catch {
            tipText = error.localizedDescription
        }
    }
}

/// 群成员列表：顶部人数、搜索、成员行（群主/管理员角标、群主可切管理员）、末尾邀请格
/// 对齐安卓 GroupMembersScreen.kt
struct GroupMemberListView: View {
    let groupId: Int64
    let myRole: Int
    let myUid: Int64
    /// 群主关闭了成员信息查看：列表仍可见，但不能进主页
    var hidden: Bool = false

    @State private var members: [GroupMember] = []
    @State private var keyword = ""
    @State private var allowInvite = 1
    @State private var loading = true
    @State private var overrides: [Int64: Bool] = [:]

    private var shown: [GroupMember] {
        let k = keyword.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty else { return members }
        return members.filter { ($0.name ?? "").range(of: k, options: .caseInsensitive) != nil }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if hidden {
                    Text("群主已关闭成员信息查看，无法查看主页或添加好友")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.hint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }

                if members.isEmpty {
                    Text(hidden ? "群主已关闭成员信息查看" : (loading ? "加载中…" : "暂无成员"))
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.hint)
                        .padding(.top, 60)
                } else {
                    HStack(spacing: 7) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundColor(AKColor.hint)
                        TextField("搜索群成员昵称 / AK号", text: $keyword)
                            .font(.system(size: 13.5))
                            .foregroundColor(AKColor.text)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 11)
                    .frame(height: 36)
                    .background(AKColor.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)

                    VStack(spacing: 0) {
                        ForEach(Array(shown.enumerated()), id: \.element.id) { idx, m in
                            if idx > 0 {
                                Rectangle().fill(AKColor.line).frame(height: 0.5).padding(.leading, 70)
                            }
                            row(m)
                        }
                        if keyword.isEmpty && !hidden {
                            if allowInvite == 1 {
                                NavigationLink {
                                    InviteMembersView(groupId: groupId)
                                } label: {
                                    HStack(spacing: 11) {
                                        ZStack {
                                            Circle().fill(AKColor.fill)
                                            Circle().strokeBorder(AKColor.line, lineWidth: 1)
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
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            } else {
                                HStack(spacing: 11) {
                                    ZStack {
                                        Circle().fill(AKColor.fill)
                                        Image(systemName: "plus")
                                            .font(.system(size: 17))
                                            .foregroundColor(AKColor.placeholder)
                                    }
                                    .frame(width: 40, height: 40)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("邀请好友")
                                            .font(.system(size: 15))
                                            .foregroundColor(AKColor.muted)
                                        Text("群主已关闭成员邀请，暂无权限")
                                            .font(.system(size: 11.5))
                                            .foregroundColor(AKColor.hint)
                                    }
                                    Spacer(minLength: 6)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                        }
                    }
                    .background(AKColor.card)
                }
            }
        }
        .background(AKColor.bg.ignoresSafeArea())
        .navigationTitle("群成员（\(members.count)）")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func row(_ m: GroupMember) -> some View {
        let isAdmin = overrides[m.uid] ?? (m.role == 2)
        return HStack(spacing: 11) {
            if hidden {
                AvatarView(url: m.avatar, name: m.name ?? "成员", size: 40)
            } else {
                NavigationLink {
                    UserProfileView(uid: m.uid, gid: groupId)
                } label: {
                    AvatarView(url: m.avatar, name: m.name ?? "成员", size: 40)
                }
                .buttonStyle(.plain)
            }
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
            if myRole == 1 && m.role != 1 {
                Toggle("", isOn: Binding(
                    get: { isAdmin },
                    set: { next in setAdmin(m, next) }
                ))
                .labelsHidden()
                .tint(AKColor.brand)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
    }

    private func load() async {
        loading = true
        defer { loading = false }
        if let info = try? await APIClient.shared.groupInfo(id: groupId) {
            members = info.members
            allowInvite = info.allowInvite
        }
    }

    private func setAdmin(_ m: GroupMember, _ next: Bool) {
        overrides[m.uid] = next
        Task {
            await APIClient.shared.setAdmin(gid: groupId, uid: m.uid, role: next ? 2 : 0)
            await load()
        }
    }
}
