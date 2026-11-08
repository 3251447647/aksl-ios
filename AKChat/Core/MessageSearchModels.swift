import Foundation

/// 聊天记录搜索命中（GET /api/v1/search/messages）
struct SearchMsgHit: Decodable, Identifiable, Equatable {
    let id: Int64
    let convType: String
    let convId: Int64
    let convName: String
    let convAvatar: String
    let fromUid: Int64
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
        case fromUid = "from_uid"
        case fromName = "from_name"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        convType = (try? c.decode(String.self, forKey: .convType)) ?? "private"
        convId = (try? c.decode(Int64.self, forKey: .convId)) ?? 0
        convName = (try? c.decode(String.self, forKey: .convName)) ?? ""
        convAvatar = (try? c.decode(String.self, forKey: .convAvatar)) ?? ""
        fromUid = (try? c.decode(Int64.self, forKey: .fromUid)) ?? 0
        fromName = (try? c.decode(String.self, forKey: .fromName)) ?? ""
        type = (try? c.decode(Int.self, forKey: .type)) ?? 1
        digest = (try? c.decode(String.self, forKey: .digest)) ?? ""
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
        recalled = (try? c.decode(Int.self, forKey: .recalled)) ?? 0
    }

    /// 会话标题：群里显示「群名 · 发送人」
    var subtitle: String {
        convType == "group" && !fromName.isEmpty ? "\(convName) · \(fromName)" : convName
    }
}

struct MessageSearchData: Decodable {
    let list: [SearchMsgHit]
    let hasMore: Int
    let page: Int
    let nextBeforeId: Int64
    let nextBeforeTs: Int64

    enum CodingKeys: String, CodingKey {
        case list, page
        case hasMore = "has_more"
        case nextBeforeId = "next_before_id"
        case nextBeforeTs = "next_before_ts"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decode([SearchMsgHit].self, forKey: .list)) ?? []
        hasMore = (try? c.decode(Int.self, forKey: .hasMore)) ?? 0
        page = (try? c.decode(Int.self, forKey: .page)) ?? 1
        nextBeforeId = (try? c.decode(Int64.self, forKey: .nextBeforeId)) ?? 0
        nextBeforeTs = (try? c.decode(Int64.self, forKey: .nextBeforeTs)) ?? 0
    }
}

/// 服务端最新版本（GET /api/v1/app/version，免登录）
struct AppVersionInfo: Decodable {
    let latestCode: Int
    let latestName: String
    let force: Int
    let changelog: String
    let url: String
    let size: Int64
    let minSupported: Int

    enum CodingKeys: String, CodingKey {
        case force, changelog, url, size
        case latestCode = "latest_code"
        case latestName = "latest_name"
        case minSupported = "min_supported"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        latestCode = (try? c.decode(Int.self, forKey: .latestCode)) ?? 0
        latestName = (try? c.decode(String.self, forKey: .latestName)) ?? ""
        force = (try? c.decode(Int.self, forKey: .force)) ?? 0
        changelog = (try? c.decode(String.self, forKey: .changelog)) ?? ""
        url = (try? c.decode(String.self, forKey: .url)) ?? ""
        size = (try? c.decode(Int64.self, forKey: .size)) ?? 0
        minSupported = (try? c.decode(Int.self, forKey: .minSupported)) ?? 0
    }
}
