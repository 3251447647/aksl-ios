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

extension APIClient {
    func groupJoinRequests(gid: Int64) async throws -> GroupJoinRequestsData {
        try await get("api/v1/group/requests", query: ["id": "\(gid)"])
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
