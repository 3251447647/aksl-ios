import Foundation

struct UserProfile: Decodable, Identifiable, Equatable {
    let id: Int64
    let nickname: String
    let yxId: String
    let prettyYxid: String
    let showYxid: String
    let isPretty: Int
    let avatar: String?
    let vipLevel: Int
    let vipExpireText: String
    let online: Int
    let bio: String
    let isFriend: Int
    let remark: String
    let isTop: Int
    let isMute: Int
    let isSelf: Int
    let isBlocked: Int
    let isBot: Int
    let moments: [ProfileMoment]

    enum CodingKeys: String, CodingKey {
        case id, nickname, avatar, online, bio, remark, moments
        case yxId = "yx_id"
        case prettyYxid = "pretty_yxid"
        case showYxid = "show_yxid"
        case isPretty = "is_pretty"
        case vipLevel = "vip_level"
        case vipExpireText = "vip_expire_text"
        case isFriend = "is_friend"
        case isTop = "is_top"
        case isMute = "is_mute"
        case isSelf = "is_self"
        case isBlocked = "is_blocked"
        case isBot = "is_bot"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        nickname = (try? c.decode(String.self, forKey: .nickname)) ?? "用户"
        yxId = (try? c.decode(String.self, forKey: .yxId)) ?? ""
        prettyYxid = (try? c.decode(String.self, forKey: .prettyYxid)) ?? ""
        showYxid = (try? c.decode(String.self, forKey: .showYxid)) ?? ""
        isPretty = (try? c.decode(Int.self, forKey: .isPretty)) ?? 0
        avatar = try? c.decode(String.self, forKey: .avatar)
        vipLevel = (try? c.decode(Int.self, forKey: .vipLevel)) ?? 0
        vipExpireText = (try? c.decode(String.self, forKey: .vipExpireText)) ?? ""
        online = (try? c.decode(Int.self, forKey: .online)) ?? 0
        bio = (try? c.decode(String.self, forKey: .bio)) ?? ""
        isFriend = (try? c.decode(Int.self, forKey: .isFriend)) ?? 0
        remark = (try? c.decode(String.self, forKey: .remark)) ?? ""
        isTop = (try? c.decode(Int.self, forKey: .isTop)) ?? 0
        isMute = (try? c.decode(Int.self, forKey: .isMute)) ?? 0
        isSelf = (try? c.decode(Int.self, forKey: .isSelf)) ?? 0
        isBlocked = (try? c.decode(Int.self, forKey: .isBlocked)) ?? 0
        isBot = (try? c.decode(Int.self, forKey: .isBot)) ?? 0
        moments = (try? c.decode([ProfileMoment].self, forKey: .moments)) ?? []
    }

    var displayName: String { remark.isEmpty ? nickname : remark }
}

extension APIClient {
    func userProfile(id: Int64) async throws -> UserProfile {
        try await get("api/v1/user", query: ["id": "\(id)"])
    }

    func setRemark(userId: Int64, remark: String) async {
        await postIgnore("api/v1/friend/remark", body: ["user_id": userId, "remark": remark])
    }

    func deleteFriend(userId: Int64) async {
        await postIgnore("api/v1/friend/delete", body: ["user_id": userId])
    }
}

/// 资料页里的 TA 的动态（服务端 /user/profile 的 moments 字段）
struct ProfileMoment: Decodable, Identifiable {
    let id: Int64
    let img: String
    let text: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        img = (try? c.decode(String.self, forKey: .img)) ?? ""
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
    }

    enum CodingKeys: String, CodingKey { case id, img, text }
}
