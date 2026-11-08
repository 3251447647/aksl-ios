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
    @State private var info: GroupPreviewInfo?
    @State private var errorText: String?
    @State private var busy = false
    @State private var showReason = false
    @State private var reason = ""
    @State private var applied = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let errorText {
                    Text(errorText).font(.system(size: 13)).foregroundColor(AKColor.red)
                }
                if let g = info {
                    VStack(spacing: 10) {
                        AvatarView(url: g.avatar, name: g.name, size: 64)
                        HStack(spacing: 6) {
                            Text(g.name).font(.system(size: 17, weight: .semibold)).foregroundColor(AKColor.text)
                            if g.isPretty == 1, !g.groupNo.isEmpty { BadgeView(text: "群靓 \(g.groupNo)") }
                        }
                        Text("\(g.groupNo.isEmpty ? "" : "群号：\(g.groupNo)　")\(g.memberCount)/\(g.maxMember) 人")
                            .font(.system(size: 12)).foregroundColor(AKColor.muted)
                        if !g.intro.isEmpty {
                            Text(g.intro)
                                .font(.system(size: 12.5))
                                .foregroundColor(AKColor.sub)
                                .multilineTextAlignment(.center)
                        }
                        if g.isBanned == 1 {
                            Text("该群已被封禁").font(.system(size: 12)).foregroundColor(AKColor.red)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(AKColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if !g.members.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("群成员").font(.system(size: 13, weight: .medium)).foregroundColor(AKColor.sub)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 10) {
                                ForEach(g.members) { m in
                                    VStack(spacing: 4) {
                                        AvatarView(url: m.avatar, name: m.name, size: 40)
                                        Text(m.name).font(.system(size: 10)).foregroundColor(AKColor.muted).lineLimit(1)
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AKColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    if !g.notice.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("群公告").font(.system(size: 13, weight: .medium)).foregroundColor(AKColor.sub)
                            Text(g.notice).font(.system(size: 13)).foregroundColor(AKColor.text)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AKColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Button {
                        Task { await primaryAction(g) }
                    } label: {
                        Text(buttonText(g))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(canTap(g) ? .white : AKColor.muted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(canTap(g) ? AKColor.brand : AKColor.fill)
                            .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                    }
                    .disabled(!canTap(g) || busy)
                } else if errorText == nil {
                    ProgressView().padding(.top, 40)
                }
            }
            .padding(14)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .navigationTitle("群资料")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("填写申请理由", isPresented: $showReason) {
            TextField("例如：朋友推荐", text: $reason)
            Button("取消", role: .cancel) {}
            Button("提交") { Task { await join(needAudit: true) } }
        }
    }

    private func buttonText(_ g: GroupPreviewInfo) -> String {
        if g.isMember == 1 { return "进入群聊" }
        if g.pending == 1 || applied { return "已提交申请" }
        if g.isBanned == 1 { return "该群已被封禁" }
        if g.full == 1 { return "群已满员" }
        return g.needAudit == 1 ? "申请加入" : "加入群聊"
    }

    private func canTap(_ g: GroupPreviewInfo) -> Bool {
        if g.isBanned == 1 || g.full == 1 { return false }
        if g.isMember == 1 { return true }
        return g.pending == 0 && !applied
    }

    private func primaryAction(_ g: GroupPreviewInfo) async {
        if g.isMember == 1 {
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
        busy = true
        defer { busy = false }
        do {
            _ = try await APIClient.shared.joinGroup(id: groupId, reason: needAudit ? reason : "")
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
        do {
            info = try await APIClient.shared.groupPreview(id: groupId)
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }
}
