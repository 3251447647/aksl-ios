import Foundation

struct SearchUser: Decodable, Identifiable, Equatable {
    let id: Int64
    let nickname: String?
    let avatar: String?
    let yxId: String?
    let isFriend: Int
    let vipLevel: Int
    let isPretty: Int
    let prettyNo: String

    enum CodingKeys: String, CodingKey {
        case id, nickname, avatar
        case yxId = "yx_id"
        case isFriend = "is_friend"
        case vipLevel = "vip_level"
        case isPretty = "is_pretty"
        case prettyNo = "pretty_no"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        nickname = try? c.decode(String.self, forKey: .nickname)
        avatar = try? c.decode(String.self, forKey: .avatar)
        yxId = try? c.decode(String.self, forKey: .yxId)
        isFriend = (try? c.decode(Int.self, forKey: .isFriend)) ?? 0
        vipLevel = (try? c.decode(Int.self, forKey: .vipLevel)) ?? 0
        isPretty = (try? c.decode(Int.self, forKey: .isPretty)) ?? 0
        prettyNo = (try? c.decode(String.self, forKey: .prettyNo)) ?? ""
    }
}

struct SearchResult: Decodable {
    let users: [SearchUser]
    let groups: [SearchGroup]

    enum CodingKeys: String, CodingKey { case users, groups }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        users = (try? c.decode([SearchUser].self, forKey: .users)) ?? []
        groups = (try? c.decode([SearchGroup].self, forKey: .groups)) ?? []
    }
}
