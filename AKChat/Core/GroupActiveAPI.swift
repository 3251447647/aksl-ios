import Foundation

/// 群内进行中的通话 / 直播（用于聊天页顶部横条）
struct GroupActiveLive: Decodable {
    let liveId: Int64
    let title: String
    let hostName: String
    let viewers: Int

    enum CodingKeys: String, CodingKey {
        case title, viewers
        case liveId = "live_id"
        case hostName = "host_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        liveId = (try? c.decode(Int64.self, forKey: .liveId)) ?? 0
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        hostName = (try? c.decode(String.self, forKey: .hostName)) ?? ""
        viewers = (try? c.decode(Int.self, forKey: .viewers)) ?? 0
    }
}

struct GroupActiveCall: Decodable {
    let callId: Int64
    let callType: Int
    let callerName: String
    let members: Int

    enum CodingKeys: String, CodingKey {
        case members
        case callId = "call_id"
        case callType = "call_type"
        case callerName = "caller_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        callId = (try? c.decode(Int64.self, forKey: .callId)) ?? 0
        callType = (try? c.decode(Int.self, forKey: .callType)) ?? 1
        callerName = (try? c.decode(String.self, forKey: .callerName)) ?? ""
        members = (try? c.decode(Int.self, forKey: .members)) ?? 0
    }
}

struct GroupActiveData: Decodable {
    let live: GroupActiveLive?
    let call: GroupActiveCall?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        live = try? c.decode(GroupActiveLive.self, forKey: .live)
        call = try? c.decode(GroupActiveCall.self, forKey: .call)
    }

    enum CodingKeys: String, CodingKey { case live, call }
}

extension APIClient {
    func groupActive(gid: Int64) async throws -> GroupActiveData {
        try await get("api/v1/group/active", query: ["id": "\(gid)"])
    }
}
