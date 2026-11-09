import SwiftUI
import Foundation

/* ================= 礼物目录（GET /api/v1/gifts） ================= */

/// 服务端礼物字段：type=pretty 为靓号（yx_mall_number），type=vip 为会员套餐（yx_vip_plan）
struct GiftItem: Decodable, Identifiable {
    let id: Int64
    let name: String
    let type: String
    let coin: Int
    let days: Int
    let level: Int
    let enabled: Int
    let sort: Int

    /// 靓号与套餐的 id 来自不同表，列表身份按 type+id 区分
    var stableKey: String { "\(type)_\(id)" }
    /// 旧调用方按 price 取值；服务端实际字段是 coin
    var price: Int { coin }

    enum CodingKeys: String, CodingKey { case id, name, type, coin, days, level, enabled, sort }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? c.decode(String.self, forKey: .name)) ?? "礼物"
        type = (try? c.decode(String.self, forKey: .type)) ?? "pretty"
        coin = (try? c.decode(Int.self, forKey: .coin)) ?? 0
        days = (try? c.decode(Int.self, forKey: .days)) ?? 0
        level = (try? c.decode(Int.self, forKey: .level)) ?? 1
        enabled = (try? c.decode(Int.self, forKey: .enabled)) ?? 1
        sort = (try? c.decode(Int.self, forKey: .sort)) ?? 0
    }
}

struct GiftCategory: Decodable, Identifiable {
    let id: Int64
    let name: String
    let type: String
    let gifts: [GiftItem]

    enum CodingKeys: String, CodingKey { case id, name, type, gifts }

    init(id: Int64, name: String, type: String = "pretty", gifts: [GiftItem]) {
        self.id = id
        self.name = name
        self.type = type
        self.gifts = gifts
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        type = (try? c.decode(String.self, forKey: .type)) ?? "pretty"
        gifts = (try? c.decode([GiftItem].self, forKey: .gifts)) ?? []
    }
}

struct GiftListData: Decodable {
    let list: [GiftItem]
    let categories: [GiftCategory]

    enum CodingKeys: String, CodingKey { case list, categories }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decode([GiftItem].self, forKey: .list)) ?? []
        categories = (try? c.decode([GiftCategory].self, forKey: .categories)) ?? []
    }
}

extension APIClient {
    func sendRedPacket(convType: String, convId: Int64, coin: Int, count: Int,
                       rpType: Int, blessing: String, password: String) async throws {
        _ = try await postRaw("api/v1/redpacket/send", body: [
            "conv_type": convType,
            "conv_id": convId,
            "coin": coin,
            "count": count,
            "rp_type": rpType,
            "blessing": blessing,
            "pay_password": password
        ])
    }

    func sendTransfer(convType: String, convId: Int64, toUid: Int64, coin: Int,
                      remark: String, password: String) async throws {
        _ = try await postRaw("api/v1/transfer/send", body: [
            "conv_type": convType,
            "conv_id": convId,
            "to_uid": toUid,
            "coin": coin,
            "remark": remark,
            "pay_password": password
        ])
    }

    func gifts() async throws -> GiftListData {
        try await get("api/v1/gifts")
    }

    func sendGift(convType: String, convId: Int64, toUid: Int64, giftType: String,
                  giftId: Int64, count: Int, password: String) async throws {
        _ = try await postRaw("api/v1/gift/send", body: [
            "conv_type": convType,
            "conv_id": convId,
            "to_uid": toUid,
            "gift_type": giftType,
            "gift_id": giftId,
            "count": count,
            "pay_password": password
        ])
    }
}

/* ================= 公用控件（对齐安卓 PayUi.kt） ================= */

private struct PaySheetHeader: View {
    let title: String
    let onClose: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AKColor.text)
            Spacer(minLength: 8)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AKColor.muted)
                    .frame(width: 30, height: 30)
                    .background(AKColor.fill)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }
}

/// 圆角灰底输入框：只收数字的金额/密码与普通文本共用
private struct PayInputField: View {
    let placeholder: String
    @Binding var text: String
    var limit: Int = 6
    var fontSize: CGFloat = 24
    var weight: Font.Weight = .bold
    var height: CGFloat = 52
    var secure = false
    var digitsOnly = true

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AKColor.fill)
            Group {
                if secure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .font(.system(size: fontSize, weight: weight))
            .foregroundColor(AKColor.text)
            .keyboardType(digitsOnly ? .numberPad : .default)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)

            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: fontSize, weight: weight))
                    .foregroundColor(AKColor.placeholder)
                    .padding(.horizontal, 14)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .contentShape(Rectangle())
        .onChange(of: text) { value in
            var next = value
            if digitsOnly { next = String(next.filter { $0.isNumber }) }
            if next.count > limit { next = String(next.prefix(limit)) }
            if next != value { text = next }
        }
    }
}

private struct PayGradientButton: View {
    let title: String
    let colors: [Color]
    let busy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(busy ? "处理中…" : title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .opacity(busy ? 0.72 : 1)
    }
}

private struct PayErrorLine: View {
    let text: String?

    var body: some View {
        if let text, !text.isEmpty {
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(AKColor.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private func payBalanceText(_ coin: Int64?) -> String {
    let text = coin.map { String($0) } ?? "--"
    return "余额 \(text) K币 · 仅支持整数"
}

/// 群内选人（转账收款人 / 礼物收礼人），对齐安卓 MemberPicker
private struct PayMemberPicker: View {
    let members: [GroupMember]
    @Binding var picked: Int64
    var loading: Bool

    @State private var keyword = ""

    private var filtered: [GroupMember] {
        let q = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return members }
        return members.filter { m in
            (m.name ?? "").localizedCaseInsensitiveContains(q)
                || (m.prettyNo ?? "").localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("选择成员")
                .font(.system(size: 12))
                .foregroundColor(AKColor.muted)
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.placeholder)
                TextField("搜索昵称 / AK号", text: $keyword)
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !keyword.isEmpty {
                    Button {
                        keyword = ""
                    } label: {
                        Text("✕")
                            .font(.system(size: 12))
                            .foregroundColor(AKColor.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 11)
            .frame(height: 38)
            .background(AKColor.fill)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if loading {
                emptyRow("加载中…")
            } else if members.isEmpty {
                emptyRow("暂无群成员")
            } else if filtered.isEmpty {
                emptyRow("没有匹配的成员")
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(filtered) { m in
                            memberRow(m)
                        }
                    }
                }
                .frame(maxHeight: 208)
                .scrollIndicators(.hidden)
            }
        }
    }

    private func emptyRow(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(AKColor.placeholder)
            Spacer()
        }
        .frame(height: 64)
    }

    private func memberRow(_ m: GroupMember) -> some View {
        let active = m.uid == picked
        let name = (m.name?.isEmpty == false ? m.name! : "成员")
        let idText = (m.prettyNo?.isEmpty == false ? m.prettyNo! : "")
        let roleText = m.role == 1 ? "群主" : (m.role == 2 ? "管理员" : "")
        return Button {
            picked = m.uid
        } label: {
            HStack(spacing: 9) {
                AvatarView(url: m.avatar, name: name, size: 34)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 13.5))
                        .foregroundColor(active ? AKColor.brand : AKColor.text)
                        .lineLimit(1)
                    if !roleText.isEmpty || !idText.isEmpty {
                        HStack(spacing: 5) {
                            if !roleText.isEmpty {
                                Text(roleText)
                                    .font(.system(size: 9))
                                    .foregroundColor(m.role == 1 ? AKColor.gold : AKColor.link)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(m.role == 1 ? AKColor.goldSoft : AKColor.blueSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            if !idText.isEmpty {
                                Text("AK号 \(idText)")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(AKColor.muted)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                Spacer(minLength: 6)
                if active {
                    Text("✓")
                        .font(.system(size: 14))
                        .foregroundColor(AKColor.brand)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(active ? AKColor.brandSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/* ================= 发红包 ================= */

/// 发红包：金额 + 个数 + 祝福语 + 支付密码（对齐安卓 RedPacketDialog）
struct RedPacketSheet: View {
    let convType: String
    let convId: Int64
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppState
    @State private var amount = ""
    @State private var count = "1"
    @State private var rpType = 1
    @State private var blessing = "恭喜发财，大吉大利"
    @State private var password = ""
    @State private var balance: Int64?
    @State private var busy = false
    @State private var errorText: String?

    private var isGroup: Bool { convType == "group" }

    var body: some View {
        VStack(spacing: 0) {
            PaySheetHeader(title: "发红包") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isGroup {
                        rpTypeSwitch
                        Spacer().frame(height: 14)
                    }

                    HStack(spacing: 8) {
                        Text("¥")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AKColor.red)
                        PayInputField(placeholder: "0", text: $amount, limit: 6,
                                      fontSize: 24, weight: .bold, height: 52)
                    }

                    Spacer().frame(height: 6)
                    Text(payBalanceText(balance))
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.muted)

                    if isGroup {
                        Spacer().frame(height: 12)
                        HStack(spacing: 10) {
                            Text("红包个数")
                                .font(.system(size: 13))
                                .foregroundColor(AKColor.sub)
                            Spacer(minLength: 8)
                            PayInputField(placeholder: "1", text: $count, limit: 3,
                                          fontSize: 15, weight: .regular, height: 40)
                                .frame(width: 90)
                        }
                    }

                    Spacer().frame(height: 12)
                    PayInputField(placeholder: "恭喜发财，大吉大利", text: $blessing, limit: 30,
                                  fontSize: 14, weight: .regular, height: 44, digitsOnly: false)

                    Spacer().frame(height: 12)
                    PayInputField(placeholder: "支付密码", text: $password, limit: 8,
                                  fontSize: 14, weight: .regular, height: 44, secure: true)

                    if let errorText, !errorText.isEmpty {
                        Spacer().frame(height: 10)
                        PayErrorLine(text: errorText)
                    }

                    Spacer().frame(height: 18)
                    PayGradientButton(title: "塞钱进红包",
                                      colors: [AKColor.red, Color(hex: 0xC93028)],
                                      busy: busy) {
                        Task { await send() }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 26)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(AKColor.card)
        .presentationDragIndicator(.visible)
        .task { await loadBalance() }
    }

    private var rpTypeSwitch: some View {
        let titles = ["拼手气红包", "普通红包"]
        return HStack(spacing: 0) {
            ForEach(titles.indices, id: \.self) { index in
                let value = index + 1
                Button {
                    rpType = value
                } label: {
                    Text(titles[index])
                        .font(.system(size: 13, weight: rpType == value ? .medium : .regular))
                        .foregroundColor(rpType == value ? AKColor.red : AKColor.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(rpType == value ? AKColor.card : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(AKColor.fill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func loadBalance() async {
        if let wallet = try? await APIClient.shared.walletInfo() {
            balance = wallet.coin
        }
    }

    private func send() async {
        guard !busy else { return }
        let coin = Int64(amount) ?? 0
        guard coin > 0 else {
            errorText = "请输入红包金额"
            return
        }
        if let balance, coin > balance {
            errorText = "K币不足，请先充值"
            return
        }
        let num = isGroup ? max(Int(count) ?? 1, 1) : 1
        if isGroup && coin < Int64(num) {
            errorText = "平均金额不能低于 1 K币"
            return
        }
        busy = true
        defer { busy = false }
        do {
            try await APIClient.shared.sendRedPacket(
                convType: convType,
                convId: convId,
                coin: Int(coin),
                count: num,
                rpType: isGroup ? rpType : 2,
                blessing: blessing,
                password: password
            )
            refreshMe()
            onDone()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func refreshMe() {
        Task {
            if let me = try? await APIClient.shared.me() {
                app.user = me
                SessionStore.shared.user = me
            }
        }
    }
}

/* ================= 转账 ================= */

/// 转账：群聊先选收款人 + 金额 + 支付密码（对齐安卓 TransferDialog）
struct TransferSheet: View {
    let convType: String
    let convId: Int64
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppState
    @State private var amount = ""
    @State private var password = ""
    @State private var toUid: Int64 = 0
    @State private var members: [GroupMember] = []
    @State private var loadingMembers = false
    @State private var balance: Int64?
    @State private var busy = false
    @State private var errorText: String?

    private var isGroup: Bool { convType == "group" }
    private var myId: Int64 { app.user?.id ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            PaySheetHeader(title: "转账") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isGroup {
                        PayMemberPicker(members: members, picked: $toUid, loading: loadingMembers)
                        Spacer().frame(height: 12)
                    }

                    HStack(spacing: 8) {
                        Text("¥")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Color(hex: 0x2F6BFF))
                        PayInputField(placeholder: "0", text: $amount, limit: 6,
                                      fontSize: 26, weight: .bold, height: 54)
                    }

                    Spacer().frame(height: 8)
                    Text(payBalanceText(balance))
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.muted)

                    Spacer().frame(height: 14)
                    PayInputField(placeholder: "支付密码", text: $password, limit: 8,
                                  fontSize: 14, weight: .regular, height: 44, secure: true)

                    if let errorText, !errorText.isEmpty {
                        Spacer().frame(height: 10)
                        PayErrorLine(text: errorText)
                    }

                    Spacer().frame(height: 18)
                    PayGradientButton(title: "确认转账",
                                      colors: [Color(hex: 0x4D8BFF), Color(hex: 0x2F6BFF)],
                                      busy: busy) {
                        Task { await send() }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 26)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(AKColor.card)
        .presentationDragIndicator(.visible)
        .task {
            await loadBalance()
            if isGroup { await loadMembers() }
        }
    }

    private func loadBalance() async {
        if let wallet = try? await APIClient.shared.walletInfo() {
            balance = wallet.coin
        }
    }

    private func loadMembers() async {
        loadingMembers = true
        defer { loadingMembers = false }
        if let info = try? await APIClient.shared.groupInfo(id: convId) {
            members = info.members.filter { $0.uid != myId }
        }
    }

    private func send() async {
        guard !busy else { return }
        if isGroup && toUid <= 0 {
            errorText = "请选择收款人"
            return
        }
        let coin = Int64(amount) ?? 0
        guard coin > 0 else {
            errorText = "请输入转账金额"
            return
        }
        if let balance, coin > balance {
            errorText = "K币不足，请先充值"
            return
        }
        busy = true
        defer { busy = false }
        do {
            try await APIClient.shared.sendTransfer(
                convType: convType,
                convId: convId,
                toUid: isGroup ? toUid : convId,
                coin: Int(coin),
                remark: "",
                password: password
            )
            refreshMe()
            onDone()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func refreshMe() {
        Task {
            if let me = try? await APIClient.shared.me() {
                app.user = me
                SessionStore.shared.user = me
            }
        }
    }
}

/* ================= 送礼物 ================= */

/// 送礼物：分类 + 礼物网格 + 数量 + 支付密码（对齐安卓 GiftDialog）
struct GiftSheet: View {
    let convType: String
    let convId: Int64
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppState
    @State private var gifts: [GiftItem] = []
    @State private var categories: [GiftCategory] = []
    @State private var catIndex = 0
    @State private var picked: GiftItem?
    @State private var count = 1
    @State private var password = ""
    @State private var toUid: Int64 = 0
    @State private var members: [GroupMember] = []
    @State private var loadingMembers = false
    @State private var balance: Int64?
    @State private var busy = false
    @State private var errorText: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    private var isGroup: Bool { convType == "group" }
    private var myId: Int64 { app.user?.id ?? 0 }
    private var list: [GiftItem] {
        categories.indices.contains(catIndex) ? categories[catIndex].gifts : gifts
    }
    private var total: Int {
        (picked?.coin ?? 0) * count
    }
    private var balanceText: String {
        let text = balance.map { String($0) } ?? "--"
        return "余额 \(text) K币"
    }

    var body: some View {
        VStack(spacing: 0) {
            PaySheetHeader(title: "送礼物") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isGroup {
                        PayMemberPicker(members: members, picked: $toUid, loading: loadingMembers)
                        Spacer().frame(height: 10)
                    }

                    if !categories.isEmpty {
                        categoryChips
                        Spacer().frame(height: 10)
                    }

                    if list.isEmpty {
                        HStack {
                            Spacer()
                            Text("该分类暂无礼物")
                                .font(.system(size: 12.5))
                                .foregroundColor(AKColor.muted)
                            Spacer()
                        }
                        .frame(height: 150)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(list, id: \.stableKey) { g in
                                    giftCell(g)
                                }
                            }
                            .padding(.vertical, 1)
                        }
                        .frame(height: min(CGFloat((list.count + 3) / 4) * 86, 250))
                        .scrollIndicators(.hidden)
                    }

                    Spacer().frame(height: 10)
                    HStack(spacing: 6) {
                        Text(balanceText)
                            .font(.system(size: 11.5))
                            .foregroundColor(AKColor.muted)
                        Spacer(minLength: 6)
                        Text("数量")
                            .font(.system(size: 11.5))
                            .foregroundColor(AKColor.muted)
                        Button {
                            if count > 1 { count -= 1 }
                        } label: {
                            Text("−")
                                .font(.system(size: 15))
                                .foregroundColor(AKColor.text)
                                .frame(width: 28, height: 28)
                                .background(AKColor.fill)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        Text("\(count)")
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.text)
                            .frame(minWidth: 20)
                        Button {
                            let max = picked?.type == "pretty" ? 1 : 99
                            if count < max { count += 1 }
                        } label: {
                            Text("+")
                                .font(.system(size: 15))
                                .foregroundColor(AKColor.text)
                                .frame(width: 28, height: 28)
                                .background(AKColor.fill)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer().frame(height: 8)
                    PayInputField(placeholder: "支付密码", text: $password, limit: 8,
                                  fontSize: 14, weight: .regular, height: 44, secure: true)

                    if let errorText, !errorText.isEmpty {
                        Spacer().frame(height: 10)
                        PayErrorLine(text: errorText)
                    }

                    Spacer().frame(height: 14)
                    PayGradientButton(title: total > 0 ? "赠送 · \(total) K币" : "赠送",
                                      colors: [AKColor.gold, Color(hex: 0xE0900F)],
                                      busy: busy) {
                        Task { await send() }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(AKColor.card)
        .presentationDragIndicator(.visible)
        .task {
            await loadGifts()
            await loadBalance()
            if isGroup { await loadMembers() }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(categories.indices, id: \.self) { index in
                    let on = index == catIndex
                    Button {
                        catIndex = index
                        picked = nil
                        count = 1
                    } label: {
                        Text(categories[index].name.isEmpty ? "分类" : categories[index].name)
                            .font(.system(size: 12.5, weight: on ? .medium : .regular))
                            .foregroundColor(on ? .white : AKColor.sub)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background(on ? AKColor.brand : AKColor.fill)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func giftCell(_ g: GiftItem) -> some View {
        let on = picked?.type == g.type && picked?.id == g.id
        let isPretty = g.type == "pretty"
        return Button {
            picked = g
            if g.type != "vip" { count = 1 }
        } label: {
            VStack(spacing: 5) {
                Text(isPretty ? "靓" : "👑")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isPretty ? AKColor.red : AKColor.gold)
                    .frame(width: 34, height: 34)
                    .background(isPretty ? AKColor.redSoft : AKColor.goldSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(g.name)
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.text)
                    .lineLimit(1)
                Text("\(g.coin) K币")
                    .font(.system(size: 10.5))
                    .foregroundColor(AKColor.gold)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(on ? AKColor.goldSoft : AKColor.fill)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func loadGifts() async {
        if let data = try? await APIClient.shared.gifts() {
            gifts = data.list
            categories = data.categories
        }
        if categories.isEmpty {
            categories = [GiftCategory(id: 0, name: "全部礼物", gifts: gifts)]
        }
        if !categories.indices.contains(catIndex) { catIndex = 0 }
    }

    private func loadBalance() async {
        if let wallet = try? await APIClient.shared.walletInfo() {
            balance = wallet.coin
        }
    }

    private func loadMembers() async {
        loadingMembers = true
        defer { loadingMembers = false }
        if let info = try? await APIClient.shared.groupInfo(id: convId) {
            members = info.members.filter { $0.uid != myId }
        }
    }

    private func send() async {
        guard !busy else { return }
        guard let gift = picked else {
            errorText = "请选择礼物"
            return
        }
        if isGroup && toUid <= 0 {
            errorText = "请选择收礼人"
            return
        }
        if let balance, total > Int(balance) {
            errorText = "K币不足，请先充值"
            return
        }
        busy = true
        defer { busy = false }
        do {
            try await APIClient.shared.sendGift(
                convType: convType,
                convId: convId,
                toUid: isGroup ? toUid : convId,
                giftType: gift.type,
                giftId: gift.id,
                count: count,
                password: password
            )
            refreshMe()
            onDone()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func refreshMe() {
        Task {
            if let me = try? await APIClient.shared.me() {
                app.user = me
                SessionStore.shared.user = me
            }
        }
    }
}

/* ---------------- 领取类卡片：红包详情 / 转账收款 / 礼物领取 ---------------- */

struct RedPacketInfo: Decodable {
    let id: Int64
    let fromUid: Int64
    let fromName: String
    let totalCoin: Int
    let count: Int
    let grabbedCount: Int
    let leftCount: Int
    let rpType: Int
    let blessing: String
    let grabbed: Int
    let mine: Int
    let isSelf: Int
    let finished: Int
    let logs: [RedPacketLog]

    enum CodingKeys: String, CodingKey {
        case id, count, blessing, grabbed, mine, logs, finished
        case fromUid = "from_uid"
        case fromName = "from_name"
        case totalCoin = "total_coin"
        case grabbedCount = "grabbed_count"
        case leftCount = "left_count"
        case rpType = "rp_type"
        case isSelf = "is_self"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        fromUid = (try? c.decode(Int64.self, forKey: .fromUid)) ?? 0
        fromName = (try? c.decode(String.self, forKey: .fromName)) ?? ""
        totalCoin = (try? c.decode(Int.self, forKey: .totalCoin)) ?? 0
        count = (try? c.decode(Int.self, forKey: .count)) ?? 0
        grabbedCount = (try? c.decode(Int.self, forKey: .grabbedCount)) ?? 0
        leftCount = (try? c.decode(Int.self, forKey: .leftCount)) ?? 0
        rpType = (try? c.decode(Int.self, forKey: .rpType)) ?? 1
        blessing = (try? c.decode(String.self, forKey: .blessing)) ?? ""
        grabbed = (try? c.decode(Int.self, forKey: .grabbed)) ?? 0
        mine = (try? c.decode(Int.self, forKey: .mine)) ?? 0
        isSelf = (try? c.decode(Int.self, forKey: .isSelf)) ?? 0
        finished = (try? c.decode(Int.self, forKey: .finished)) ?? 0
        logs = (try? c.decode([RedPacketLog].self, forKey: .logs)) ?? []
    }
}

struct RedPacketLog: Decodable, Identifiable {
    let uid: Int64
    let name: String
    let avatar: String
    let coin: Int
    let createdAt: Int64
    let isBest: Int

    var id: Int64 { uid }

    enum CodingKeys: String, CodingKey {
        case uid, name, avatar, coin
        case createdAt = "created_at"
        case isBest = "is_best"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uid = (try? c.decode(Int64.self, forKey: .uid)) ?? 0
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        avatar = (try? c.decode(String.self, forKey: .avatar)) ?? ""
        coin = (try? c.decode(Int.self, forKey: .coin)) ?? 0
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
        isBest = (try? c.decode(Int.self, forKey: .isBest)) ?? 0
    }
}

extension APIClient {
    func redPacketInfo(id: Int64, convType: String, convId: Int64) async throws -> RedPacketInfo {
        try await get("api/v1/redpacket/info", query: [
            "id": String(id),
            "conv_type": convType,
            "conv_id": String(convId)
        ])
    }

    func grabRedPacket(id: Int64, convType: String, convId: Int64) async throws -> Int {
        struct GrabResp: Decodable { let coin: Int }
        let r: GrabResp = try await post("api/v1/redpacket/grab", body: [
            "id": id, "conv_type": convType, "conv_id": convId
        ])
        return r.coin
    }

    func receiveTransfer(id: Int64) async throws {
        _ = try await postRaw("api/v1/transfer/receive", body: ["id": id])
    }

    func claimGift(id: Int64) async throws {
        _ = try await postRaw("api/v1/gift/claim", body: ["id": id])
    }
}

/// 从卡片消息里取字段：extra 优先，缺字段回落到 content/text 的 JSON
private func payCardStr(_ m: Message, _ key: String) -> String {
    if let v = m.extraMap[key]?.stringValue, !v.isEmpty, v != "null" { return v }
    if let o = MessageBody.jsonObject(m.content) ?? MessageBody.jsonObject(m.text) {
        if let s = o[key] as? String, !s.isEmpty { return s }
        if let n = o[key] as? NSNumber { return n.stringValue }
    }
    return ""
}

private func payCardInt(_ m: Message, _ key: String) -> Int {
    if let v = m.extraMap[key]?.intValue { return v }
    if let o = MessageBody.jsonObject(m.content) ?? MessageBody.jsonObject(m.text) {
        if let n = o[key] as? NSNumber { return n.intValue }
        if let s = o[key] as? String { return Int(s) ?? 0 }
    }
    return 0
}

private func payDetailTime(_ ts: Int64) -> String {
    guard ts > 0 else { return "" }
    let f = DateFormatter()
    f.locale = Locale(identifier: "zh_CN")
    f.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)!
    f.dateFormat = "yyyy年M月d日 HH:mm"
    return f.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
}

/// 红包详情：总额/祝福语/领取记录 + 开红包（对齐安卓 RpDetailDialog）
struct RedPacketDetailSheet: View {
    let infoId: Int64
    let convType: String
    let convId: Int64
    let myId: Int64
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var info: RedPacketInfo?
    @State private var showAll = false
    @State private var busy = false
    @State private var errorText: String?

    private var isSelf: Bool {
        guard let info else { return false }
        return info.isSelf == 1 || (myId > 0 && info.fromUid == myId)
    }

    private var canGrab: Bool {
        guard let info else { return false }
        return info.grabbed == 0 && info.leftCount > 0 && !isSelf
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let info {
                    header(info)
                    logsCard(info)
                } else if let errorText {
                    Text(errorText)
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.red)
                        .padding(.top, 40)
                } else {
                    ProgressView().padding(.top, 40)
                }
            }
            .padding(16)
        }
        .background(AKColor.bg)
        .navigationTitle("红包")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let info { actionBar(info) }
        }
        .task { await load() }
    }

    private func header(_ info: RedPacketInfo) -> some View {
        let finished = info.finished == 1
        let big = info.mine > 0 ? info.mine : info.totalCoin
        let title: String = {
            if isSelf { return "我发的红包" }
            let name = info.fromName.isEmpty ? "好友" : info.fromName
            return "\(name)的红包"
        }()
        let subline: String = {
            if info.mine > 0 { return "你抢到 \(info.mine) K币" }
            if isSelf { return "共 \(info.count) 个 · 已领 \(info.grabbedCount) 个" }
            if finished { return "红包已领完" }
            return "共 \(info.count) 个 · 剩 \(info.leftCount) 个"
        }()
        return VStack(spacing: 0) {
            Text("🧧")
                .font(.system(size: 26))
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.top, 10)
            Text(info.blessing.isEmpty ? "恭喜发财，大吉大利" : info.blessing)
                .font(.system(size: 12.5))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
            HStack(alignment: .bottom, spacing: 4) {
                if info.mine > 0 {
                    Text("¥")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(.bottom, 6)
                }
                Text("\(big)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                Text("K币")
                    .font(.system(size: 11.5))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.bottom, 8)
            }
            .padding(.top, 14)
            Text(subline)
                .font(.system(size: 11.5))
                .foregroundColor(Color(hex: 0xFFE9C7))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .background(
            LinearGradient(colors: finished
                           ? [Color(hex: 0xF0907F), Color(hex: 0xD67F6B)]
                           : [AKColor.red, AKColor.red],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func logsCard(_ info: RedPacketInfo) -> some View {
        let shown = showAll ? info.logs : Array(info.logs.prefix(5))
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("领取记录")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AKColor.text)
                Spacer(minLength: 8)
                Text("\(info.grabbedCount)/\(info.count)")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.muted)
            }
            .padding(.bottom, 6)

            if info.logs.isEmpty {
                HStack {
                    Spacer()
                    Text("还没有人领取")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.placeholder)
                    Spacer()
                }
                .frame(height: 56)
            } else {
                ForEach(shown) { log in
                    logRow(log)
                }
                if info.logs.count > 5 {
                    Button {
                        showAll.toggle()
                    } label: {
                        Text(showAll ? "收起" : "查看全部 \(info.logs.count) 条")
                            .font(.system(size: 12))
                            .foregroundColor(AKColor.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let errorText, !errorText.isEmpty {
                Text(errorText)
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.red)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func logRow(_ log: RedPacketLog) -> some View {
        let mine = myId > 0 && log.uid == myId
        let name = log.name.isEmpty ? "成员" : log.name
        return HStack(spacing: 8) {
            AvatarView(url: log.avatar, name: name, size: 26)
                .clipShape(Circle())
            Text(mine ? "\(name)（你）" : name)
                .font(.system(size: 12.5, weight: mine ? .medium : .regular))
                .foregroundColor(mine ? AKColor.gold : AKColor.sub)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text("\(log.coin) K币")
                .font(.system(size: 12.5, weight: mine ? .bold : .regular))
                .foregroundColor(mine ? AKColor.red : AKColor.muted)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(mine ? AKColor.goldSoft : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func actionBar(_ info: RedPacketInfo) -> some View {
        Button {
            if canGrab {
                Task { await grab() }
            } else {
                dismiss()
            }
        } label: {
            Text(canGrab ? (busy ? "拆开中…" : "拆开红包") : "关闭")
                .font(.system(size: 15.5, weight: .medium))
                .foregroundColor(canGrab ? .white : AKColor.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    LinearGradient(colors: canGrab ? [AKColor.red, AKColor.red] : [AKColor.line, AKColor.line],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(AKColor.bg)
    }

    private func load() async {
        do {
            info = try await APIClient.shared.redPacketInfo(id: infoId, convType: convType, convId: convId)
        } catch {
            errorText = "红包加载失败：\(error.localizedDescription)"
        }
    }

    private func grab() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            _ = try await APIClient.shared.grabRedPacket(id: infoId, convType: convType, convId: convId)
            await load()
            onDone()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

/// 转账 / 礼物详情卡（对齐安卓 PayDetailScreen）
private struct PayDetailCard: View {
    let message: Message
    let isGift: Bool
    let myId: Int64
    let myName: String
    let myAvatar: String?
    let busy: Bool
    let claimed: Bool
    let tip: String?
    let onClaim: () -> Void

    private var mine: Bool { myId > 0 && message.fromUid == myId }
    private var amount: Int {
        let v = payCardInt(message, "amount")
        return v > 0 ? v : payCardInt(message, "coin")
    }
    private var price: Int { payCardInt(message, "price") }
    private var remark: String {
        let msg = payCardStr(message, "msg")
        return msg.isEmpty ? payCardStr(message, "remark") : msg
    }
    private var giftName: String {
        let v = payCardStr(message, "gift_name")
        if !v.isEmpty { return v }
        let n = payCardStr(message, "name")
        return n.isEmpty ? "礼物" : n
    }
    private var giftDesc: String {
        let v = payCardStr(message, "gift_desc")
        return v.isEmpty ? giftName : v
    }
    private var giftType: String { payCardStr(message, "gift_type") }
    private var giftLevel: Int { max(payCardInt(message, "level"), 1) }
    private var toUid: Int64 {
        let v = payCardInt(message, "to_uid")
        return v > 0 ? Int64(v) : message.toUid
    }
    private var toName: String { payCardStr(message, "to_name") }
    private var senderName: String {
        if mine { return myName.isEmpty ? "我" : myName }
        if let name = message.fromName, !name.isEmpty { return name }
        return "对方"
    }
    private var receiverName: String {
        if !toName.isEmpty { return toName }
        return mine ? "对方" : (myName.isEmpty ? "我" : myName)
    }
    private var isOutsider: Bool { toUid > 0 && toUid != myId && !mine }
    private var done: Bool { claimed || payCardInt(message, "status") != 0 }
    private var canClaim: Bool { !mine && !done && !busy && message.id > 0 && !isOutsider }

    private var statusText: String {
        if done { return isGift ? "已领取" : "已收款" }
        if mine { return isGift ? "等待对方领取" : "等待对方收款" }
        if isOutsider { return "仅指定成员可领取" }
        return isGift ? "待领取" : "待收款"
    }

    private var buttonText: String {
        if busy { return "处理中…" }
        if done { return isGift ? "已领取" : "已收款" }
        if mine { return isGift ? "等待对方领取" : "等待对方收款" }
        if isOutsider { return "仅指定成员可领取" }
        return "确认收下"
    }

    private var giftEmoji: String {
        if giftType == "vip" { return giftLevel >= 2 ? "👑" : "💎" }
        return "🎁"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                card
                Spacer().frame(height: 20)
                claimButton
                if let tip, !tip.isEmpty {
                    Text(tip)
                        .font(.system(size: 12))
                        .foregroundColor(done ? Color(hex: 0x0FB67A) : Color(hex: 0xE24A3C))
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                }
                Spacer().frame(height: 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(AKColor.bg)
    }

    private var card: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                AvatarView(url: mine ? myAvatar : message.fromAvatar, name: senderName, size: 40)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(senderName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AKColor.text)
                        .lineLimit(1)
                    Text(isGift ? "送出一份礼物" : "发起转账")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.hint)
                }
                Spacer(minLength: 8)
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(colors: isGift
                                           ? [AKColor.gold, Color(hex: 0xF09A17)]
                                           : [Color(hex: 0x6D7CFF), Color(hex: 0xB06BFF)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 28, height: 28)
                    Image(systemName: isGift ? "gift.fill" : "arrow.left.arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
            }

            Spacer().frame(height: 22)

            if isGift {
                Text(giftEmoji)
                    .font(.system(size: 30))
                    .frame(width: 64, height: 64)
                    .background(
                        LinearGradient(colors: [AKColor.goldSoft, Color(hex: 0xFFE2B0)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                Text(giftName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AKColor.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                Text(giftDesc)
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.hint)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                if price > 0 {
                    Text("价值 \(price) K币")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(AKColor.gold)
                        .padding(.top, 6)
                }
            } else {
                HStack(alignment: .bottom, spacing: 4) {
                    Text("¥")
                        .font(.system(size: 20))
                        .foregroundColor(AKColor.text)
                        .padding(.bottom, 7)
                    Text("\(amount)")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(AKColor.text)
                    Text("K币")
                        .font(.system(size: 12.5))
                        .foregroundColor(AKColor.hint)
                        .padding(.bottom, 9)
                }
            }

            if !remark.isEmpty {
                Text(remark)
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.sub)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AKColor.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top, 14)
            }

            Rectangle()
                .fill(AKColor.line)
                .frame(height: 0.6)
                .padding(.top, 18)
            Spacer().frame(height: 14)

            detailLine("接收人", receiverName)
            Spacer().frame(height: 10)
            detailLine("发起时间", payDetailTime(message.createdAt))
            Spacer().frame(height: 10)
            detailLine("状态", statusText, color: done ? Color(hex: 0x0FB67A) : AKColor.red)

            Spacer().frame(height: 12)
            HStack(spacing: 6) {
                AvatarView(url: mine ? nil : myAvatar, name: receiverName, size: 24)
                    .clipShape(Circle())
                Text("由 \(senderName) 发送给 \(receiverName)")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.muted)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    private func detailLine(_ label: String, _ value: String, color: Color = AKColor.text) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12.5))
                .foregroundColor(AKColor.muted)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(color)
                .lineLimit(1)
        }
    }

    private var claimButton: some View {
        Button {
            if canClaim { onClaim() }
        } label: {
            Text(buttonText)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(canClaim ? .white : Color(hex: 0x9AA6B5))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(colors: canClaim
                                   ? (isGift
                                      ? [AKColor.gold, Color(hex: 0xF09A17)]
                                      : [Color(hex: 0x6D7CFF), Color(hex: 0x9B5CF6)])
                                   : [AKColor.line, AKColor.line],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canClaim)
    }
}

/// 转账收款
struct TransferClaimSheet: View {
    let message: Message
    let convType: String
    let convId: Int64
    let myId: Int64
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppState
    @State private var busy = false
    @State private var done = false
    @State private var errorText: String?
    @State private var okText: String?

    private var tid: Int64 {
        let v = payCardInt(message, "tid")
        return v > 0 ? Int64(v) : message.id
    }

    var body: some View {
        PayDetailCard(
            message: message,
            isGift: false,
            myId: myId,
            myName: app.user?.displayName ?? "我",
            myAvatar: app.user?.avatar,
            busy: busy,
            claimed: done,
            tip: errorText ?? okText
        ) {
            Task { await receive() }
        }
        .navigationTitle("转账详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
        }
    }

    private func receive() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await APIClient.shared.receiveTransfer(id: tid)
            done = true
            okText = "收款成功，K币已到账"
            refreshMe()
            onDone()
            try? await Task.sleep(nanoseconds: 900_000_000)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func refreshMe() {
        Task {
            if let me = try? await APIClient.shared.me() {
                app.user = me
                SessionStore.shared.user = me
            }
        }
    }
}

/// 礼物领取
struct GiftClaimSheet: View {
    let message: Message
    let convType: String
    let convId: Int64
    let myId: Int64
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppState
    @State private var busy = false
    @State private var done = false
    @State private var errorText: String?
    @State private var okText: String?

    private var giftLogId: Int64 {
        let v = payCardInt(message, "gift_log_id")
        return v > 0 ? Int64(v) : message.id
    }

    var body: some View {
        PayDetailCard(
            message: message,
            isGift: true,
            myId: myId,
            myName: app.user?.displayName ?? "我",
            myAvatar: app.user?.avatar,
            busy: busy,
            claimed: done,
            tip: errorText ?? okText
        ) {
            Task { await claim() }
        }
        .navigationTitle("礼物详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
        }
    }

    private func claim() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await APIClient.shared.claimGift(id: giftLogId)
            done = true
            okText = "领取成功，礼物已到账"
            refreshMe()
            onDone()
            try? await Task.sleep(nanoseconds: 900_000_000)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func refreshMe() {
        Task {
            if let me = try? await APIClient.shared.me() {
                app.user = me
                SessionStore.shared.user = me
            }
        }
    }
}
