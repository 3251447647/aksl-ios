import SwiftUI

/// 礼物条目（GET /api/v1/gifts）
struct GiftItem: Decodable, Identifiable {
    let id: Int64
    let name: String
    let icon: String
    let price: Int
    let type: String

    enum CodingKeys: String, CodingKey {
        case id, name, icon, price, type
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? c.decode(String.self, forKey: .name)) ?? "礼物"
        icon = (try? c.decode(String.self, forKey: .icon)) ?? ""
        price = (try? c.decode(Int.self, forKey: .price)) ?? 0
        type = (try? c.decode(String.self, forKey: .type)) ?? "pretty"
    }
}

struct GiftListData: Decodable {
    let list: [GiftItem]
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decode([GiftItem].self, forKey: .list)) ?? []
    }
    enum CodingKeys: String, CodingKey { case list }
}

extension APIClient {
    func sendRedPacket(convType: String, convId: Int64, coin: Int, blessing: String, password: String) async throws {
        _ = try await postRaw("api/v1/redpacket/send", body: [
            "conv_type": convType, "conv_id": convId, "coin": coin, "count": 1,
            "rp_type": 1, "blessing": blessing, "pay_password": password
        ])
    }

    func sendTransfer(convType: String, convId: Int64, toUid: Int64, coin: Int, remark: String, password: String) async throws {
        _ = try await postRaw("api/v1/transfer/send", body: [
            "conv_type": convType, "conv_id": convId, "to_uid": toUid,
            "coin": coin, "remark": remark, "pay_password": password
        ])
    }

    func gifts() async throws -> GiftListData {
        try await get("api/v1/gifts")
    }

    func sendGift(convType: String, convId: Int64, toUid: Int64, giftId: Int64, count: Int, password: String) async throws {
        _ = try await postRaw("api/v1/gift/send", body: [
            "conv_type": convType, "conv_id": convId, "to_uid": toUid,
            "gift_type": "pretty", "gift_id": giftId, "count": count, "pay_password": password
        ])
    }
}

/// 发红包：金额 + 祝福语 + 支付密码
struct RedPacketSheet: View {
    let convType: String
    let convId: Int64
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var blessing = "恭喜发财，大吉大利"
    @State private var password = ""
    @State private var busy = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("金额") {
                    TextField("K币数量", text: $amount).keyboardType(.numberPad)
                }
                Section("祝福语") {
                    TextField("恭喜发财，大吉大利", text: $blessing)
                }
                Section("支付密码") {
                    SecureField("请输入支付密码", text: $password)
                }
                if let errorText {
                    Section { Text(errorText).foregroundColor(AKColor.red).font(.system(size: 13)) }
                }
            }
            .reportsDetailPage()
            .navigationTitle("发红包")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(busy ? "发送中…" : "发送") { Task { await send() } }
                        .disabled(busy || Int(amount) == nil || password.isEmpty)
                }
            }
        }
    }

    private func send() async {
        guard let coin = Int(amount), coin > 0 else { return }
        busy = true
        defer { busy = false }
        do {
            try await APIClient.shared.sendRedPacket(convType: convType, convId: convId,
                                                     coin: coin, blessing: blessing, password: password)
            onDone()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

/// 转账：金额 + 备注 + 支付密码
struct TransferSheet: View {
    let convType: String
    let convId: Int64
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var remark = ""
    @State private var password = ""
    @State private var busy = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("金额") {
                    TextField("K币数量", text: $amount).keyboardType(.numberPad)
                }
                Section("备注") {
                    TextField("选填", text: $remark)
                }
                Section("支付密码") {
                    SecureField("请输入支付密码", text: $password)
                }
                if let errorText {
                    Section { Text(errorText).foregroundColor(AKColor.red).font(.system(size: 13)) }
                }
            }
            .navigationTitle("转账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(busy ? "转账中…" : "确认转账") { Task { await send() } }
                        .disabled(busy || Int(amount) == nil || password.isEmpty)
                }
            }
        }
    }

    private func send() async {
        guard let coin = Int(amount), coin > 0 else { return }
        busy = true
        defer { busy = false }
        do {
            try await APIClient.shared.sendTransfer(convType: convType, convId: convId, toUid: convId,
                                                    coin: coin, remark: remark, password: password)
            onDone()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

/// 送礼物：列表选择 + 数量 + 支付密码
struct GiftSheet: View {
    let convType: String
    let convId: Int64
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var gifts: [GiftItem] = []
    @State private var selected: Int64 = 0
    @State private var count = 1
    @State private var password = ""
    @State private var busy = false
    @State private var errorText: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if gifts.isEmpty {
                        Text("暂无可送礼物").font(.system(size: 13)).foregroundColor(AKColor.hint)
                            .frame(maxWidth: .infinity).padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(gifts) { g in
                                Button {
                                    selected = g.id
                                } label: {
                                    VStack(spacing: 6) {
                                        AsyncImage(url: APIClient.fullURL(g.icon)) { phase in
                                            if let img = phase.image {
                                                img.resizable().scaledToFit()
                                            } else {
                                                Image(systemName: "gift.fill")
                                                    .font(.system(size: 22))
                                                    .foregroundColor(AKColor.gold)
                                            }
                                        }
                                        .frame(height: 44)
                                        Text(g.name).font(.system(size: 11.5)).foregroundColor(AKColor.text).lineLimit(1)
                                        Text("\(g.price) K币").font(.system(size: 10.5)).foregroundColor(AKColor.muted)
                                    }
                                    .padding(8)
                                    .frame(maxWidth: .infinity)
                                    .background(selected == g.id ? AKColor.brandSoft : AKColor.fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Text("数量").font(.system(size: 13)).foregroundColor(AKColor.sub)
                        TextField("1", value: $count, format: .number)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                    }

                    SecureField("请输入支付密码", text: $password)
                        .textFieldStyle(.roundedBorder)

                    if let errorText {
                        Text(errorText).font(.system(size: 12)).foregroundColor(AKColor.red)
                    }
                }
                .padding(14)
            }
            .navigationTitle("送礼物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(busy ? "赠送中…" : "赠送") { Task { await send() } }
                        .disabled(busy || selected == 0 || password.isEmpty)
                }
            }
            .task {
                if let d = try? await APIClient.shared.gifts() {
                    gifts = d.list
                    selected = d.list.first?.id ?? 0
                }
            }
        }
    }

    private func send() async {
        busy = true
        defer { busy = false }
        do {
            try await APIClient.shared.sendGift(convType: convType, convId: convId, toUid: convId,
                                                giftId: selected, count: count, password: password)
            onDone()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

/* ---------------- 领取类卡片：红包详情 / 转账收款 / 礼物领取 ---------------- */

struct RedPacketInfo: Decodable {
    let id: Int64
    let fromUid: Int64
    let totalCoin: Int
    let count: Int
    let leftCount: Int
    let blessing: String
    let grabbed: Int
    let mine: Int
    let logs: [RedPacketLog]

    enum CodingKeys: String, CodingKey {
        case id, count, blessing, grabbed, mine, logs
        case fromUid = "from_uid"
        case totalCoin = "total_coin"
        case leftCount = "left_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        fromUid = (try? c.decode(Int64.self, forKey: .fromUid)) ?? 0
        totalCoin = (try? c.decode(Int.self, forKey: .totalCoin)) ?? 0
        count = (try? c.decode(Int.self, forKey: .count)) ?? 0
        leftCount = (try? c.decode(Int.self, forKey: .leftCount)) ?? 0
        blessing = (try? c.decode(String.self, forKey: .blessing)) ?? ""
        grabbed = (try? c.decode(Int.self, forKey: .grabbed)) ?? 0
        mine = (try? c.decode(Int.self, forKey: .mine)) ?? 0
        logs = (try? c.decode([RedPacketLog].self, forKey: .logs)) ?? []
    }
}

struct RedPacketLog: Decodable, Identifiable {
    let uid: Int64
    let name: String
    let avatar: String
    let coin: Int
    let createdAt: Int64

    var id: Int64 { uid }

    enum CodingKeys: String, CodingKey {
        case uid, name, avatar, coin
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uid = (try? c.decode(Int64.self, forKey: .uid)) ?? 0
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        avatar = (try? c.decode(String.self, forKey: .avatar)) ?? ""
        coin = (try? c.decode(Int.self, forKey: .coin)) ?? 0
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
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

/// 红包详情：总额/祝福语/领取记录 + 开红包
struct RedPacketDetailSheet: View {
    let infoId: Int64
    let convType: String
    let convId: Int64
    let myId: Int64
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var info: RedPacketInfo?
    @State private var busy = false
    @State private var errorText: String?

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
        let mineGrabbed = info.mine
        let amount = mineGrabbed > 0 ? mineGrabbed : info.totalCoin
        let title = info.fromUid == myId ? "我发的红包" : "收到的红包"
        let subline = mineGrabbed > 0
            ? "你抢到 \(mineGrabbed) K币"
            : "共 \(info.count) 个 · 剩 \(info.leftCount) 个"
        return VStack(spacing: 6) {
            Text("🧧").font(.system(size: 34))
            Text(title).font(.system(size: 14, weight: .medium)).foregroundColor(.white)
            Text(info.blessing.isEmpty ? "恭喜发财，大吉大利" : info.blessing)
                .font(.system(size: 12.5))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
            Text("\(amount)")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
            Text("K币").font(.system(size: 11.5)).foregroundColor(.white.opacity(0.8))
            Text(subline).font(.system(size: 11.5)).foregroundColor(Color(hex: 0xFFE9C7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(LinearGradient(colors: [AKColor.red, AKColor.red],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func logsCard(_ info: RedPacketInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("领取记录").font(.system(size: 13, weight: .medium)).foregroundColor(AKColor.text)
                Spacer()
                Text("\(info.logs.count)/\(info.count)")
                    .font(.system(size: 11.5)).foregroundColor(AKColor.muted)
            }
            if info.logs.isEmpty {
                Text("还没有人领取")
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.placeholder)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
            } else {
                ForEach(info.logs) { log in
                    HStack(spacing: 8) {
                        AvatarView(url: log.avatar, name: log.name, size: 26)
                        Text(log.name.isEmpty ? "成员" : log.name)
                            .font(.system(size: 13))
                            .foregroundColor(log.uid == myId ? AKColor.gold : AKColor.text)
                            .lineLimit(1)
                        Spacer()
                        Text("\(log.coin) K币")
                            .font(.system(size: 12))
                            .foregroundColor(AKColor.sub)
                    }
                }
            }
            if let errorText {
                Text(errorText).font(.system(size: 12)).foregroundColor(AKColor.red)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func actionBar(_ info: RedPacketInfo) -> some View {
        let isSelf = info.fromUid == myId
        let canGrab = !isSelf && info.grabbed == 0 && info.leftCount > 0 && info.mine == 0
        Button {
            Task { await grab() }
        } label: {
            Text(canGrab ? (busy ? "领取中…" : "开") : (info.mine > 0 ? "已领取 \(info.mine) K币" : (info.leftCount <= 0 ? "红包已领完" : "已领取")))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(canGrab ? AKColor.red : AKColor.placeholder)
                .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        }
        .disabled(!canGrab || busy)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .padding(.top, 6)
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

/// 转账收款
struct TransferClaimSheet: View {
    let message: Message
    let convType: String
    let convId: Int64
    let myId: Int64
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    @State private var done = false
    @State private var errorText: String?

    private var tid: Int64 {
        let v = payCardInt(message, "tid")
        return v > 0 ? Int64(v) : message.id
    }
    private var coin: Int {
        payCardInt(message, "coin") > 0 ? payCardInt(message, "coin") : payCardInt(message, "amount")
    }
    private var remark: String { payCardStr(message, "remark") }
    private var toUid: Int64 {
        payCardInt(message, "to_uid") > 0 ? Int64(payCardInt(message, "to_uid")) : message.toUid
    }
    private var isRcv: Bool { myId > 0 && toUid == myId }
    private var finished: Bool { done || payCardInt(message, "status") != 0 }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text("转账")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.85))
                Text("\(coin) K币")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                if !remark.isEmpty {
                    Text(remark).font(.system(size: 12)).foregroundColor(.white.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(LinearGradient(colors: [Color(hex: 0x5B6BFF), Color(hex: 0x7C4DF5)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if let errorText {
                Text(errorText).font(.system(size: 12)).foregroundColor(AKColor.red)
            }

            Spacer(minLength: 0)

            if isRcv && !finished {
                Button {
                    Task { await receive() }
                } label: {
                    Text(busy ? "收款中…" : "确认收款")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(AKColor.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                }
                .disabled(busy)
            } else {
                Text(isRcv || !finished ? "等待对方领取" : "已被领取")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(AKColor.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
            }
        }
        .padding(16)
        .background(AKColor.bg)
        .navigationTitle("转账")
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
            onDone()
        } catch {
            errorText = error.localizedDescription
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
    @State private var busy = false
    @State private var done = false
    @State private var errorText: String?

    private var giftLogId: Int64 {
        let v = payCardInt(message, "gift_log_id")
        return v > 0 ? Int64(v) : message.id
    }
    private var name: String { payCardStr(message, "name") }
    private var coin: Int { payCardInt(message, "coin") }
    private var toUid: Int64 {
        payCardInt(message, "to_uid") > 0 ? Int64(payCardInt(message, "to_uid")) : message.toUid
    }
    private var isRcv: Bool { myId > 0 && toUid == myId }
    private var finished: Bool { done || payCardInt(message, "status") != 0 }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 8) {
                Text("🎁").font(.system(size: 40))
                Text(name.isEmpty ? "礼物" : name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                if coin > 0 {
                    Text("\(coin) K币").font(.system(size: 13)).foregroundColor(.white.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .background(LinearGradient(colors: [AKColor.gold, Color(hex: 0xF09A17)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if let errorText {
                Text(errorText).font(.system(size: 12)).foregroundColor(AKColor.red)
            }

            Spacer(minLength: 0)

            if isRcv && !finished {
                Button {
                    Task { await claim() }
                } label: {
                    Text(busy ? "领取中…" : "领取礼物")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(AKColor.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                }
                .disabled(busy)
            } else {
                Text(finished ? "已领取" : "等待对方领取")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(AKColor.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
            }
        }
        .padding(16)
        .background(AKColor.bg)
        .navigationTitle("礼物")
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
            onDone()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
