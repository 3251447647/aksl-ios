import SwiftUI
import PhotosUI

/// /group 里 iOS Core 模型没有、但群资料页要用的字段
struct GroupInfoExtras: Decodable {
    let createdAt: Int64
    let recentSpeakers: Int
    let membersHidden: Int
    let hideMembers: Int
    let noticePending: Int
    let needAudit: Int
    let allowInvite: Int

    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case recentSpeakers = "recent_speakers"
        case membersHidden = "members_hidden"
        case hideMembers = "hide_members"
        case noticePending = "notice_pending"
        case needAudit = "need_audit"
        case allowInvite = "allow_invite"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
        recentSpeakers = (try? c.decode(Int.self, forKey: .recentSpeakers)) ?? 0
        membersHidden = (try? c.decode(Int.self, forKey: .membersHidden)) ?? 0
        hideMembers = (try? c.decode(Int.self, forKey: .hideMembers)) ?? 0
        noticePending = (try? c.decode(Int.self, forKey: .noticePending)) ?? 0
        needAudit = (try? c.decode(Int.self, forKey: .needAudit)) ?? 0
        allowInvite = (try? c.decode(Int.self, forKey: .allowInvite)) ?? 1
    }
}

/// 群资料页的两个弹层
private enum GroupInfoSheet: Identifiable {
    case rename
    case report

    var id: Int {
        switch self {
        case .rename: return 0
        case .report: return 1
        }
    }
}

/// 聊天信息（群资料）：封禁条 → 群名/群号 → 群成员宫格 → 群资料（群名称/群公告）
/// → 群管理 → 查找聊天记录 → 会话设置（置顶/免打扰/群昵称）→ 其他（删除记录/退出）→ 举报
/// 顺序、行高 50、卡片圆角 12、分区标题对齐安卓 GroupProfileScreen.kt
struct GroupInfoView: View {
    let groupId: Int64
    var onLeft: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppState
    @State private var info: GroupInfo?
    @State private var extras: GroupInfoExtras?
    @State private var loading = true
    @State private var errorText: String?
    /// /group 返回「你不在该群里」时，安卓会回退到群预览（/group/preview）
    @State private var notMember = false
    @State private var confirmLeave = false
    @State private var confirmDeleteHistory = false
    @State private var showNick = false
    @State private var nickDraft = ""
    @State private var activeSheet: GroupInfoSheet?
    @State private var nameDraft = ""
    @State private var reportReason = ""
    @State private var reportNote = ""
    @State private var avatarItem: PhotosPickerItem?
    @State private var uploadingAvatar = false
    @State private var toastText: String?

    private var isOwner: Bool { (info?.myRole ?? 0) == 1 }
    private var isManager: Bool { isOwner || (info?.myRole ?? 0) == 2 }
    private var myUid: Int64 { app.user?.id ?? 0 }
    private var canInvite: Bool { (info?.allowInvite ?? 1) == 1 || isManager }
    private var membersHidden: Bool {
        guard let g = info else { return false }
        let hidden = (extras?.membersHidden ?? 0) == 1
            || ((extras?.hideMembers ?? 0) == 1 && g.myRole != 1 && g.myRole != 2)
        return hidden
    }
    private var conv: Conversation? {
        app.conversations.first { $0.convType == "group" && $0.convId == groupId }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let g = info {
                    if g.isBanned == 1 { bannedBar(g) }
                    groupHeader(g)
                    membersCard(g)
                    groupDataCard(g)
                    if isManager { managerCard }
                    sectionLabel("聊天")
                    chatCard(g)
                    sectionLabel("会话设置")
                    sessionCard(g)
                    sectionLabel("其他")
                    otherCard(g)
                    Button {
                        reportReason = ""
                        reportNote = ""
                        activeSheet = .report
                    } label: {
                        Text("被骚扰了？举报该群")
                            .font(.system(size: 12.5))
                            .foregroundColor(AKColor.link)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 14)
                    }
                    .buttonStyle(.plain)
                } else if loading {
                    ProgressView().padding(.top, 60)
                } else if let errorText {
                    VStack(spacing: 12) {
                        Text(errorText)
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.red)
                            .multilineTextAlignment(.center)
                        Button {
                            Task { await load() }
                        } label: {
                            Text("重新加载")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AKColor.link)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(AKColor.fill)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        if notMember {
                            NavigationLink {
                                GroupPreviewView(groupId: groupId).restoresSwipeBack()
                            } label: {
                                Text("查看群资料")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(AKColor.brand)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 40)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .reportsDetailPage()
        .navigationTitle("聊天信息")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { BackButton() }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    GroupQRCodeView(groupId: groupId)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(AKColor.text)
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .onChange(of: avatarItem) { item in
            guard let item else { return }
            Task { await uploadAvatar(item) }
        }
        .sheet(item: $activeSheet) { s in
            switch s {
            case .rename:
                renameSheet
            case .report:
                reportSheet
            }
        }
        .alert("修改我在本群的昵称", isPresented: $showNick) {
            TextField("留空则使用昵称", text: $nickDraft)
            Button("取消", role: .cancel) {}
            Button("保存") { Task { await saveNick() } }
        } message: {
            Text("群昵称只在本群内显示。")
        }
        .alert("删除聊天记录", isPresented: $confirmDeleteHistory) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { Task { await deleteHistory() } }
        } message: {
            Text("删除后本机将看不到该群的聊天记录，且无法恢复。确定删除吗？")
        }
        .alert("退出群聊", isPresented: $confirmLeave) {
            Button("取消", role: .cancel) {}
            Button("退出群聊", role: .destructive) {
                Task {
                    await APIClient.shared.quitGroup(id: groupId)
                    onLeft?()
                    dismiss()
                }
            }
        } message: {
            Text("退出后将不再接收「\(info?.name ?? "")」的消息，聊天记录会一并清除。确定退出吗？")
        }
        .overlay(alignment: .bottom) {
            if let toastText {
                Text(toastText)
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

    // MARK: - 封禁提示

    private func bannedBar(_ g: GroupInfo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("该群已被封禁")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(hex: 0xD92D20))
            Text("群内所有成员（包括群主）均无法发送消息，如有疑问请联系在线客服处理"
                 + ((g.banReason ?? "").isEmpty ? "" : "。封禁原因：\(g.banReason ?? "")"))
                .font(.system(size: 12))
                .foregroundColor(Color(hex: 0xB42318))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(AKColor.redSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 群名 / 群号

    private func groupHeader(_ g: GroupInfo) -> some View {
        HStack(spacing: 10) {
            NavigationLink {
                GroupCardProfileView(groupId: groupId)
            } label: {
                HStack(spacing: 14) {
                    PhotosPicker(selection: $avatarItem, matching: .images) {
                        ZStack {
                            AvatarView(url: g.avatar, name: g.name ?? "群聊", size: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            if uploadingAvatar {
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: 56, height: 56)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!isManager)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Text(g.name ?? "群聊")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AKColor.text)
                                .lineLimit(1)
                            if g.isPretty == 1, !(g.prettyGroupNo ?? "").isEmpty {
                                PrettyBadge(number: g.prettyGroupNo ?? "", isGroup: true)
                            }
                        }
                        Text("群号：\(groupNoText(g))")
                            .font(.system(size: 12.5))
                            .foregroundColor(AKColor.hint)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.placeholder)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            NavigationLink {
                GroupQRCodeView(groupId: groupId)
            } label: {
                Image(systemName: "qrcode")
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.sub)
                    .frame(width: 28, height: 28)
                    .background(AKColor.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.card)
    }

    private func groupNoText(_ g: GroupInfo) -> String {
        if let no = g.groupNo, !no.isEmpty { return no }
        return String(g.id)
    }

    // MARK: - 群成员宫格

    private func membersCard(_ g: GroupInfo) -> some View {
        let shown = Array(g.members.prefix(15))
        return card {
            NavigationLink {
                GroupMemberListView(groupId: groupId, myRole: g.myRole, myUid: myUid, hidden: membersHidden)
            } label: {
                HStack(spacing: 6) {
                    Text("群成员")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AKColor.text)
                    Spacer(minLength: 6)
                    Text(g.maxMember > 0 ? "\(g.memberCount)/\(g.maxMember)" : "\(g.memberCount) 人")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.hint)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.placeholder)
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(spacing: 14) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 14) {
                    ForEach(shown) { m in
                        if membersHidden {
                            memberCell(m)
                        } else {
                            NavigationLink {
                                UserProfileView(uid: m.uid, gid: groupId)
                            } label: {
                                memberCell(m)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if canInvite {
                        NavigationLink {
                            InviteMembersView(groupId: groupId)
                        } label: {
                            inviteCell(enabled: true)
                        }
                        .buttonStyle(.plain)
                    } else {
                        inviteCell(enabled: false)
                    }
                }
                if !canInvite {
                    Text("群主已关闭成员邀请，暂无邀请权限")
                        .font(.system(size: 11))
                        .foregroundColor(AKColor.hint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
    }

    private func memberCell(_ m: GroupMember) -> some View {
        VStack(spacing: 5) {
            AvatarView(url: m.avatar, name: m.name ?? "成员", size: 48)
            Text(m.name ?? "成员")
                .font(.system(size: 10.5))
                .foregroundColor(akNameColor(vipLevel: m.vipLevel, isPretty: m.isPretty, isGroup: false))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity)
    }

    private func inviteCell(enabled: Bool) -> some View {
        VStack(spacing: 5) {
            ZStack {
                Circle().fill(AKColor.fill)
                Circle().strokeBorder(AKColor.line, lineWidth: 1)
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(enabled ? AKColor.muted : AKColor.placeholder)
            }
            .frame(width: 48, height: 48)
            Text("邀请")
                .font(.system(size: 10.5))
                .foregroundColor(enabled ? AKColor.hint : AKColor.placeholder)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 群资料（群名称 / 群公告）

    private func groupDataCard(_ g: GroupInfo) -> some View {
        VStack(spacing: 10) {
            sectionLabel("群资料")
            card {
                Button {
                    nameDraft = g.name ?? ""
                    activeSheet = .rename
                } label: {
                    row("群名称", value: g.name ?? "")
                }
                .buttonStyle(.plain)

                divider

                NavigationLink {
                    GroupNoticesView(groupId: groupId)
                } label: {
                    noticeRow(g)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func noticeRow(_ g: GroupInfo) -> some View {
        HStack(alignment: .top, spacing: 8) {
            HStack(spacing: 6) {
                Text("群公告")
                    .font(.system(size: 15))
                    .foregroundColor(AKColor.text)
                if (extras?.noticePending ?? 0) == 1 {
                    Circle()
                        .fill(AKColor.red)
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.top, 1)
            Spacer(minLength: 8)
            Text((g.notice ?? "").isEmpty ? "未设置" : (g.notice ?? ""))
                .font(.system(size: 13))
                .foregroundColor(AKColor.hint)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .frame(maxWidth: 210, alignment: .trailing)
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(AKColor.placeholder)
                .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(minHeight: 50)
        .contentShape(Rectangle())
    }

    private var managerCard: some View {
        NavigationLink {
            GroupMembersView(groupId: groupId, myRole: info?.myRole ?? 0, myUid: myUid)
        } label: {
            HStack(spacing: 6) {
                Text("群管理")
                    .font(.system(size: 15))
                    .foregroundColor(AKColor.text)
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.placeholder)
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AKColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 聊天 / 会话设置 / 其他

    private func chatCard(_ g: GroupInfo) -> some View {
        card {
            NavigationLink {
                MessageSearchView(scopeType: "group", scopeId: groupId, scopeTitle: g.name ?? "群聊")
            } label: {
                row("查找聊天记录", value: "图片、视频、文件等")
            }
            .buttonStyle(.plain)
        }
    }

    private func sessionCard(_ g: GroupInfo) -> some View {
        card {
            toggleRow("设为置顶", key: "is_top", on: conv?.isTop == 1)
            divider
            toggleRow("消息免打扰", key: "is_mute", on: conv?.isMute == 1)
            divider
            Button {
                nickDraft = g.myNickname
                showNick = true
            } label: {
                row("我在本群的昵称", value: g.myNickname.isEmpty ? "未设置" : g.myNickname)
            }
            .buttonStyle(.plain)
        }
    }

    private func otherCard(_ g: GroupInfo) -> some View {
        card {
            Button {
                confirmDeleteHistory = true
            } label: {
                HStack {
                    Text("删除聊天记录")
                        .font(.system(size: 15))
                        .foregroundColor(AKColor.link)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if g.myRole != 1 {
                divider
                Button {
                    confirmLeave = true
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
    }

    private func toggleRow(_ title: String, key: String, on: Bool) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(AKColor.text)
            Spacer(minLength: 0)
            Toggle("", isOn: Binding(
                get: { on },
                set: { want in
                    Task {
                        await APIClient.shared.convSet(convType: "group", convId: groupId,
                                                       key: key, value: want ? 1 : 0)
                        await app.refreshConversations()
                    }
                }
            ))
            .labelsHidden()
            .tint(AKColor.brand)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
    }

    // MARK: - 编辑群名称 / 举报

    private var renameSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("修改群名称")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AKColor.text)
            TextField("输入群名称", text: $nameDraft)
                .font(.system(size: 15))
                .padding(.horizontal, 12)
                .frame(height: 46)
                .background(AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onChange(of: nameDraft) { value in
                    if value.count > 20 { nameDraft = String(value.prefix(20)) }
                }
            HStack(spacing: 10) {
                Button("取消") { activeSheet = nil }
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.hint)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AKColor.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .buttonStyle(.plain)
                Button("保存") { Task { await saveName() } }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AKColor.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .buttonStyle(.plain)
            }
        }
        .padding(18)
        .presentationDetents([.height(230)])
    }

    private var reportSheet: some View {
        let reasons = ["色情低俗", "诈骗/赌博", "骚扰广告", "侵权内容"]
        return VStack(alignment: .leading, spacing: 10) {
            Text("举报该群")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AKColor.text)
            Text("请选择举报原因")
                .font(.system(size: 12))
                .foregroundColor(AKColor.muted)
            ForEach(reasons, id: \.self) { r in
                Button {
                    reportReason = r
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: reportReason == r ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 16))
                            .foregroundColor(reportReason == r ? AKColor.brand : AKColor.placeholder)
                        Text(r)
                            .font(.system(size: 14))
                            .foregroundColor(AKColor.text)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            TextField("补充说明（选填）", text: $reportNote)
                .font(.system(size: 13.5))
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            HStack(spacing: 10) {
                Button("取消") { activeSheet = nil }
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.hint)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AKColor.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .buttonStyle(.plain)
                Button("提交举报") { Task { await submitReport() } }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(reportReason.isEmpty ? AKColor.line : AKColor.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .buttonStyle(.plain)
                    .disabled(reportReason.isEmpty)
            }
        }
        .padding(18)
        .presentationDetents([.height(420)])
    }

    // MARK: - 基础件

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(AKColor.hint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 10)
            .padding(.top, 2)
    }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AKColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func row(_ title: String, value: String? = nil) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(AKColor.text)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.hint)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(AKColor.placeholder)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .contentShape(Rectangle())
    }

    private var divider: some View {
        Rectangle()
            .fill(AKColor.line)
            .frame(height: 0.5)
            .padding(.leading, 16)
    }

    // MARK: - 数据

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            info = try await APIClient.shared.groupInfo(id: groupId)
            extras = try? await APIClient.shared.get("api/v1/group", query: ["id": "\(groupId)"])
            errorText = nil
            notMember = false
        } catch {
            errorText = error.localizedDescription
            notMember = error.localizedDescription.contains("不在该群")
        }
    }

    private func saveNick() async {
        do {
            try await APIClient.shared.setGroupMyNickname(
                gid: groupId, userId: myUid, nickname: nickDraft.trimmingCharacters(in: .whitespaces)
            )
            await load()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    private func saveName() async {
        let next = nameDraft.trimmingCharacters(in: .whitespaces)
        guard !next.isEmpty else {
            showToast("请输入群名称")
            return
        }
        do {
            _ = try await APIClient.shared.postRaw("api/v1/group/update", body: [
                "id": groupId,
                "name": next,
            ])
            activeSheet = nil
            await load()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    private func uploadAvatar(_ item: PhotosPickerItem) async {
        defer { avatarItem = nil }
        uploadingAvatar = true
        defer { uploadingAvatar = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let up = try await APIClient.shared.upload(
                data: data,
                filename: "group_avatar_\(Int(Date().timeIntervalSince1970)).jpg",
                kind: "group"
            )
            _ = try await APIClient.shared.postRaw("api/v1/group/update", body: [
                "id": groupId,
                "avatar": up.url,
            ])
            await load()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    private func deleteHistory() async {
        await APIClient.shared.clearConversation(convType: "group", convId: groupId)
        await app.refreshConversations()
        dismiss()
    }

    private func submitReport() async {
        do {
            let msg = try await APIClient.shared.postRaw("api/v1/report", body: [
                "target_type": "group",
                "target_id": groupId,
                "reason": reportReason,
                "content": reportNote.trimmingCharacters(in: .whitespaces),
            ])
            activeSheet = nil
            showToast(msg.isEmpty ? "已提交，我们会尽快处理" : msg)
        } catch {
            showToast(error.localizedDescription)
        }
    }

    private func showToast(_ message: String) {
        toastText = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if toastText == message { toastText = nil }
        }
    }
}

/// 群资料卡片页（成员视角）：头像/群名/群号/成员情况 + 分享/发消息
/// 对齐安卓 GroupCardProfileScreen.kt
struct GroupCardProfileView: View {
    let groupId: Int64

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppState
    @State private var info: GroupInfo?
    @State private var extras: GroupInfoExtras?
    @State private var errorText: String?
    @State private var toastText: String?

    private var members: [GroupMember] { info?.members ?? [] }
    private var myUid: Int64 { app.user?.id ?? 0 }
    private var admins: [GroupMember] { Array(members.filter { $0.role == 1 || $0.role == 2 }.prefix(6)) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    if let g = info {
                        header(g)
                        memberCard(g)
                        Color.clear.frame(height: 10)
                    } else if let errorText {
                        Text(errorText)
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.red)
                            .padding(.top, 60)
                    } else {
                        ProgressView().padding(.top, 60)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
            if let g = info {
                bottomBar(g)
            }
        }
        .background(AKColor.bg.ignoresSafeArea())
        .navigationTitle("群资料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    GroupQRCodeView(groupId: groupId)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(AKColor.text)
                }
            }
        }
        .task { await load() }
        .overlay(alignment: .bottom) {
            if let toastText {
                Text(toastText)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.72))
                    .clipShape(Capsule())
                    .padding(.bottom, 70)
            }
        }
    }

    private func header(_ g: GroupInfo) -> some View {
        HStack(alignment: .top, spacing: 14) {
            AvatarView(url: g.avatar, name: g.name ?? "群聊", size: 72)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 5) {
                    Text(g.name ?? "群聊")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(akNameColor(vipLevel: 0, isPretty: g.isPretty, isGroup: true))
                        .lineLimit(1)
                    if g.isPretty == 1, !(g.prettyGroupNo ?? "").isEmpty {
                        PrettyBadge(number: g.prettyGroupNo ?? "", isGroup: true)
                    }
                    NavigationLink {
                        GroupQRCodeView(groupId: groupId)
                    } label: {
                        Image(systemName: "qrcode")
                            .font(.system(size: 11))
                            .foregroundColor(AKColor.sub)
                            .frame(width: 22, height: 22)
                            .background(AKColor.fill)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                HStack(spacing: 7) {
                    HStack(spacing: -10) {
                        ForEach(Array(members.prefix(5).enumerated()), id: \.element.id) { idx, m in
                            AvatarView(url: m.avatar, name: m.name ?? "成员", size: 26)
                                .overlay(Circle().stroke(AKColor.card, lineWidth: 1.5))
                                .zIndex(Double(5 - idx))
                        }
                    }
                    Text("\(g.memberCount) 人 · 群号:\(groupNoText(g))")
                        .font(.system(size: 12.5))
                        .foregroundColor(AKColor.hint)
                        .lineLimit(1)
                    Button {
                        UIPasteboard.general.string = groupNoText(g)
                        showToast("群号已复制")
                    } label: {
                        Text("复制")
                            .font(.system(size: 11.5))
                            .foregroundColor(AKColor.link)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(AKColor.brandSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                if let ts = extras?.createdAt, ts > 0 {
                    Text("建群时间: \(joinDate(ts))")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.placeholder)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.card)
    }

    private func memberCard(_ g: GroupInfo) -> some View {
        VStack(spacing: 0) {
            NavigationLink {
                GroupMemberListView(groupId: groupId, myRole: g.myRole, myUid: myUid, hidden: false)
            } label: {
                HStack(spacing: 6) {
                    Text("成员情况")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AKColor.text)
                    Spacer(minLength: 6)
                    if let n = extras?.recentSpeakers, n > 0 {
                        Text("最近有 \(n) 人发言")
                            .font(.system(size: 11.5))
                            .foregroundColor(AKColor.hint)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.placeholder)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if admins.isEmpty {
                Text("暂无成员信息")
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.hint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            } else {
                ForEach(admins) { m in
                    HStack(spacing: 10) {
                        AvatarView(url: m.avatar, name: m.name ?? "成员", size: 42)
                        Text(m.name ?? "成员")
                            .font(.system(size: 14.5))
                            .foregroundColor(akNameColor(vipLevel: m.vipLevel, isPretty: m.isPretty, isGroup: false))
                            .lineLimit(1)
                        Spacer(minLength: 6)
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
            Color.clear.frame(height: 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func bottomBar(_ g: GroupInfo) -> some View {
        HStack(spacing: 10) {
            NavigationLink {
                GroupQRCodeView(groupId: groupId)
            } label: {
                Text("分享群聊")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AKColor.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(AKColor.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                dismiss()
            } label: {
                Text("发消息")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(AKColor.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AKColor.card)
    }

    private func groupNoText(_ g: GroupInfo) -> String {
        if let no = g.groupNo, !no.isEmpty { return no }
        return String(g.id)
    }

    private func joinDate(_ ts: Int64) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }

    private func load() async {
        do {
            info = try await APIClient.shared.groupInfo(id: groupId)
            extras = try? await APIClient.shared.get("api/v1/group", query: ["id": "\(groupId)"])
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func showToast(_ message: String) {
        toastText = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if toastText == message { toastText = nil }
        }
    }
}
