import Foundation

struct PinInfo: Decodable, Equatable {
    let msgId: Int64
    let digest: String
    let fromUid: Int64
    let createdAt: Int64

    enum CodingKeys: String, CodingKey {
        case digest
        case msgId = "msg_id"
        case fromUid = "from_uid"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        msgId = (try? c.decode(Int64.self, forKey: .msgId)) ?? 0
        digest = (try? c.decode(String.self, forKey: .digest)) ?? ""
        fromUid = (try? c.decode(Int64.self, forKey: .fromUid)) ?? 0
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
    }
}

struct PinData: Decodable {
    let pin: PinInfo?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pin = try? c.decode(PinInfo.self, forKey: .pin)
    }

    enum CodingKeys: String, CodingKey { case pin }
}

struct GroupTopItem: Decodable, Identifiable, Equatable {
    let id: Int64
    let type: Int
    let digest: String
    let fromName: String
    let createdAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, type, digest
        case fromName = "from_name"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        type = (try? c.decode(Int.self, forKey: .type)) ?? 1
        digest = (try? c.decode(String.self, forKey: .digest)) ?? ""
        fromName = (try? c.decode(String.self, forKey: .fromName)) ?? ""
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
    }
}

struct GroupTopData: Decodable {
    let list: [GroupTopItem]

    enum CodingKeys: String, CodingKey { case list }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decode([GroupTopItem].self, forKey: .list)) ?? []
    }
}

struct FavoriteItem: Decodable, Identifiable, Equatable {
    let id: Int64
    let type: Int
    let content: String
    let convName: String
    let fromName: String
    let createdAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, type, content
        case convName = "conv_name"
        case fromName = "from_name"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        type = (try? c.decode(Int.self, forKey: .type)) ?? 1
        content = (try? c.decode(String.self, forKey: .content)) ?? ""
        convName = (try? c.decode(String.self, forKey: .convName)) ?? ""
        fromName = (try? c.decode(String.self, forKey: .fromName)) ?? ""
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
    }
}

struct FavoriteList: Decodable {
    let list: [FavoriteItem]
    let total: Int
    let hasMore: Int

    enum CodingKeys: String, CodingKey {
        case list, total
        case hasMore = "has_more"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decode([FavoriteItem].self, forKey: .list)) ?? []
        total = (try? c.decode(Int.self, forKey: .total)) ?? 0
        hasMore = (try? c.decode(Int.self, forKey: .hasMore)) ?? 0
    }
}

extension APIClient {
    /// 私聊置顶消息（/pin 只支持私聊；群置顶走 /group/top）
    func pinInfo(peer: Int64) async throws -> PinInfo? {
        let data: PinData = try await get("api/v1/pin", query: ["conv_type": "private", "conv_id": "\(peer)"])
        return data.pin
    }

    func setPin(peer: Int64, msgId: Int64) async {
        await postIgnore("api/v1/pin", body: ["conv_type": "private", "conv_id": peer, "msg_id": msgId, "scope": "all"])
    }

    func groupTop(gid: Int64) async throws -> [GroupTopItem] {
        let data: GroupTopData = try await get("api/v1/group/top", query: ["id": "\(gid)"])
        return data.list
    }

    func setGroupTop(gid: Int64, msgId: Int64, top: Bool) async {
        await postIgnore("api/v1/group/top", body: ["id": gid, "message_id": msgId, "top": top ? 1 : 0])
    }

    func sendTyping(convType: String, convId: Int64) async {
        await postIgnore("api/v1/typing", body: ["conv_type": convType, "conv_id": convId])
    }

    func addFavorite(message: Message, convName: String) async {
        await postIgnore("api/v1/favorites/add", body: [
            "msg_id": message.id,
            "conv_type": message.convType,
            "conv_id": message.convId,
            "conv_name": convName,
            "from_name": message.fromName ?? "",
            "from_avatar": message.fromAvatar ?? "",
            "from_uid": message.fromUid,
            "type": message.type,
            "content": message.content ?? message.text ?? "",
        ])
    }

    func favorites(page: Int = 1) async throws -> FavoriteList {
        try await get("api/v1/favorites", query: ["page": "\(page)"])
    }

    func deleteFavorite(id: Int64) async {
        await postIgnore("api/v1/favorites/delete", body: ["id": id])
    }

    func pendingGroupNotice(gid: Int64) async -> GroupNotice? {
        try? await get("api/v1/group/notice/pending", query: ["gid": "\(gid)"])
    }

    func ackGroupNotice(gid: Int64, noticeId: Int64) async {
        await postIgnore("api/v1/group/notice/ack", body: ["gid": gid, "notice_id": noticeId])
    }
}
