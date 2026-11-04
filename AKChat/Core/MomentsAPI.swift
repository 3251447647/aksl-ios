import Foundation

struct MomentNotice: Decodable, Identifiable, Equatable {
    let id: Int64
    let type: String
    let fromUid: Int64
    let fromName: String
    let fromAvatar: String?
    let vipLevel: Int
    let isPretty: Int
    let prettyNo: String
    let momentId: Int64
    let commentId: Int64
    let content: String
    let isRead: Int
    let createdAt: Int64
    let momentText: String
    let momentThumb: String

    enum CodingKeys: String, CodingKey {
        case id, type, content
        case fromUid = "from_uid"
        case fromName = "from_name"
        case fromAvatar = "from_avatar"
        case vipLevel = "vip_level"
        case isPretty = "is_pretty"
        case prettyNo = "pretty_no"
        case momentId = "moment_id"
        case commentId = "comment_id"
        case isRead = "is_read"
        case createdAt = "created_at"
        case momentText = "moment_text"
        case momentThumb = "moment_thumb"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        type = (try? c.decode(String.self, forKey: .type)) ?? "like"
        fromUid = (try? c.decode(Int64.self, forKey: .fromUid)) ?? 0
        fromName = (try? c.decode(String.self, forKey: .fromName)) ?? "用户"
        fromAvatar = try? c.decode(String.self, forKey: .fromAvatar)
        vipLevel = (try? c.decode(Int.self, forKey: .vipLevel)) ?? 0
        isPretty = (try? c.decode(Int.self, forKey: .isPretty)) ?? 0
        prettyNo = (try? c.decode(String.self, forKey: .prettyNo)) ?? ""
        momentId = (try? c.decode(Int64.self, forKey: .momentId)) ?? 0
        commentId = (try? c.decode(Int64.self, forKey: .commentId)) ?? 0
        content = (try? c.decode(String.self, forKey: .content)) ?? ""
        isRead = (try? c.decode(Int.self, forKey: .isRead)) ?? 0
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
        momentText = (try? c.decode(String.self, forKey: .momentText)) ?? ""
        momentThumb = (try? c.decode(String.self, forKey: .momentThumb)) ?? ""
    }

    var actionText: String {
        switch type {
        case "like": return "赞了你的动态"
        case "reply": return "回复了你"
        case "comment": return "评论了你的动态"
        default: return "互动了你的动态"
        }
    }
}

struct MomentNoticesData: Decodable {
    let list: [MomentNotice]
    let unread: Int
    let hasMore: Int

    enum CodingKeys: String, CodingKey {
        case list, unread
        case hasMore = "has_more"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decode([MomentNotice].self, forKey: .list)) ?? []
        unread = (try? c.decode(Int.self, forKey: .unread)) ?? 0
        hasMore = (try? c.decode(Int.self, forKey: .hasMore)) ?? 0
    }
}

extension APIClient {
    func momentNotices(page: Int = 1) async throws -> MomentNoticesData {
        try await get("api/v1/moments/notices", query: ["page": "\(page)"])
    }

    func readMomentNotices(id: Int64 = 0) async {
        await postIgnore("api/v1/moments/notices/read", body: ["id": id])
    }

    func deleteMoment(id: Int64) async {
        await postIgnore("api/v1/moments/delete", body: ["id": id])
    }
}
