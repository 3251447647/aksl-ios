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
