import Foundation

struct PrivacySettings: Decodable, Equatable {
    let allowFriendRequest: Int
    let allowGroupInvite: Int
    let autoAcceptFriend: Int
    let hasPayPassword: Int

    enum CodingKeys: String, CodingKey {
        case allowFriendRequest = "allow_friend_request"
        case allowGroupInvite = "allow_group_invite"
        case autoAcceptFriend = "auto_accept_friend"
        case hasPayPassword = "has_pay_password"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        allowFriendRequest = (try? c.decode(Int.self, forKey: .allowFriendRequest)) ?? 1
        allowGroupInvite = (try? c.decode(Int.self, forKey: .allowGroupInvite)) ?? 1
        autoAcceptFriend = (try? c.decode(Int.self, forKey: .autoAcceptFriend)) ?? 0
        hasPayPassword = (try? c.decode(Int.self, forKey: .hasPayPassword)) ?? 0
    }
}

extension APIClient {
    func privacy() async throws -> PrivacySettings {
        try await get("api/v1/privacy")
    }

    func setPrivacy(key: String, value: Bool) async throws {
        _ = try await postRaw("api/v1/privacy/set", body: ["key": key, "value": value ? 1 : 0])
    }

    /// type = login 修改登录密码 / pay 设置或修改支付密码
    func changePassword(type: String, old: String, new: String) async throws {
        _ = try await postRaw("api/v1/profile/password", body: ["type": type, "old": old, "new": new])
    }
}
