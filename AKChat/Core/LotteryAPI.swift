import Foundation

/// 抽奖奖池里的一个奖品（GET /api/v1/lottery）
struct LotteryPrize: Decodable, Identifiable, Equatable {
    let id: Int64
    let name: String
    let type: String
    let value: Int
    let iconTxt: String
    let prettyNumber: String?

    enum CodingKeys: String, CodingKey {
        case id, name, type, value
        case iconTxt = "icon_txt"
        case prettyNumber = "pretty_number"
    }

    init(id: Int64, name: String, type: String, value: Int = 0,
         iconTxt: String = "", prettyNumber: String? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.value = value
        self.iconTxt = iconTxt
        self.prettyNumber = prettyNumber
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        type = (try? c.decode(String.self, forKey: .type)) ?? ""
        value = (try? c.decode(Int.self, forKey: .value)) ?? 0
        iconTxt = (try? c.decode(String.self, forKey: .iconTxt)) ?? ""
        prettyNumber = try? c.decode(String.self, forKey: .prettyNumber)
    }

    /// 转盘数据未到 / 失败时的占位扇区，保证高度不塌陷
    static let placeholders: [LotteryPrize] = (0..<4).map {
        LotteryPrize(id: Int64(-($0 + 1)), name: "加载中", type: "loading")
    }
}

/// 实际发放结果：会员折算后的天数、靓号号码等都写在 note 里
struct LotteryGrant: Decodable, Equatable {
    let type: String
    let days: Int
    let note: String

    enum CodingKeys: String, CodingKey { case type, days, note }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = (try? c.decode(String.self, forKey: .type)) ?? ""
        days = (try? c.decode(Int.self, forKey: .days)) ?? 0
        note = (try? c.decode(String.self, forKey: .note)) ?? ""
    }
}

/// 中奖记录（服务端保留最近 10 条，含发放明细）
struct LotteryRecord: Decodable, Identifiable, Equatable {
    let id: Int64
    let prizeId: Int64
    let name: String
    let type: String
    let value: Int
    let mode: String
    let cost: Int
    let grant: LotteryGrant?
    let createdAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, name, type, value, mode, cost, grant
        case prizeId = "prize_id"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        prizeId = (try? c.decode(Int64.self, forKey: .prizeId)) ?? 0
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        type = (try? c.decode(String.self, forKey: .type)) ?? ""
        value = (try? c.decode(Int.self, forKey: .value)) ?? 0
        mode = (try? c.decode(String.self, forKey: .mode)) ?? ""
        cost = (try? c.decode(Int.self, forKey: .cost)) ?? 0
        grant = try? c.decode(LotteryGrant.self, forKey: .grant)
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
    }
}

struct LotteryInfo: Decodable {
    let freeTotal: Int
    var freeLeft: Int
    let cost: Int
    var balance: Int64
    let prizes: [LotteryPrize]
    var records: [LotteryRecord]

    enum CodingKeys: String, CodingKey {
        case cost, balance, prizes, records
        case freeTotal = "free_total"
        case freeLeft = "free_left"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        freeTotal = (try? c.decode(Int.self, forKey: .freeTotal)) ?? 0
        freeLeft = (try? c.decode(Int.self, forKey: .freeLeft)) ?? 0
        cost = (try? c.decode(Int.self, forKey: .cost)) ?? 0
        balance = (try? c.decode(Int64.self, forKey: .balance)) ?? 0
        prizes = (try? c.decode([LotteryPrize].self, forKey: .prizes)) ?? []
        records = (try? c.decode([LotteryRecord].self, forKey: .records)) ?? []
    }
}

/// POST /api/v1/lottery/draw：奖品、发放明细与抽奖后的余额/剩余次数
struct LotteryDrawResult: Decodable {
    let prize: LotteryPrize?
    let balance: Int64
    let freeLeft: Int
    let grant: LotteryGrant?

    enum CodingKeys: String, CodingKey {
        case prize, balance, grant
        case freeLeft = "free_left"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        prize = try? c.decode(LotteryPrize.self, forKey: .prize)
        balance = (try? c.decode(Int64.self, forKey: .balance)) ?? 0
        freeLeft = (try? c.decode(Int.self, forKey: .freeLeft)) ?? 0
        grant = try? c.decode(LotteryGrant.self, forKey: .grant)
    }
}

extension APIClient {
    func lotteryInfo() async throws -> LotteryInfo {
        try await get("api/v1/lottery")
    }

    func lotteryDraw(mode: String) async throws -> LotteryDrawResult {
        try await post("api/v1/lottery/draw", body: ["mode": mode])
    }
}
