import Foundation

/// 入群申请
struct GroupJoinRequest: Decodable, Identifiable {
    let rid: Int64
    let uid: Int64
    let nickname: String
    let avatar: String
    let reason: String
    let createdAt: Int64

    var id: Int64 { rid }

    enum CodingKeys: String, CodingKey {
        case rid, uid, nickname, avatar, reason
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rid = (try? c.decode(Int64.self, forKey: .rid)) ?? 0
        uid = (try? c.decode(Int64.self, forKey: .uid)) ?? 0
        nickname = (try? c.decode(String.self, forKey: .nickname)) ?? "成员"
        avatar = (try? c.decode(String.self, forKey: .avatar)) ?? ""
        reason = (try? c.decode(String.self, forKey: .reason)) ?? ""
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
    }
}

struct GroupJoinRequestsData: Decodable {
    let list: [GroupJoinRequest]
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decode([GroupJoinRequest].self, forKey: .list)) ?? []
    }
    enum CodingKeys: String, CodingKey { case list }
}

/// 群拉黑名单成员
struct GroupBlockedUser: Decodable, Identifiable, Equatable {
    let uid: Int64
    let nickname: String?
    let avatar: String?
    let yxId: String?
    let isPretty: Int
    let prettyNo: String?
    let vipLevel: Int
    let operatorUid: Int64
    let operatorName: String?
    let reason: String?
    let createdAt: Int64

    var id: Int64 { uid }

    enum CodingKeys: String, CodingKey {
        case uid, nickname, avatar, reason
        case yxId = "yx_id"
        case isPretty = "is_pretty"
        case prettyNo = "pretty_no"
        case vipLevel = "vip_level"
        case operatorUid = "operator_uid"
        case operatorName = "operator_name"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uid = (try? c.decode(Int64.self, forKey: .uid)) ?? 0
        nickname = try? c.decode(String.self, forKey: .nickname)
        avatar = try? c.decode(String.self, forKey: .avatar)
        yxId = try? c.decode(String.self, forKey: .yxId)
        isPretty = (try? c.decode(Int.self, forKey: .isPretty)) ?? 0
        prettyNo = try? c.decode(String.self, forKey: .prettyNo)
        vipLevel = (try? c.decode(Int.self, forKey: .vipLevel)) ?? 0
        operatorUid = (try? c.decode(Int64.self, forKey: .operatorUid)) ?? 0
        operatorName = try? c.decode(String.self, forKey: .operatorName)
        reason = try? c.decode(String.self, forKey: .reason)
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
    }
}

struct GroupBlockListData: Decodable {
    let list: [GroupBlockedUser]
    let total: Int

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decode([GroupBlockedUser].self, forKey: .list)) ?? []
        total = (try? c.decode(Int.self, forKey: .total)) ?? 0
    }
    enum CodingKeys: String, CodingKey { case list, total }
}

extension APIClient {
    func groupJoinRequests(gid: Int64) async throws -> GroupJoinRequestsData {
        try await get("api/v1/group/requests", query: ["id": "\(gid)"])
    }

    /// 群拉黑名单（仅群主/管理员）
    func groupBlocklist(gid: Int64) async throws -> GroupBlockListData {
        try await get("api/v1/group/blocklist", query: ["id": "\(gid)"])
    }

    func blockGroupMember(gid: Int64, uid: Int64, reason: String = "") async throws -> String {
        try await postRaw("api/v1/group/block", body: ["id": gid, "uid": uid, "reason": reason])
    }

    func unblockGroupMember(gid: Int64, uid: Int64) async throws -> String {
        try await postRaw("api/v1/group/unblock", body: ["id": gid, "uid": uid])
    }

    /// act: agree / refuse
    func handleGroupRequest(gid: Int64, requestId: Int64, act: String, reason: String = "") async throws {
        _ = try await postRaw("api/v1/group/requests/handle", body: [
            "id": gid, "request_id": requestId, "act": act, "reason": reason
        ])
    }

    func transferGroup(gid: Int64, toUid: Int64) async throws {
        _ = try await postRaw("api/v1/group/transfer", body: ["gid": gid, "to_uid": toUid])
    }

    func dissolveGroup(gid: Int64, name: String) async throws {
        _ = try await postRaw("api/v1/group/dissolve", body: ["gid": gid, "name": name])
    }
}

extension APIClient {
    /// 修改我在本群的昵称（user_id 传自己）
    func setGroupMyNickname(gid: Int64, userId: Int64, nickname: String) async throws {
        _ = try await postRaw("api/v1/group/member/nick", body: [
            "gid": gid, "user_id": userId, "nickname": nickname
        ])
    }
}
