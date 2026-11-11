import Foundation

struct GroupNotice: Decodable, Identifiable, Equatable {
    let id: Int64
    let content: String?
    let images: String?
    let isTop: Int
    let needAck: Int
    let ackCount: Int
    let myAck: Int
    let publisherName: String?
    let publisherId: Int64
    let createdAt: Int64
    let readCount: Int
    let totalMembers: Int
    let myRead: Int
    let canManage: Int

    enum CodingKeys: String, CodingKey {
        case id, content, images, popup
        case isTop = "is_top"
        case needAck = "need_ack"
        case ackCount = "ack_count"
        case myAck = "my_ack"
        case publisherName = "publisher_name"
        case publisherId = "publisher_id"
        case createdAt = "created_at"
        case readCount = "read_count"
        case totalMembers = "total_members"
        case myRead = "my_read"
        case canManage = "can_manage"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        content = try? c.decode(String.self, forKey: .content)
        images = try? c.decode(String.self, forKey: .images)
        isTop = (try? c.decode(Int.self, forKey: .isTop)) ?? 0
        needAck = (try? c.decode(Int.self, forKey: .needAck)) ?? 0
        ackCount = (try? c.decode(Int.self, forKey: .ackCount)) ?? 0
        myAck = (try? c.decode(Int.self, forKey: .myAck)) ?? 0
        publisherName = try? c.decode(String.self, forKey: .publisherName)
        publisherId = (try? c.decode(Int64.self, forKey: .publisherId)) ?? 0
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
        readCount = (try? c.decode(Int.self, forKey: .readCount)) ?? 0
        totalMembers = (try? c.decode(Int.self, forKey: .totalMembers)) ?? 0
        myRead = (try? c.decode(Int.self, forKey: .myRead)) ?? 0
        canManage = (try? c.decode(Int.self, forKey: .canManage)) ?? 0
    }

    var imageList: [String] {
        guard let images, let data = images.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [String] else { return [] }
        return arr
    }
}

struct GroupNoticesData: Decodable {
    let list: [GroupNotice]
    let canManage: Int

    enum CodingKeys: String, CodingKey {
        case list
        case canManage = "can_manage"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decode([GroupNotice].self, forKey: .list)) ?? []
        canManage = (try? c.decode(Int.self, forKey: .canManage)) ?? 0
    }
}

struct CreateGroupResult: Decodable {
    let id: Int64
    let name: String?
    let pending: Int?
    let pendingNote: String?

    enum CodingKeys: String, CodingKey {
        case id, name, pending
        case pendingNote = "pending_note"
    }
}
