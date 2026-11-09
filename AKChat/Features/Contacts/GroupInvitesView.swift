import SwiftUI

/// 群通知：入群申请（群主/管理员）+ 邀请我入群（对齐安卓 GroupNoticeScreen）
struct GroupInvitesView: View {
    @State private var tab = 0
    @State private var tabPicked = false
    @State private var invites: [ContactInvite] = []
    @State private var invitePending = 0
    @State private var requests: [ContactJoinRequest] = []
    @State private var refuseRequest: ContactJoinRequest?
    @State private var showRefuse = false
    @State private var refuseReason = ""
    @State private var toastText: String?

    private var pendingInvites: Int { invitePending }
    private var pendingJoin: Int { requests.count }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            if tab == 0 {
                joinRequestPane
            } else {
                invitePane
            }
        }
        .background(AKColor.bg)
        .overlay(alignment: .bottom) { toastView }
        .reportsDetailPage()
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
                    let total = pendingInvites + pendingJoin
                    if total > 0 {
                        Text("\(total) 条待处理")
                            .font(.system(size: 10.5))
                            .foregroundColor(AKColor.red)
                    }
                }
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .alert("拒绝理由（选填）", isPresented: $showRefuse) {
            TextField("告诉对方原因，可不填", text: $refuseReason)
            Button("取消", role: .cancel) {}
            Button("拒绝") {
                if let target = refuseRequest {
                    Task { await handleRequest(target, pass: false, reason: refuseReason) }
                }
            }
        }
    }

    // MARK: - 分段

    private var tabBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabCell(pendingJoin > 0 ? "入群申请 \(pendingJoin)" : "入群申请", 0)
                tabCell(pendingInvites > 0 ? "邀请我入群 \(pendingInvites)" : "邀请我入群", 1)
            }
            Rectangle().fill(AKColor.line).frame(height: 0.6)
        }
        .background(AKColor.card)
    }

    private func tabCell(_ title: String, _ index: Int) -> some View {
        Button {
            tab = index
            tabPicked = true
        } label: {
            VStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 13.5, weight: tab == index ? .semibold : .regular))
                    .foregroundColor(tab == index ? AKColor.text : AKColor.hint)
                Rectangle()
                    .fill(tab == index ? AKColor.brand : Color.clear)
                    .frame(width: 22, height: 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 入群申请

    @ViewBuilder
    private var joinRequestPane: some View {
        if requests.isEmpty {
            Text("暂无待审批的入群申请")
                .font(.system(size: 13))
                .foregroundColor(AKColor.hint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(requests) { r in
                    joinRequestRow(r)
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

    private func joinRequestRow(_ r: ContactJoinRequest) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                NavigationLink {
                    UserProfileView(uid: r.uid).restoresSwipeBack()
                } label: {
                    AvatarView(url: r.avatar, name: r.nickname.isEmpty ? "用户" : r.nickname, size: 46)
                }
                .buttonStyle(.plain)
                .frame(width: 46)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(r.nickname.isEmpty ? "用户" : r.nickname)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AKColor.text)
                            .lineLimit(1)
                        Text("申请加入")
                            .font(.system(size: 11))
                            .foregroundColor(AKColor.hint)
                    }
                    HStack(spacing: 4) {
                        AvatarView(url: r.groupAvatar, name: r.groupName, size: 14)
                        Text(r.groupName)
                            .font(.system(size: 11.5))
                            .foregroundColor(AKColor.sub)
                            .lineLimit(1)
                    }
                    if !r.reason.isEmpty {
                        Text("理由：\(r.reason)")
                            .font(.system(size: 12))
                            .foregroundColor(AKColor.sub)
                            .lineLimit(2)
                    }
                    Text(ContactTimeFormat.short(r.createdAt))
                        .font(.system(size: 10.5))
                        .foregroundColor(AKColor.hint)
                }

                Spacer(minLength: 8)

                Button {
                    refuseReason = ""
                    refuseRequest = r
                    showRefuse = true
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
                    Task { await handleRequest(r, pass: true, reason: "") }
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
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            Rectangle().fill(AKColor.line).frame(height: 0.6).padding(.leading, 74)
        }
    }

    // MARK: - 邀请我入群

    @ViewBuilder
    private var invitePane: some View {
        if invites.isEmpty {
            Text("暂时没有群邀请")
                .font(.system(size: 13))
                .foregroundColor(AKColor.hint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(invites) { inv in
                    inviteRow(inv)
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

    private func inviteRow(_ inv: ContactInvite) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                NavigationLink {
                    GroupPreviewView(groupId: inv.groupId).restoresSwipeBack()
                } label: {
                    HStack(spacing: 12) {
                        AvatarView(url: inv.groupAvatar, name: inv.groupName, size: 46)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(inv.groupName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AKColor.text)
                                    .lineLimit(1)
                                if !inv.groupNo.isEmpty {
                                    Text("群号 \(inv.groupNo)")
                                        .font(.system(size: 10.5))
                                        .foregroundColor(AKColor.hint)
                                        .lineLimit(1)
                                }
                            }
                            Text(inviterLine(inv))
                                .font(.system(size: 12))
                                .foregroundColor(AKColor.sub)
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                statusTag(inv)
                                Text(ContactTimeFormat.short(inv.handledAt > 0 ? inv.handledAt : inv.createdAt))
                                    .font(.system(size: 10.5))
                                    .foregroundColor(AKColor.hint)
                                if inv.memberCount > 0 {
                                    Text("· \(inv.memberCount) 人")
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

                if inv.status == 0 && inv.alive == 1 {
                    Button {
                        Task { await handleInvite(inv, pass: false) }
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
                        Task { await handleInvite(inv, pass: true) }
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
            Rectangle().fill(AKColor.line).frame(height: 0.6).padding(.leading, 74)
        }
    }

    private func inviterLine(_ inv: ContactInvite) -> String {
        var text = "\(inv.inviterName.isEmpty ? "好友" : inv.inviterName) 邀请你加入群聊"
        if inv.status == 0 && inv.needAudit == 1 { text += "（需群主审批）" }
        return text
    }

    private func statusTag(_ inv: ContactInvite) -> some View {
        let text: String
        let color: Color
        let background: Color
        if inv.status == 1 {
            text = "已同意"
            color = Color(hex: 0x0FB67A)
            background = AKColor.brandSoft
        } else if inv.status == 2 {
            text = "已拒绝"
            color = AKColor.muted
            background = AKColor.fill
        } else if inv.alive != 1 {
            text = "群已解散"
            color = AKColor.muted
            background = AKColor.fill
        } else {
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

    // MARK: - 数据

    private func load() async {
        if let data: ContactInvitesData = try? await APIClient.shared.get("api/v1/group/invites") {
            invites = data.list
            invitePending = data.pending
        }
        if let data: ContactJoinRequestsData = try? await APIClient.shared.get("api/v1/group/requests/all") {
            requests = data.list
        }
        // 没有入群申请、只有群邀请时直接停在「邀请我入群」（与安卓一致）
        if !tabPicked && requests.isEmpty && pendingInvites > 0 {
            tab = 1
            tabPicked = true
        }
    }

    private func handleInvite(_ inv: ContactInvite, pass: Bool) async {
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

    private func handleRequest(_ r: ContactJoinRequest, pass: Bool, reason: String) async {
        do {
            let msg = try await APIClient.shared.postRaw(
                "api/v1/group/requests/handle",
                body: [
                    "id": r.groupId,
                    "request_id": r.rid,
                    "act": pass ? "agree" : "refuse",
                    "reason": reason
                ]
            )
            showToast(msg.isEmpty ? (pass ? "已同意加入" : "已拒绝") : msg)
            await load()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    // MARK: - Toast

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

/// 群邀请（含 alive / need_audit / 时间，Core 模型没有这些字段）
struct ContactInvite: Decodable, Identifiable {
    let id: Int64
    let groupId: Int64
    let groupName: String
    let groupAvatar: String
    let groupNo: String
    let memberCount: Int
    let inviterName: String
    let status: Int
    let alive: Int
    let needAudit: Int
    let createdAt: Int64
    let handledAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, status, alive, message
        case groupId = "group_id"
        case groupName = "group_name"
        case groupAvatar = "group_avatar"
        case groupNo = "group_no"
        case memberCount = "member_count"
        case inviterName = "inviter_name"
        case needAudit = "need_audit"
        case createdAt = "created_at"
        case handledAt = "handled_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        groupId = (try? c.decode(Int64.self, forKey: .groupId)) ?? 0
        groupName = (try? c.decode(String.self, forKey: .groupName)) ?? "群聊"
        groupAvatar = (try? c.decode(String.self, forKey: .groupAvatar)) ?? ""
        groupNo = (try? c.decode(String.self, forKey: .groupNo)) ?? ""
        memberCount = (try? c.decode(Int.self, forKey: .memberCount)) ?? 0
        inviterName = (try? c.decode(String.self, forKey: .inviterName)) ?? ""
        status = (try? c.decode(Int.self, forKey: .status)) ?? 0
        alive = (try? c.decode(Int.self, forKey: .alive)) ?? 1
        needAudit = (try? c.decode(Int.self, forKey: .needAudit)) ?? 0
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
        handledAt = (try? c.decode(Int64.self, forKey: .handledAt)) ?? 0
    }
}

struct ContactInvitesData: Decodable {
    let list: [ContactInvite]
    let pending: Int

    enum CodingKeys: String, CodingKey { case list, pending }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decode([ContactInvite].self, forKey: .list)) ?? []
        pending = (try? c.decode(Int.self, forKey: .pending)) ?? 0
    }
}

/// 入群申请（跨群聚合，群通知页用）
struct ContactJoinRequest: Decodable, Identifiable {
    let rid: Int64
    let uid: Int64
    let nickname: String
    let avatar: String
    let reason: String
    let createdAt: Int64
    let groupId: Int64
    let groupName: String
    let groupAvatar: String
    let groupNo: String

    var id: Int64 { rid }

    enum CodingKeys: String, CodingKey {
        case rid, uid, nickname, avatar, reason
        case createdAt = "created_at"
        case groupId = "group_id"
        case groupName = "group_name"
        case groupAvatar = "group_avatar"
        case groupNo = "group_no"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rid = (try? c.decode(Int64.self, forKey: .rid)) ?? 0
        uid = (try? c.decode(Int64.self, forKey: .uid)) ?? 0
        nickname = (try? c.decode(String.self, forKey: .nickname)) ?? ""
        avatar = (try? c.decode(String.self, forKey: .avatar)) ?? ""
        reason = (try? c.decode(String.self, forKey: .reason)) ?? ""
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
        groupId = (try? c.decode(Int64.self, forKey: .groupId)) ?? 0
        groupName = (try? c.decode(String.self, forKey: .groupName)) ?? "群聊"
        groupAvatar = (try? c.decode(String.self, forKey: .groupAvatar)) ?? ""
        groupNo = (try? c.decode(String.self, forKey: .groupNo)) ?? ""
    }
}

struct ContactJoinRequestsData: Decodable {
    let list: [ContactJoinRequest]

    enum CodingKeys: String, CodingKey { case list }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decode([ContactJoinRequest].self, forKey: .list)) ?? []
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
