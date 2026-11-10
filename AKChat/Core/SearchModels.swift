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

    init(users: [SearchUser], groups: [SearchGroup]) {
        self.users = users
        self.groups = groups
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        users = (try? c.decode([SearchUser].self, forKey: .users)) ?? []
        groups = (try? c.decode([SearchGroup].self, forKey: .groups)) ?? []
    }

    /// 找人/找群只认 AK号 / 靓号 / 群号 / 群靓号的完全相等；服务端 /search 仍会命中昵称/邮箱/手机，这里统一剔除
    func exactNumberMatches(keyword: String) -> SearchResult {
        let kw = keyword.trimmingCharacters(in: .whitespaces)
        guard !kw.isEmpty else { return self }
        return SearchResult(
            users: users.filter { ($0.yxId ?? "") == kw || $0.prettyNo == kw },
            groups: groups.filter { $0.groupNo == kw || $0.prettyNo == kw }
        )
    }
}
