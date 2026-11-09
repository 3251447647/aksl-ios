import Foundation

struct GroupMember: Decodable, Identifiable, Equatable {
    let uid: Int64
    let name: String?
    let avatar: String?
    let role: Int
    let vipLevel: Int
    let isPretty: Int
    let prettyNo: String?

    var id: Int64 { uid }

    enum CodingKeys: String, CodingKey {
        case uid, name, avatar, role
        case vipLevel = "vip_level"
        case isPretty = "is_pretty"
        case prettyNo = "pretty_no"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uid = (try? c.decode(Int64.self, forKey: .uid)) ?? 0
        name = try? c.decode(String.self, forKey: .name)
        avatar = try? c.decode(String.self, forKey: .avatar)
        role = (try? c.decode(Int.self, forKey: .role)) ?? 0
        vipLevel = (try? c.decode(Int.self, forKey: .vipLevel)) ?? 0
        isPretty = (try? c.decode(Int.self, forKey: .isPretty)) ?? 0
        prettyNo = try? c.decode(String.self, forKey: .prettyNo)
    }
}

struct GroupInfo: Decodable {
    let id: Int64
    let name: String?
    let avatar: String?
    let intro: String?
    let notice: String?
    let groupNo: String?
    let prettyGroupNo: String?
    let isPretty: Int
    let ownerId: Int64
    let memberCount: Int
    let maxMember: Int
    let isBanned: Int
    let banReason: String?
    let myRole: Int
    let myMuteUntil: Int64
    let allowInvite: Int
    let myNickname: String
    let members: [GroupMember]

    enum CodingKeys: String, CodingKey {
        case id, name, avatar, intro, notice, members
        case groupNo = "group_no"
        case prettyGroupNo = "pretty_group_no"
        case isPretty = "is_pretty"
        case ownerId = "owner_id"
        case memberCount = "member_count"
        case maxMember = "max_member"
        case isBanned = "is_banned"
        case banReason = "ban_reason"
        case myRole = "my_role"
        case myMuteUntil = "my_mute_until"
        case allowInvite = "allow_invite"
        case myNickname = "my_nickname"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        name = try? c.decode(String.self, forKey: .name)
        avatar = try? c.decode(String.self, forKey: .avatar)
        intro = try? c.decode(String.self, forKey: .intro)
        notice = try? c.decode(String.self, forKey: .notice)
        groupNo = try? c.decode(String.self, forKey: .groupNo)
        prettyGroupNo = try? c.decode(String.self, forKey: .prettyGroupNo)
        isPretty = (try? c.decode(Int.self, forKey: .isPretty)) ?? 0
        ownerId = (try? c.decode(Int64.self, forKey: .ownerId)) ?? 0
        memberCount = (try? c.decode(Int.self, forKey: .memberCount)) ?? 0
        maxMember = (try? c.decode(Int.self, forKey: .maxMember)) ?? 0
        isBanned = (try? c.decode(Int.self, forKey: .isBanned)) ?? 0
        banReason = try? c.decode(String.self, forKey: .banReason)
        myRole = (try? c.decode(Int.self, forKey: .myRole)) ?? 0
        myMuteUntil = (try? c.decode(Int64.self, forKey: .myMuteUntil)) ?? 0
        allowInvite = (try? c.decode(Int.self, forKey: .allowInvite)) ?? 1
        myNickname = (try? c.decode(String.self, forKey: .myNickname)) ?? ""
        members = (try? c.decode([GroupMember].self, forKey: .members)) ?? []
    }

    var displayNo: String {
        if let pretty = prettyGroupNo, !pretty.isEmpty { return pretty }
        return groupNo ?? ""
    }
}

struct Notice: Decodable, Identifiable, Equatable {
    let id: Int64
    let title: String?
    let summary: String?
    let content: String?
    let images: [String]
    let read: Int
    let isTop: Int
    let createdAt: Int64

    init(id: Int64, title: String?, summary: String?, content: String?, images: [String], read: Int, isTop: Int, createdAt: Int64) {
        self.id = id
        self.title = title
        self.summary = summary
        self.content = content
        self.images = images
        self.read = read
        self.isTop = isTop
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, title, summary, content, images, read
        case isTop = "is_top"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        title = try? c.decode(String.self, forKey: .title)
        summary = try? c.decode(String.self, forKey: .summary)
        content = try? c.decode(String.self, forKey: .content)
        images = (try? c.decode([String].self, forKey: .images)) ?? []
        read = (try? c.decode(Int.self, forKey: .read)) ?? 0
        isTop = (try? c.decode(Int.self, forKey: .isTop)) ?? 0
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
    }
}

struct NoticesData: Decodable {
    let list: [Notice]
    let unread: Int
}

struct NoticeDetail: Decodable {
    let id: Int64
    let title: String?
    let content: String?
    let images: [String]
    let createdAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, title, content, images
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        title = try? c.decode(String.self, forKey: .title)
        content = try? c.decode(String.self, forKey: .content)
        images = (try? c.decode([String].self, forKey: .images)) ?? []
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
    }
}
