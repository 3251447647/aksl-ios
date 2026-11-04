import Foundation

struct WalletInfo: Decodable {
    let coin: Int64
    let income: Int64
    let expense: Int64
    let pending: Int

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        coin = (try? c.decode(Int64.self, forKey: .coin)) ?? 0
        income = (try? c.decode(Int64.self, forKey: .income)) ?? 0
        expense = (try? c.decode(Int64.self, forKey: .expense)) ?? 0
        pending = (try? c.decode(Int.self, forKey: .pending)) ?? 0
    }

    enum CodingKeys: String, CodingKey { case coin, income, expense, pending }
}

struct WalletLog: Decodable, Identifiable, Equatable {
    let id: Int64
    let type: Int
    let amount: Int64
    let balance: Int64
    let remark: String?
    let createdAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, type, amount, balance, remark
        case createdAt = "created_at"
    }
}

struct WalletLogsData: Decodable {
    let list: [WalletLog]
}

struct VipPlan: Decodable, Identifiable, Equatable {
    let id: Int64
    let name: String?
    let level: Int
    let days: Int
    let price: Int

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        name = try? c.decode(String.self, forKey: .name)
        level = (try? c.decode(Int.self, forKey: .level)) ?? 1
        days = (try? c.decode(Int.self, forKey: .days)) ?? 0
        price = (try? c.decode(Int.self, forKey: .price)) ?? 0
    }

    enum CodingKeys: String, CodingKey { case id, name, level, days, price }
}

struct VipPlansData: Decodable {
    let list: [VipPlan]
    let vipLevel: Int
    let vipDays: Int

    enum CodingKeys: String, CodingKey {
        case list
        case vipLevel = "vip_level"
        case vipDays = "vip_days"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decode([VipPlan].self, forKey: .list)) ?? []
        vipLevel = (try? c.decode(Int.self, forKey: .vipLevel)) ?? 0
        vipDays = (try? c.decode(Int.self, forKey: .vipDays)) ?? 0
    }
}
