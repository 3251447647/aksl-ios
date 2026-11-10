import Foundation

struct SearchGroup: Decodable, Identifiable, Equatable {
    let id: Int64
    let name: String
    let avatar: String?
    let memberCount: Int
    let groupNo: String
    let isPretty: Int
    let prettyNo: String
    let isMember: Int

    enum CodingKeys: String, CodingKey {
        case id, name, avatar
        case memberCount = "member_count"
        case groupNo = "group_no"
        case isPretty = "is_pretty"
        case prettyNo = "pretty_no"
        case isMember = "is_member"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? c.decode(String.self, forKey: .name)) ?? "群聊"
        avatar = try? c.decode(String.self, forKey: .avatar)
        memberCount = (try? c.decode(Int.self, forKey: .memberCount)) ?? 0
        groupNo = (try? c.decode(String.self, forKey: .groupNo)) ?? ""
        isPretty = (try? c.decode(Int.self, forKey: .isPretty)) ?? 0
        prettyNo = (try? c.decode(String.self, forKey: .prettyNo)) ?? ""
        isMember = (try? c.decode(Int.self, forKey: .isMember)) ?? 0
    }
}

struct SearchMessageItem: Decodable, Identifiable, Equatable {
    let id: Int64
    let convType: String
    let convId: Int64
    let convName: String
    let convAvatar: String?
    let fromName: String
    let type: Int
    let digest: String
    let createdAt: Int64
    let recalled: Int

    enum CodingKeys: String, CodingKey {
        case id, type, digest, recalled
        case convType = "conv_type"
        case convId = "conv_id"
        case convName = "conv_name"
        case convAvatar = "conv_avatar"
        case fromName = "from_name"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        convType = (try? c.decode(String.self, forKey: .convType)) ?? "private"
        convId = (try? c.decode(Int64.self, forKey: .convId)) ?? 0
        convName = (try? c.decode(String.self, forKey: .convName)) ?? ""
        convAvatar = try? c.decode(String.self, forKey: .convAvatar)
        fromName = (try? c.decode(String.self, forKey: .fromName)) ?? ""
        type = (try? c.decode(Int.self, forKey: .type)) ?? 1
        digest = (try? c.decode(String.self, forKey: .digest)) ?? ""
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
        recalled = (try? c.decode(Int.self, forKey: .recalled)) ?? 0
    }
}

struct SearchMessagesData: Decodable {
    let list: [SearchMessageItem]
    let hasMore: Int

    enum CodingKeys: String, CodingKey {
        case list
        case hasMore = "has_more"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decode([SearchMessageItem].self, forKey: .list)) ?? []
        hasMore = (try? c.decode(Int.self, forKey: .hasMore)) ?? 0
    }
}

extension APIClient {
    func search(keyword: String) async throws -> SearchResult {
        let data: SearchResult = try await get("api/v1/search", query: ["keyword": keyword])
        return data.exactNumberMatches(keyword: keyword)
    }

    func searchMessages(keyword: String, convType: String = "", convId: Int64 = 0,
                        beforeId: Int64 = 0) async throws -> SearchMessagesData {
        var query: [String: String] = ["keyword": keyword, "limit": "30"]
        if !convType.isEmpty {
            query["conv_type"] = convType
            query["conv_id"] = "\(convId)"
        }
        if beforeId > 0 {
            query["before_id"] = "\(beforeId)"
        }
        return try await get("api/v1/search/messages", query: query)
    }

    func joinGroup(id: Int64, reason: String = "") async throws -> String {
        try await postRaw("api/v1/group/join", body: ["id": id, "reason": reason])
    }
}
