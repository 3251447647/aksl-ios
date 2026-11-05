import Foundation

struct APIResp<T: Decodable>: Decodable {
    let code: Int
    let msg: String?
    let data: T?
}

struct User: Codable, Identifiable, Equatable {
    let id: Int64
    var account: String?
    var nickname: String?
    var avatar: String?
    var yxId: String?
    var prettyYxid: String?
    var showYxid: String?
    var vipLevel: Int
    var vipDays: Int
    var coin: Int64
    var bio: String?
    var email: String?
    var phone: String?

    enum CodingKeys: String, CodingKey {
        case id, account, nickname, avatar, coin, bio, email, phone
        case yxId = "yx_id"
        case prettyYxid = "pretty_yxid"
        case showYxid = "show_yxid"
        case vipLevel = "vip_level"
        case vipDays = "vip_days"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        account = try? c.decode(String.self, forKey: .account)
        nickname = try? c.decode(String.self, forKey: .nickname)
        avatar = try? c.decode(String.self, forKey: .avatar)
        yxId = try? c.decode(String.self, forKey: .yxId)
        prettyYxid = try? c.decode(String.self, forKey: .prettyYxid)
        showYxid = try? c.decode(String.self, forKey: .showYxid)
        vipLevel = (try? c.decode(Int.self, forKey: .vipLevel)) ?? 0
        vipDays = (try? c.decode(Int.self, forKey: .vipDays)) ?? 0
        coin = (try? c.decode(Int64.self, forKey: .coin)) ?? 0
        bio = try? c.decode(String.self, forKey: .bio)
        email = try? c.decode(String.self, forKey: .email)
        phone = try? c.decode(String.self, forKey: .phone)
    }

    var displayName: String { (nickname?.isEmpty == false ? nickname! : (account ?? "用户")) }
    var displayNo: String { (showYxid?.isEmpty == false ? showYxid! : (yxId ?? "")) }
}

struct LoginData: Decodable {
    let token: String
    let refreshToken: String
    let expiresAt: Int64
    let user: User?

    enum CodingKeys: String, CodingKey {
        case token, user
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
    }
}

struct Conversation: Decodable, Identifiable, Equatable {
    let convType: String
    let convId: Int64
    var name: String?
    var avatar: String?
    var vipLevel: Int
    var isTop: Int
    var isMute: Int
    var unread: Int
    var lastMsgId: Int64
    var lastTime: Int64
    var lastType: Int
    var digest: String?
    var isPretty: Int
    var prettyNo: String?
    var atMe: Int
    var online: Int

    var id: String { "\(convType):\(convId)" }

    enum CodingKeys: String, CodingKey {
        case name, avatar, unread, digest, online
        case convType = "conv_type"
        case convId = "conv_id"
        case vipLevel = "vip_level"
        case isTop = "is_top"
        case isMute = "is_mute"
        case lastMsgId = "last_msg_id"
        case lastTime = "last_time"
        case lastType = "last_type"
        case isPretty = "is_pretty"
        case prettyNo = "pretty_no"
        case atMe = "at_me"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        convType = (try? c.decode(String.self, forKey: .convType)) ?? "private"
        convId = (try? c.decode(Int64.self, forKey: .convId)) ?? 0
        name = try? c.decode(String.self, forKey: .name)
        avatar = try? c.decode(String.self, forKey: .avatar)
        vipLevel = (try? c.decode(Int.self, forKey: .vipLevel)) ?? 0
        isTop = (try? c.decode(Int.self, forKey: .isTop)) ?? 0
        isMute = (try? c.decode(Int.self, forKey: .isMute)) ?? 0
        unread = (try? c.decode(Int.self, forKey: .unread)) ?? 0
        lastMsgId = (try? c.decode(Int64.self, forKey: .lastMsgId)) ?? 0
        lastTime = (try? c.decode(Int64.self, forKey: .lastTime)) ?? 0
        lastType = (try? c.decode(Int.self, forKey: .lastType)) ?? 0
        digest = try? c.decode(String.self, forKey: .digest)
        isPretty = (try? c.decode(Int.self, forKey: .isPretty)) ?? 0
        prettyNo = try? c.decode(String.self, forKey: .prettyNo)
        atMe = (try? c.decode(Int.self, forKey: .atMe)) ?? 0
        online = (try? c.decode(Int.self, forKey: .online)) ?? 0
    }
}

struct ConversationList: Decodable {
    let list: [Conversation]
    let unreadTotal: Int

    enum CodingKeys: String, CodingKey {
        case list
        case unreadTotal = "unread_total"
    }
}

struct Message: Decodable, Identifiable, Equatable {
    let id: Int64
    var convType: String
    var convId: Int64
    var fromUid: Int64
    var toUid: Int64
    var type: Int
    var text: String?
    var content: String?
    var createdAt: Int64
    var isRead: Int
    var recalled: Int
    var clientId: String?
    var fromName: String?
    var fromAvatar: String?
    var atMe: Int
    var atAll: Int
    var atUids: String?
    var fromRole: Int
    var operatorUid: Int64
    var originalType: Int
    var isEdited: Int
    /// 卡片类消息的结构随 type 变化（红包/转账/礼物/名片/通话/文件…）
    var extra: JSONValue?
    /// 本地临时消息（发送中/失败）用负数 id
    var localId: Int64 = 0
    /// 0 发送中 1 已发送 2 发送失败
    var status: Int = 1

    enum CodingKeys: String, CodingKey {
        case id, text, content, type, recalled, extra
        case convType = "conv_type"
        case convId = "conv_id"
        case fromUid = "from_uid"
        case toUid = "to_uid"
        case createdAt = "created_at"
        case isRead = "is_read"
        case clientId = "client_id"
        case fromName = "from_name"
        case fromAvatar = "from_avatar"
        case atMe = "at_me"
        case atAll = "at_all"
        case atUids = "at_uids"
        case fromRole = "from_role"
        case operatorUid = "operator_uid"
        case originalType = "original_type"
        case isEdited = "is_edited"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        convType = (try? c.decode(String.self, forKey: .convType)) ?? "private"
        convId = (try? c.decode(Int64.self, forKey: .convId)) ?? 0
        fromUid = (try? c.decode(Int64.self, forKey: .fromUid)) ?? 0
        toUid = (try? c.decode(Int64.self, forKey: .toUid)) ?? 0
        type = (try? c.decode(Int.self, forKey: .type)) ?? 1
        text = try? c.decode(String.self, forKey: .text)
        content = try? c.decode(String.self, forKey: .content)
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
        isRead = (try? c.decode(Int.self, forKey: .isRead)) ?? 0
        recalled = (try? c.decode(Int.self, forKey: .recalled)) ?? 0
        clientId = try? c.decode(String.self, forKey: .clientId)
        fromName = try? c.decode(String.self, forKey: .fromName)
        fromAvatar = try? c.decode(String.self, forKey: .fromAvatar)
        atMe = (try? c.decode(Int.self, forKey: .atMe)) ?? 0
        atAll = (try? c.decode(Int.self, forKey: .atAll)) ?? 0
        atUids = try? c.decode(String.self, forKey: .atUids)
        fromRole = (try? c.decode(Int.self, forKey: .fromRole)) ?? 0
        operatorUid = (try? c.decode(Int64.self, forKey: .operatorUid)) ?? 0
        originalType = (try? c.decode(Int.self, forKey: .originalType)) ?? 0
        isEdited = (try? c.decode(Int.self, forKey: .isEdited)) ?? 0
        extra = try? c.decode(JSONValue.self, forKey: .extra)
    }

    init(local convType: String, convId: Int64, fromUid: Int64, type: Int = 1, content: String, localId: Int64) {
        self.id = 0
        self.convType = convType
        self.convId = convId
        self.fromUid = fromUid
        self.toUid = 0
        self.type = type
        self.text = content
        self.content = content
        self.createdAt = Int64(Date().timeIntervalSince1970)
        self.isRead = 0
        self.recalled = 0
        self.clientId = UUID().uuidString
        self.fromName = nil
        self.fromAvatar = nil
        self.atMe = 0
        self.atAll = 0
        self.atUids = nil
        self.fromRole = 0
        self.operatorUid = 0
        self.originalType = 0
        self.isEdited = 0
        self.extra = nil
        self.localId = localId
        self.status = 0
    }

    /// 本地临时消息用负数 id 参与列表标识；服务端消息用真实 id
    var listKey: String {
        if localId < 0 { return "local_\(localId)" }
        return "m_\(id)"
    }

    var extraMap: [String: JSONValue] {
        extra?.objectValue ?? [:]
    }
}

struct HistoryData: Decodable {
    let list: [Message]
    let hasMore: Int

    enum CodingKeys: String, CodingKey {
        case list
        case hasMore = "has_more"
    }
}

struct SendData: Decodable {
    let message: Message
    let duplicated: Int

    enum CodingKeys: String, CodingKey { case message, duplicated }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        message = try c.decode(Message.self, forKey: .message)
        duplicated = (try? c.decode(Int.self, forKey: .duplicated)) ?? 0
    }
}

struct ContactFriend: Decodable, Identifiable, Equatable {
    let id: Int64
    var name: String?
    var nickname: String?
    var avatar: String?
    var yxId: String?
    var vipLevel: Int
    var isPretty: Int
    var prettyNo: String?
    var online: Int
    var isBot: Int

    enum CodingKeys: String, CodingKey {
        case id, name, nickname, avatar, online
        case yxId = "yx_id"
        case vipLevel = "vip_level"
        case isPretty = "is_pretty"
        case prettyNo = "pretty_no"
        case isBot = "is_bot"
    }

    var displayName: String { (name?.isEmpty == false ? name! : (nickname ?? "好友")) }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        name = try? c.decode(String.self, forKey: .name)
        nickname = try? c.decode(String.self, forKey: .nickname)
        avatar = try? c.decode(String.self, forKey: .avatar)
        yxId = try? c.decode(String.self, forKey: .yxId)
        vipLevel = (try? c.decode(Int.self, forKey: .vipLevel)) ?? 0
        isPretty = (try? c.decode(Int.self, forKey: .isPretty)) ?? 0
        prettyNo = try? c.decode(String.self, forKey: .prettyNo)
        online = (try? c.decode(Int.self, forKey: .online)) ?? 0
        isBot = (try? c.decode(Int.self, forKey: .isBot)) ?? 0
    }
}

struct ContactGroup: Decodable, Identifiable, Equatable {
    let id: Int64
    var name: String?
    var avatar: String?
    var memberCount: Int
    var isPretty: Int
    var prettyNo: String?

    enum CodingKeys: String, CodingKey {
        case id, name, avatar
        case memberCount = "member_count"
        case isPretty = "is_pretty"
        case prettyNo = "pretty_no"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        name = try? c.decode(String.self, forKey: .name)
        avatar = try? c.decode(String.self, forKey: .avatar)
        memberCount = (try? c.decode(Int.self, forKey: .memberCount)) ?? 0
        isPretty = (try? c.decode(Int.self, forKey: .isPretty)) ?? 0
        prettyNo = try? c.decode(String.self, forKey: .prettyNo)
    }
}

struct ContactsData: Decodable {
    let friends: [ContactFriend]
    let groups: [ContactGroup]
    let pending: Int
    let groupInviteUnread: Int

    enum CodingKeys: String, CodingKey {
        case friends, groups
        case pending = "pending_friend_requests"
        case groupInviteUnread = "group_invite_unread"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        friends = (try? c.decode([ContactFriend].self, forKey: .friends)) ?? []
        groups = (try? c.decode([ContactGroup].self, forKey: .groups)) ?? []
        pending = (try? c.decode(Int.self, forKey: .pending)) ?? 0
        groupInviteUnread = (try? c.decode(Int.self, forKey: .groupInviteUnread)) ?? 0
    }
}

struct ReadData: Decodable {
    let unreadTotal: Int

    enum CodingKeys: String, CodingKey { case unreadTotal = "unread_total" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        unreadTotal = (try? c.decode(Int.self, forKey: .unreadTotal)) ?? 0
    }
}

struct UploadData: Decodable {
    let url: String
    let w: Int
    let h: Int
}

struct RecallData: Decodable {
    let text: String?
    let fromUid: Int64
    let operatorUid: Int64

    enum CodingKeys: String, CodingKey {
        case text
        case fromUid = "from_uid"
        case operatorUid = "operator_uid"
    }
}

struct EmptyResponse: Decodable {
    init(from decoder: Decoder) throws {}
}

struct EmojiItem: Decodable, Identifiable, Equatable {
    let id: Int64
    let url: String

    enum CodingKeys: String, CodingKey { case id, url }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        url = (try? c.decode(String.self, forKey: .url)) ?? ""
    }
}

struct EmojiList: Decodable {
    let list: [EmojiItem]
}

struct FriendRequest: Decodable, Identifiable, Equatable {
    let id: Int64
    let fromUid: Int64
    let nickname: String?
    let avatar: String?
    let yxId: String?
    let message: String?
    let status: Int
    let createdAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, nickname, avatar, message, status
        case fromUid = "from_uid"
        case yxId = "yx_id"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        fromUid = (try? c.decode(Int64.self, forKey: .fromUid)) ?? 0
        nickname = try? c.decode(String.self, forKey: .nickname)
        avatar = try? c.decode(String.self, forKey: .avatar)
        yxId = try? c.decode(String.self, forKey: .yxId)
        message = try? c.decode(String.self, forKey: .message)
        status = (try? c.decode(Int.self, forKey: .status)) ?? 0
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
    }
}

struct FriendRequestsData: Decodable {
    let list: [FriendRequest]
    let pending: Int
}

struct MomentLike: Decodable, Identifiable, Equatable {
    let uid: Int64
    let name: String?
    var id: Int64 { uid }
}

struct MomentComment: Decodable, Identifiable, Equatable {
    let id: Int64
    let uid: Int64
    let name: String?
    let avatar: String?
    let content: String?
    let replyName: String?
    let canDelete: Int
    let createdAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, uid, name, avatar, content
        case replyName = "reply_name"
        case canDelete = "can_delete"
        case createdAt = "created_at"
    }
}

struct Moment: Decodable, Identifiable, Equatable {
    let id: Int64
    let userId: Int64
    let nickname: String?
    let avatar: String?
    let content: String?
    let images: [String]
    let likeCount: Int
    let commentCount: Int
    let liked: Int
    let vipLevel: Int
    let prettyYxid: String?
    let createdAt: Int64
    let likes: [MomentLike]
    let comments: [MomentComment]

    enum CodingKeys: String, CodingKey {
        case id, nickname, avatar, content, images, liked, likes, comments
        case userId = "user_id"
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case vipLevel = "vip_level"
        case prettyYxid = "pretty_yxid"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        userId = (try? c.decode(Int64.self, forKey: .userId)) ?? 0
        nickname = try? c.decode(String.self, forKey: .nickname)
        avatar = try? c.decode(String.self, forKey: .avatar)
        content = try? c.decode(String.self, forKey: .content)
        images = (try? c.decode([String].self, forKey: .images)) ?? []
        likeCount = (try? c.decode(Int.self, forKey: .likeCount)) ?? 0
        commentCount = (try? c.decode(Int.self, forKey: .commentCount)) ?? 0
        liked = (try? c.decode(Int.self, forKey: .liked)) ?? 0
        vipLevel = (try? c.decode(Int.self, forKey: .vipLevel)) ?? 0
        prettyYxid = try? c.decode(String.self, forKey: .prettyYxid)
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
        likes = (try? c.decode([MomentLike].self, forKey: .likes)) ?? []
        comments = (try? c.decode([MomentComment].self, forKey: .comments)) ?? []
    }
}

struct MomentsData: Decodable {
    let list: [Moment]
    let page: Int
    let hasMore: Int
    let nextBeforeId: Int64

    enum CodingKeys: String, CodingKey {
        case list, page
        case hasMore = "has_more"
        case nextBeforeId = "next_before_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decode([Moment].self, forKey: .list)) ?? []
        page = (try? c.decode(Int.self, forKey: .page)) ?? 1
        hasMore = (try? c.decode(Int.self, forKey: .hasMore)) ?? 0
        nextBeforeId = (try? c.decode(Int64.self, forKey: .nextBeforeId)) ?? 0
    }
}

struct ChatBgResp: Decodable {
    let bg: String?
    let isOwner: Int?

    enum CodingKeys: String, CodingKey {
        case bg
        case isOwner = "is_owner"
    }
}

struct AppConfigData: Decodable {
    let botUid: Int64?
    let botQuickButtons: [String]?

    enum CodingKeys: String, CodingKey {
        case botUid = "bot_uid"
        case botQuickButtons = "bot_quick_buttons"
    }
}
