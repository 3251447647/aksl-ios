import Foundation

/// USDT 充值（对齐安卓 UsdtScreen）
struct UsdtConfig: Decodable {
    let enabled: Int
    let rate: Double
    let address: String
    let min: Int

    enum CodingKeys: String, CodingKey { case enabled, rate, address, min }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = (try? c.decode(Int.self, forKey: .enabled)) ?? 0
        rate = (try? c.decode(Double.self, forKey: .rate)) ?? 0
        address = (try? c.decode(String.self, forKey: .address)) ?? ""
        min = (try? c.decode(Int.self, forKey: .min)) ?? 10
    }
}

struct UsdtCreateResult: Decodable {
    let id: Int64
    let amountUsdt: String
    let coin: Int64
    let address: String
    let rate: Double

    enum CodingKeys: String, CodingKey {
        case id, coin, address, rate
        case amountUsdt = "amount_usdt"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        amountUsdt = (try? c.decode(String.self, forKey: .amountUsdt)) ?? ""
        coin = (try? c.decode(Int64.self, forKey: .coin)) ?? 0
        address = (try? c.decode(String.self, forKey: .address)) ?? ""
        rate = (try? c.decode(Double.self, forKey: .rate)) ?? 0
    }
}

struct UsdtOrder: Decodable, Identifiable {
    let id: Int64
    let amountUsdt: String
    let coin: Int64
    let status: Int
    let remark: String
    let createdAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, coin, status, remark
        case amountUsdt = "amount_usdt"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        amountUsdt = (try? c.decode(String.self, forKey: .amountUsdt)) ?? ""
        coin = (try? c.decode(Int64.self, forKey: .coin)) ?? 0
        status = (try? c.decode(Int.self, forKey: .status)) ?? 0
        remark = (try? c.decode(String.self, forKey: .remark)) ?? ""
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
    }

    var statusText: String {
        switch status {
        case 0: return "待支付"
        case 1: return "已完成"
        case 2: return "已取消"
        default: return "处理中"
        }
    }
}

struct UsdtOrdersData: Decodable {
    let list: [UsdtOrder]

    enum CodingKeys: String, CodingKey { case list }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decode([UsdtOrder].self, forKey: .list)) ?? []
    }
}

extension APIClient {
    func usdtConfig() async throws -> UsdtConfig {
        try await get("api/v1/usdt/config")
    }

    func usdtCreate(coin: Int64) async throws -> UsdtCreateResult {
        try await post("api/v1/usdt/create", body: ["coin": coin])
    }

    func usdtOrders() async throws -> UsdtOrdersData {
        try await get("api/v1/usdt/orders")
    }
}
