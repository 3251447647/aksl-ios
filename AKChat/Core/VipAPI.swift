import Foundation

struct VipBuyResult: Decodable {
    let level: Int
    let levelName: String
    let days: Int
    let expire: Int64

    enum CodingKeys: String, CodingKey {
        case level, days, expire
        case levelName = "level_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        level = (try? c.decode(Int.self, forKey: .level)) ?? 0
        levelName = (try? c.decode(String.self, forKey: .levelName)) ?? ""
        days = (try? c.decode(Int.self, forKey: .days)) ?? 0
        expire = (try? c.decode(Int64.self, forKey: .expire)) ?? 0
    }
}

extension APIClient {
    /// K币 开通会员（与安卓 /vip/buy 同一接口）
    func buyVip(planId: Int64, payPassword: String) async throws -> VipBuyResult {
        try await post("api/v1/vip/buy", body: ["plan_id": planId, "pay_password": payPassword])
    }
}
