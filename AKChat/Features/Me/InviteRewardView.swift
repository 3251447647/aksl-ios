import SwiftUI
import UIKit

/// 邀请奖励规则（GET /api/v1/invite 的 rules）
struct InviteRule: Decodable, Identifiable {
    let id: Int64
    let needCount: Int
    let rewardType: String
    let rewardName: String
    let rewardDesc: String

    enum CodingKeys: String, CodingKey {
        case id
        case needCount = "need_count"
        case rewardType = "reward_type"
        case rewardName = "reward_name"
        case rewardDesc = "reward_desc"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        needCount = (try? c.decode(Int.self, forKey: .needCount)) ?? 0
        rewardType = (try? c.decode(String.self, forKey: .rewardType)) ?? ""
        rewardName = (try? c.decode(String.self, forKey: .rewardName)) ?? ""
        rewardDesc = (try? c.decode(String.self, forKey: .rewardDesc)) ?? ""
    }
}

/// 已邀请的好友（服务端只返回最近 200 条）
struct Invitee: Decodable, Identifiable {
    let uid: Int64
    let name: String
    let avatar: String
    let prettyNo: String
    let yxId: String
    let createdAt: Int64

    var id: Int64 { uid }

    enum CodingKeys: String, CodingKey {
        case uid, name, avatar
        case prettyNo = "pretty_no"
        case yxId = "yx_id"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uid = (try? c.decode(Int64.self, forKey: .uid)) ?? 0
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        avatar = (try? c.decode(String.self, forKey: .avatar)) ?? ""
        prettyNo = (try? c.decode(String.self, forKey: .prettyNo)) ?? ""
        yxId = (try? c.decode(String.self, forKey: .yxId)) ?? ""
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
    }
}

struct InviteData: Decodable {
    let code: String
    let count: Int
    let rules: [InviteRule]
    let gotIds: [Int64]
    let invitees: [Invitee]
    let inviteUrl: String
    let shareUrl: String

    enum CodingKeys: String, CodingKey {
        case code, count, rules, invitees
        case gotIds = "got_ids"
        case inviteUrl = "invite_url"
        case shareUrl = "share_url"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? c.decode(String.self, forKey: .code)) ?? ""
        count = (try? c.decode(Int.self, forKey: .count)) ?? 0
        rules = (try? c.decode([InviteRule].self, forKey: .rules)) ?? []
        gotIds = (try? c.decode([Int64].self, forKey: .gotIds)) ?? []
        invitees = (try? c.decode([Invitee].self, forKey: .invitees)) ?? []
        inviteUrl = (try? c.decode(String.self, forKey: .inviteUrl)) ?? ""
        shareUrl = (try? c.decode(String.self, forKey: .shareUrl)) ?? ""
    }
}

struct InviteNumber: Decodable, Identifiable {
    let id: Int64
    let number: String

    enum CodingKeys: String, CodingKey { case id, number }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        number = (try? c.decode(String.self, forKey: .number)) ?? ""
    }
}

struct InviteNumbersData: Decodable {
    let list: [InviteNumber]

    enum CodingKeys: String, CodingKey { case list }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decode([InviteNumber].self, forKey: .list)) ?? []
    }
}

extension APIClient {
    func inviteInfo() async throws -> InviteData {
        try await get("api/v1/invite")
    }

    func inviteNumbers(ruleId: Int64) async throws -> InviteNumbersData {
        try await get("api/v1/invite/numbers", query: ["rule_id": "\(ruleId)"])
    }

    func claimInvite(ruleId: Int64, numberId: Int64) async throws -> String {
        try await postRaw("api/v1/invite/claim", body: ["rule_id": ruleId, "number_id": numberId])
    }
}

/// 邀请好友：邀请码 / 已邀请人数 / 奖励领取 / 专属邀请链接 / 邀请记录（对齐安卓 InviteScreen）
struct InviteRewardView: View {
    @EnvironmentObject private var app: AppState

    @State private var data: InviteData?
    @State private var loading = true
    @State private var page = 0
    @State private var claiming = false
    @State private var toastText: String?
    @State private var numbers: [InviteNumber] = []
    @State private var numberRuleId: Int64?
    @State private var showNumbers = false

    private let green = Color(hex: 0x2FA84F)
    private let pageSize = 10

    private var code: String {
        let value = data?.code ?? ""
        return value.isEmpty ? (app.user?.displayNo ?? "") : value
    }

    private var count: Int { data?.count ?? 0 }
    private var rules: [InviteRule] { data?.rules ?? [] }
    private var gotIds: [Int64] { data?.gotIds ?? [] }
    private var invitees: [Invitee] { data?.invitees ?? [] }

    private var pages: Int { max(1, (invitees.count + pageSize - 1) / pageSize) }
    private var currentPage: Int { min(page, pages - 1) }

    private var pageRows: [Invitee] {
        let start = currentPage * pageSize
        guard start < invitees.count else { return [] }
        return Array(invitees[start..<min(start + pageSize, invitees.count)])
    }

    private var hasClaimable: Bool {
        data != nil && rules.contains { $0.needCount <= count && !gotIds.contains($0.id) }
    }

    private var inviteURL: URL? {
        if let value = data?.inviteUrl, !value.isEmpty, let url = URL(string: value) { return url }
        guard !code.isEmpty else { return nil }
        return URL(string: "https://www.aksliao.cn/register.php?invite=\(code)")
    }

    private var inviteLink: String { inviteURL?.absoluteString ?? "" }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                codeCard
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                statsCard
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                sectionHeader("邀请奖励")
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                rewardCard
                    .padding(.horizontal, 14)
                sectionHeader("专属邀请链接（点击复制）")
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                inviteLinkCard
                sectionHeader("邀请记录")
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                recordsCard
                    .padding(.horizontal, 14)
                Spacer().frame(height: 12)
            }
        }
        .background(AKColor.bg.ignoresSafeArea())
        .reportsDetailPage()
        .restoresSwipeBack()
        .navigationTitle("邀请好友")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .overlay(alignment: .bottom) { toastView }
        .sheet(isPresented: $showNumbers) {
            NumberPickerSheet(numbers: numbers) { picked in
                showNumbers = false
                guard let ruleId = numberRuleId else { return }
                Task { await claim(ruleId: ruleId, numberId: picked.id) }
            }
        }
        .task { await load() }
    }

    // MARK: - 邀请码卡

    private var codeCard: some View {
        VStack(alignment: .center, spacing: 0) {
            Text("我的专属邀请码")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.9))
            Text(code.isEmpty ? "-" : code)
                .font(.system(size: 34, weight: .bold))
                .kerning(2)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 10)
            Button {
                copy(code, tip: "邀请码已复制")
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 12, weight: .semibold))
                    Text("复制邀请码")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(green)
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .background(Color.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
            .disabled(code.isEmpty)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color(hex: 0x3FC46E), Color(hex: 0x2AA85C)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 已邀请人数

    private var statsCard: some View {
        HStack(spacing: 0) {
            Text("已成功邀请")
                .font(.system(size: 14.5))
                .foregroundColor(AKColor.text)
            Text("\(count)")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(green)
                .padding(.leading, 6)
            Text("人")
                .font(.system(size: 13))
                .foregroundColor(AKColor.text)
                .padding(.leading, 4)
            Spacer(minLength: 8)
            if hasClaimable {
                Text("🎁 可领取奖励")
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.gold)
            }
        }
        .padding(16)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 邀请奖励

    private var rewardCard: some View {
        VStack(spacing: 0) {
            if rules.isEmpty {
                emptyBox(data == nil && loading ? "加载中…" : "暂无邀请奖励")
            } else {
                ForEach(Array(rules.enumerated()), id: \.element.id) { index, rule in
                    rewardRow(rule)
                    if index < rules.count - 1 {
                        divider(inset: 66)
                    }
                }
            }
        }
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func rewardRow(_ rule: InviteRule) -> some View {
        let need = max(rule.needCount, 0)
        let claimed = gotIds.contains(rule.id)
        let reached = need > 0 && count >= need
        let title = rule.rewardName.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = rule.rewardDesc.trimmingCharacters(in: .whitespacesAndNewlines)
        let condition = desc.isEmpty
            ? (need > 0 ? "成功邀请 \(need) 人" : "邀请好友即可获得")
            : desc

        return Button {
            guard reached && !claimed && !claiming else { return }
            Task { await openClaim(rule) }
        } label: {
            HStack(spacing: 12) {
                Text(rewardIcon(rule))
                    .font(.system(size: 19))
                    .frame(width: 40, height: 40)
                    .background(AKColor.fill)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(title.isEmpty ? "邀请奖励" : title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AKColor.text)
                        .lineLimit(1)
                    Text(condition)
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.hint)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                rewardStatus(claimed: claimed, reached: reached, need: need)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!reached || claimed || claiming)
    }

    @ViewBuilder
    private func rewardStatus(claimed: Bool, reached: Bool, need: Int) -> some View {
        if claimed {
            Text("已领取")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AKColor.hint)
        } else if reached {
            Text("可领取")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(green)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AKColor.brandSoft)
                .clipShape(Capsule())
        } else {
            Text("还差 \(max(need - count, 0)) 人")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AKColor.gold)
        }
    }

    // MARK: - 专属邀请链接

    private var inviteLinkCard: some View {
        Button {
            copy(inviteLink, tip: "邀请链接已复制")
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: 12, weight: .semibold))
                    Text("我的专属邀请链接")
                        .font(.system(size: 12.5, weight: .medium))
                    Spacer(minLength: 8)
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                }
                .foregroundColor(AKColor.hint)
                Text(inviteLink.isEmpty ? "-" : inviteLink)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(green)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("好友打开链接注册会自动绑定你的邀请码，注册成功后引导下载 App")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.hint)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .background(AKColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(inviteLink.isEmpty)
        .padding(.horizontal, 14)
    }

    // MARK: - 邀请记录

    private var recordsCard: some View {
        VStack(spacing: 0) {
            if invitees.isEmpty {
                emptyBox(data == nil && loading ? "加载中…" : "还没有邀请记录")
            } else {
                ForEach(Array(pageRows.enumerated()), id: \.element.id) { index, user in
                    recordRow(user)
                    if index < pageRows.count - 1 {
                        divider(inset: 62)
                    }
                }
                if pages > 1 {
                    pager
                }
            }
        }
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func recordRow(_ user: Invitee) -> some View {
        let pretty = user.prettyNo
        let account = user.yxId.isEmpty ? (pretty.isEmpty ? "-" : pretty) : user.yxId
        let avatar: String? = user.avatar.isEmpty ? nil : user.avatar
        return HStack(spacing: 10) {
            AvatarView(url: avatar,
                       name: user.name.isEmpty ? "好友" : user.name,
                       size: 38)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.system(size: 13.5))
                    .foregroundColor(akNameColor(vipLevel: 0, isPretty: pretty.isEmpty ? 0 : 1, isGroup: false))
                    .lineLimit(1)
                Text("AK号：\(account)")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.hint)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if !pretty.isEmpty {
                PrettyBadge(number: pretty)
            }
        }
        .padding(14)
    }

    private var pager: some View {
        HStack(spacing: 0) {
            Button {
                if currentPage > 0 { page = currentPage - 1 }
            } label: {
                Text("上一页")
                    .font(.system(size: 12.5))
                    .foregroundColor(currentPage > 0 ? green : AKColor.placeholder)
                    .padding(8)
            }
            .buttonStyle(.plain)
            .disabled(currentPage == 0)

            Text("\(currentPage + 1) / \(pages)")
                .font(.system(size: 12))
                .foregroundColor(AKColor.muted)
                .padding(.horizontal, 14)

            Button {
                if currentPage < pages - 1 { page = currentPage + 1 }
            } label: {
                Text("下一页")
                    .font(.system(size: 12.5))
                    .foregroundColor(currentPage < pages - 1 ? green : AKColor.placeholder)
                    .padding(8)
            }
            .buttonStyle(.plain)
            .disabled(currentPage >= pages - 1)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
    }

    // MARK: - 底部栏

    private var bottomBar: some View {
        HStack(spacing: 12) {
            shareButton
            NavigationLink {
                PosterView(name: app.user?.displayName ?? "我",
                           avatar: app.user?.avatar,
                           number: code,
                           uid: app.user?.id ?? 0)
            } label: {
                bottomLabel("保存海报", icon: "arrow.down.to.line", primary: true, enabled: true)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AKColor.card.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(AKColor.line).frame(height: 0.5)
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        if let url = inviteURL {
            ShareLink(item: url) {
                bottomLabel("分享链接", icon: "link", primary: false, enabled: true)
            }
            .buttonStyle(.plain)
        } else {
            bottomLabel("分享链接", icon: "link", primary: false, enabled: false)
        }
    }

    private func bottomLabel(_ title: String, icon: String, primary: Bool, enabled: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.system(size: 15, weight: .medium))
        }
        .foregroundColor(primary ? .white : (enabled ? AKColor.text : AKColor.placeholder))
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background {
            if primary {
                LinearGradient(colors: [Color(hex: 0x43C463), green],
                               startPoint: .leading, endPoint: .trailing)
            } else {
                AKColor.card
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            if !primary {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AKColor.line, lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - 通用组件

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(AKColor.gold)
                .frame(width: 3, height: 14)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AKColor.text)
            Spacer(minLength: 0)
        }
        .padding(.leading, 18)
    }

    private func divider(inset: CGFloat) -> some View {
        Rectangle()
            .fill(AKColor.line)
            .frame(height: 0.5)
            .padding(.leading, inset)
    }

    private func emptyBox(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5))
            .foregroundColor(AKColor.hint)
            .frame(maxWidth: .infinity)
            .frame(height: 80)
    }

    /// 服务端只给类型与名称、没有图标字段，按名称兜底（与安卓一致）
    private func rewardIcon(_ rule: InviteRule) -> String {
        let name = rule.rewardName
        if rule.rewardType == "mall" || name.contains("靓号") { return "🔢" }
        if name.contains("K币") || name.contains("红包") || name.contains("金币") { return "💰" }
        if name.contains("VIP") || name.contains("会员") { return "👑" }
        return "🎁"
    }

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
                    .padding(.bottom, 76)
            }
        }
    }

    // MARK: - 数据与操作

    private func load() async {
        if data == nil { loading = true }
        defer { loading = false }
        do {
            data = try await APIClient.shared.inviteInfo()
            if page > pages - 1 { page = max(pages - 1, 0) }
        } catch {
            showToast(error.localizedDescription)
        }
    }

    private func openClaim(_ rule: InviteRule) async {
        if rule.rewardType == "mall" {
            do {
                let res = try await APIClient.shared.inviteNumbers(ruleId: rule.id)
                guard !res.list.isEmpty else {
                    showToast("暂无可选靓号")
                    return
                }
                numbers = res.list
                numberRuleId = rule.id
                showNumbers = true
            } catch {
                showToast(error.localizedDescription)
            }
        } else {
            await claim(ruleId: rule.id, numberId: 0)
        }
    }

    private func claim(ruleId: Int64, numberId: Int64) async {
        if claiming { return }
        claiming = true
        defer { claiming = false }
        do {
            let msg = try await APIClient.shared.claimInvite(ruleId: ruleId, numberId: numberId)
            showToast(msg.isEmpty ? "领取成功" : msg)
            await load()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    private func copy(_ text: String, tip: String) {
        guard !text.isEmpty else { return }
        UIPasteboard.general.string = text
        showToast(tip)
    }

    private func showToast(_ message: String) {
        toastText = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if toastText == message { toastText = nil }
        }
    }
}

/// 靓号奖励：从服务端可领号码里选一个
private struct NumberPickerSheet: View {
    let numbers: [InviteNumber]
    let onPick: (InviteNumber) -> Void
    @Environment(\.dismiss) private var dismiss

    init(numbers: [InviteNumber], onPick: @escaping (InviteNumber) -> Void) {
        self.numbers = numbers
        self.onPick = onPick
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("选择靓号")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AKColor.text)
                Spacer()
                Button("取消") { dismiss() }
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.sub)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Rectangle()
                .fill(AKColor.line)
                .frame(height: 0.5)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(numbers) { item in
                        Button {
                            onPick(item)
                        } label: {
                            Text(item.number.isEmpty ? "-" : item.number)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(AKColor.text)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Rectangle()
                            .fill(AKColor.line)
                            .frame(height: 0.5)
                            .padding(.leading, 16)
                    }
                }
            }
        }
        .background(AKColor.bg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }
}
