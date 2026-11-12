import SwiftUI

/// 群拉黑名单：仅群主 / 管理员可进入；解除后有确认弹窗。
/// 样式与 GroupMembersView 的卡片列表保持一致。
struct GroupBlocklistView: View {
    let groupId: Int64

    @State private var list: [GroupBlockedUser] = []
    @State private var loading = true
    @State private var pending: GroupBlockedUser?
    @State private var tipText: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if loading && list.isEmpty {
                    ProgressView().padding(.top, 60)
                } else if list.isEmpty {
                    Text("黑名单为空")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.hint)
                        .padding(.top, 80)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(list.enumerated()), id: \.element.uid) { index, user in
                            row(user)
                            if index < list.count - 1 {
                                Rectangle()
                                    .fill(AKColor.line)
                                    .frame(height: 0.5)
                                    .padding(.leading, 62)
                            }
                        }
                    }
                    .background(AKColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .reportsDetailPage()
        .navigationTitle("黑名单")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
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
        .alert("解除拉黑", isPresented: Binding(
            get: { pending != nil },
            set: { if !$0 { pending = nil } }
        )) {
            Button("取消", role: .cancel) { pending = nil }
            Button("解除", role: .destructive) {
                if let user = pending {
                    pending = nil
                    Task { await unblock(user) }
                }
            }
        } message: {
            Text("解除后「\(pending?.nickname ?? "该用户")」可以重新申请加入本群。确定解除吗？")
        }
    }

    private func row(_ user: GroupBlockedUser) -> some View {
        HStack(spacing: 11) {
            AvatarView(url: user.avatar, name: user.nickname ?? "用户", size: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(user.nickname ?? "用户")
                        .font(.system(size: 15))
                        .foregroundColor(AKColor.text)
                        .lineLimit(1)
                    if user.isPretty == 1, let no = user.prettyNo, !no.isEmpty {
                        PrettyBadge(number: no)
                    }
                    if user.vipLevel > 0 {
                        VipBadge(level: user.vipLevel)
                    }
                }
                Text(subtitle(user))
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.hint)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Button("解除") {
                pending = user
            }
            .font(.system(size: 13))
            .foregroundColor(AKColor.red)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 62)
    }

    private func subtitle(_ user: GroupBlockedUser) -> String {
        var parts: [String] = []
        if let reason = user.reason, !reason.isEmpty {
            parts.append("原因：\(reason)")
        }
        let operatorName = (user.operatorName?.isEmpty == false) ? user.operatorName! : "—"
        parts.append("操作人：\(operatorName)")
        return parts.joined(separator: " · ")
    }

    private func load() async {
        do {
            let data = try await APIClient.shared.groupBlocklist(gid: groupId)
            list = data.list
        } catch {
            tipText = error.localizedDescription
        }
        loading = false
    }

    private func unblock(_ user: GroupBlockedUser) async {
        do {
            _ = try await APIClient.shared.unblockGroupMember(gid: groupId, uid: user.uid)
            list.removeAll { $0.uid == user.uid }
            tipText = "已解除拉黑"
        } catch {
            tipText = error.localizedDescription
        }
    }
}
