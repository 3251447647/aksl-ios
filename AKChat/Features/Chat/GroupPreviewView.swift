import SwiftUI

/// 群预览：未加入时查看群资料并申请/加入（对齐安卓 GroupPreviewScreen）
struct GroupPreviewInfo: Decodable {
    let id: Int64
    let name: String
    let avatar: String
    let intro: String
    let notice: String
    let groupNo: String
    let isPretty: Int
    let memberCount: Int
    let maxMember: Int
    let needAudit: Int
    let hideMembers: Int
    let isBanned: Int
    let full: Int
    let isMember: Int
    let pending: Int
    let owner: PreviewUser?
    let members: [PreviewUser]

    enum CodingKeys: String, CodingKey {
        case id, name, avatar, intro, notice, pending, owner, members, full
        case groupNo = "group_no"
        case isPretty = "is_pretty"
        case memberCount = "member_count"
        case maxMember = "max_member"
        case needAudit = "need_audit"
        case hideMembers = "hide_members"
        case isBanned = "is_banned"
        case isMember = "is_member"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? c.decode(String.self, forKey: .name)) ?? "群聊"
        avatar = (try? c.decode(String.self, forKey: .avatar)) ?? ""
        intro = (try? c.decode(String.self, forKey: .intro)) ?? ""
        notice = (try? c.decode(String.self, forKey: .notice)) ?? ""
        groupNo = (try? c.decode(String.self, forKey: .groupNo)) ?? ""
        isPretty = (try? c.decode(Int.self, forKey: .isPretty)) ?? 0
        memberCount = (try? c.decode(Int.self, forKey: .memberCount)) ?? 0
        maxMember = (try? c.decode(Int.self, forKey: .maxMember)) ?? 0
        needAudit = (try? c.decode(Int.self, forKey: .needAudit)) ?? 0
        hideMembers = (try? c.decode(Int.self, forKey: .hideMembers)) ?? 0
        isBanned = (try? c.decode(Int.self, forKey: .isBanned)) ?? 0
        full = (try? c.decode(Int.self, forKey: .full)) ?? 0
        isMember = (try? c.decode(Int.self, forKey: .isMember)) ?? 0
        pending = (try? c.decode(Int.self, forKey: .pending)) ?? 0
        owner = try? c.decode(PreviewUser.self, forKey: .owner)
        members = (try? c.decode([PreviewUser].self, forKey: .members)) ?? []
    }
}

struct PreviewUser: Decodable, Identifiable {
    let uid: Int64
    let name: String
    let avatar: String
    let role: Int
    var id: Int64 { uid }

    enum CodingKeys: String, CodingKey { case uid, name, avatar, role }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uid = (try? c.decode(Int64.self, forKey: .uid)) ?? 0
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        avatar = (try? c.decode(String.self, forKey: .avatar)) ?? ""
        role = (try? c.decode(Int.self, forKey: .role)) ?? 0
    }
}

extension APIClient {
    func groupPreview(id: Int64) async throws -> GroupPreviewInfo {
        try await get("api/v1/group/preview", query: ["id": "\(id)"])
    }
}

struct GroupPreviewView: View {
    let groupId: Int64
    var onJoined: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppState
    @State private var info: GroupPreviewInfo?
    @State private var errorText: String?
    @State private var loading = true
    @State private var busy = false
    @State private var showReason = false
    @State private var reason = ""
    @State private var applied = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    if let g = info {
                        headerCard(g)
                        if !g.notice.isEmpty || !g.intro.isEmpty {
                            noticeCard(g)
                        }
                        if let o = g.owner {
                            ownerCard(o)
                        }
                        memberCard(g)
                        if let errorText {
                            Text(errorText)
                                .font(.system(size: 12))
                                .foregroundColor(AKColor.red)
                                .padding(.horizontal, 4)
                        }
                    } else if loading {
                        ProgressView().padding(.top, 60)
                    } else {
                        failedState
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
        .reportsDetailPage()
        .navigationTitle("群资料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { BackButton() }
        }
        .task { await load() }
        .alert("填写申请理由", isPresented: $showReason) {
            TextField("例如：朋友推荐", text: $reason)
            Button("取消", role: .cancel) {}
            Button("提交") { Task { await join(needAudit: true) } }
        }
    }

    // MARK: - 卡片

    private func headerCard(_ g: GroupPreviewInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 13) {
                AvatarView(url: g.avatar, name: g.name, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Text(g.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(akNameColor(vipLevel: 0, isPretty: g.isPretty, isGroup: true))
                            .lineLimit(1)
                        if g.isPretty == 1 {
                            PrettyBadge(number: g.groupNo, isGroup: true)
                        }
                    }
                    Text("群号 \(g.groupNo) · \(g.memberCount)/\(g.maxMember)")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.hint)
                }
                Spacer(minLength: 0)
            }
            if g.isBanned == 1 {
                Text("该群已被封禁")
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.red)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func noticeCard(_ g: GroupPreviewInfo) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if !g.notice.isEmpty {
                Text("群公告").font(.system(size: 12.5)).foregroundColor(AKColor.hint)
                Text(g.notice)
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.text)
                    .lineSpacing(3)
                    .lineLimit(4)
            }
            if !g.notice.isEmpty && !g.intro.isEmpty {
                Color.clear.frame(height: 6)
            }
            if !g.intro.isEmpty {
                Text("群简介").font(.system(size: 12.5)).foregroundColor(AKColor.hint)
                Text(g.intro)
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.text)
                    .lineSpacing(3)
                    .lineLimit(4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func ownerCard(_ o: PreviewUser) -> some View {
        HStack(spacing: 9) {
            Text("群主")
                .font(.system(size: 14))
                .foregroundColor(AKColor.sub)
                .frame(width: 54, alignment: .leading)
            AvatarView(url: o.avatar, name: o.name, size: 30)
            Text(o.name)
                .font(.system(size: 14.5))
                .foregroundColor(akNameColor(vipLevel: 0, isPretty: 0, isGroup: false))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func memberCard(_ g: GroupPreviewInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("群成员").font(.system(size: 12.5)).foregroundColor(AKColor.hint)
            if g.hideMembers == 1 {
                Text("群主已关闭成员信息查看")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.hint)
            } else if g.members.isEmpty {
                Text("暂无成员")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.hint)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 12) {
                    ForEach(g.members.prefix(12)) { m in
                        VStack(spacing: 4) {
                            AvatarView(url: m.avatar, name: m.name, size: 44)
                                .overlay(alignment: .bottomTrailing) {
                                    if m.role == 1 {
                                        Text("群")
                                            .font(.system(size: 7.5))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 2)
                                            .background(Color(hex: 0xFF9F0A))
                                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                                            .offset(x: 2, y: 2)
                                    }
                                }
                            Text(m.name)
                                .font(.system(size: 10.5))
                                .foregroundColor(AKColor.hint)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var failedState: some View {
        VStack(spacing: 8) {
            Text("群资料加载失败")
                .font(.system(size: 15))
                .foregroundColor(AKColor.text)
            Text(errorText ?? "请稍后重试")
                .font(.system(size: 12.5))
                .foregroundColor(AKColor.hint)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Button {
                Task { await load() }
            } label: {
                Text("重试")
                    .font(.system(size: 14.5))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .frame(height: 38)
                    .background(AKColor.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
        .padding(.horizontal, 32)
        .padding(.top, 80)
    }

    private func bottomBar(_ g: GroupPreviewInfo) -> some View {
        let enabled = canTap(g)
        return Group {
            if app.user?.isPlatformAdmin == 1 {
                NavigationLink {
                    GroupInfoView(groupId: g.id)
                } label: {
                    Text("群管理")
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(AKColor.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AKColor.card)
            } else {
                Button {
                    Task { await primaryAction(g) }
                } label: {
                    Text(buttonText(g))
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundColor(enabled ? .white : AKColor.hint)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            LinearGradient(
                                colors: enabled ? [AKColor.brand, Color(hex: 0x06AD56)] : [AKColor.line, AKColor.line],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!enabled || busy)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AKColor.card)
            }
        }
    }

    // MARK: - 操作

    private func buttonText(_ g: GroupPreviewInfo) -> String {
        if g.isMember == 1 { return "进入群聊" }
        if g.full == 1 { return "群成员已达上限" }
        if g.pending == 1 || applied { return "已申请，等待审核" }
        return g.needAudit == 1 ? "申请加入" : "加入群聊"
    }

    private func canTap(_ g: GroupPreviewInfo) -> Bool {
        if g.isBanned == 1 || g.full == 1 { return false }
        if g.isMember == 1 { return true }
        return g.pending == 0 && !applied
    }

    private func primaryAction(_ g: GroupPreviewInfo) async {
        if g.isMember == 1 {
            onJoined?()
            dismiss()
            return
        }
        if g.needAudit == 1 {
            showReason = true
            return
        }
        await join(needAudit: false)
    }

    private func join(needAudit: Bool) async {
        let text = reason.trimmingCharacters(in: .whitespaces)
        if needAudit && (text.isEmpty || text.count > 100) {
            errorText = "请填写 1-100 字的进群理由"
            return
        }
        busy = true
        defer { busy = false }
        do {
            _ = try await APIClient.shared.joinGroup(id: groupId, reason: needAudit ? text : "")
            if needAudit {
                applied = true
                showReason = false
            } else {
                await load()
                onJoined?()
            }
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func load() async {
        guard groupId > 0 else {
            loading = false
            errorText = "群名片数据不完整，请让对方重新分享"
            return
        }
        loading = true
        defer { loading = false }
        do {
            info = try await APIClient.shared.groupPreview(id: groupId)
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }
}
