import Foundation

struct BlockedUser: Decodable, Identifiable, Equatable {
    let uid: Int64
    let nickname: String?
    let avatar: String?
    let yxId: String?

    var id: Int64 { uid }
}

struct BlacklistData: Decodable {
    let list: [BlockedUser]
}

struct GroupInvite: Decodable, Identifiable, Equatable {
    let id: Int64
    let groupId: Int64
    let groupName: String?
    let groupAvatar: String?
    let groupNo: String?
    let memberCount: Int
    let inviterName: String?
    let message: String?
    let status: Int

    enum CodingKeys: String, CodingKey {
        case id, message, status
        case groupId = "group_id"
        case groupName = "group_name"
        case groupAvatar = "group_avatar"
        case groupNo = "group_no"
        case memberCount = "member_count"
        case inviterName = "inviter_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        groupId = (try? c.decode(Int64.self, forKey: .groupId)) ?? 0
        groupName = try? c.decode(String.self, forKey: .groupName)
        groupAvatar = try? c.decode(String.self, forKey: .groupAvatar)
        groupNo = try? c.decode(String.self, forKey: .groupNo)
        memberCount = (try? c.decode(Int.self, forKey: .memberCount)) ?? 0
        inviterName = try? c.decode(String.self, forKey: .inviterName)
        message = try? c.decode(String.self, forKey: .message)
        status = (try? c.decode(Int.self, forKey: .status)) ?? 0
    }
}

struct GroupInvitesData: Decodable {
    let list: [GroupInvite]
    let pending: Int
}

struct InvitableFriend: Decodable, Identifiable, Equatable {
    let id: Int64
    let name: String?
    let nickname: String?
    let avatar: String?

    var displayName: String { (name?.isEmpty == false ? name! : (nickname ?? "好友")) }
}

struct InvitableData: Decodable {
    let list: [InvitableFriend]
    let canInvite: Int
    let allowInvite: Int

    enum CodingKeys: String, CodingKey {
        case list
        case canInvite = "can_invite"
        case allowInvite = "allow_invite"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decode([InvitableFriend].self, forKey: .list)) ?? []
        canInvite = (try? c.decode(Int.self, forKey: .canInvite)) ?? 0
        allowInvite = (try? c.decode(Int.self, forKey: .allowInvite)) ?? 1
    }
}
