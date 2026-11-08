import Foundation

enum APIError: LocalizedError {
    case auth
    case server(String)
    case network(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .auth: return "登录已过期，请重新登录"
        case .server(let m): return m
        case .network(let m): return "网络异常：\(m)"
        case .decoding: return "数据解析失败"
        }
    }
}

final class APIClient {
    static let shared = APIClient()
    static let base = URL(string: "https://www.aksliao.cn/")!
    static let wsURL = URL(string: "wss://www.aksliao.cn/ws")!

    private let session: URLSession

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 60
        session = URLSession(configuration: cfg)
    }

    static func fullURL(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http://") || path.hasPrefix("https://") { return URL(string: path) }
        return URL(string: path.trimmingCharacters(in: CharacterSet(charactersIn: "/")), relativeTo: base)
    }

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        try await request(path, method: "GET", query: query)
    }

    func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        try await request(path, method: "POST", body: body)
    }

    private func request<T: Decodable>(
        _ path: String,
        method: String,
        query: [String: String] = [:],
        body: [String: Any]? = nil
    ) async throws -> T {
        var comps = URLComponents(url: APIClient.base.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            comps?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = comps?.url else { throw APIError.network("地址无效") }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = SessionStore.shared.token, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw APIError.network(error.localizedDescription)
        }

        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            throw APIError.auth
        }
        if let http = resp as? HTTPURLResponse, http.statusCode == 403 {
            let text = String(data: data, encoding: .utf8) ?? ""
            if text.contains("账号已被封禁") { throw APIError.server("账号已被封禁") }
        }

        let decoded: APIResp<T>
        do {
            decoded = try JSONDecoder().decode(APIResp<T>.self, from: data)
        } catch {
            throw APIError.decoding
        }
        guard decoded.code == 0 else {
            throw APIError.server(decoded.msg ?? "请求失败（\(decoded.code)）")
        }
        guard let payload = decoded.data else { throw APIError.decoding }
        return payload
    }

    /// 只关心成功/失败与提示文案的接口（data 可能为 null，比如发验证码、重置密码）
    @discardableResult
    func postRaw(_ path: String, body: [String: Any]) async throws -> String {
        var req = URLRequest(url: APIClient.base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = SessionStore.shared.token, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        do {
            (data, _) = try await session.data(for: req)
        } catch {
            throw APIError.network(error.localizedDescription)
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decoding
        }
        let code = (obj["code"] as? NSNumber)?.intValue ?? -1
        let msg = obj["msg"] as? String ?? ""
        if code != 0 {
            throw APIError.server(msg.isEmpty ? "请求失败（\(code)）" : msg)
        }
        return msg
    }

    // MARK: - 业务接口

    func login(account: String, password: String) async throws -> LoginData {
        try await post("api/v1/auth/login", body: [
            "account": account,
            "password": password,
            "device_id": SessionStore.shared.deviceId,
            "device_name": "iPhone",
            "platform": "ios"
        ])
    }

    func me() async throws -> User { try await get("api/v1/me") }

    func conversations() async throws -> ConversationList { try await get("api/v1/conversations") }

    func history(convType: String, convId: Int64, beforeId: Int64 = 0, limit: Int = 40) async throws -> HistoryData {
        try await get("api/v1/messages", query: [
            "conv_type": convType,
            "conv_id": String(convId),
            "before_id": String(beforeId),
            "limit": String(limit)
        ])
    }

    func sendText(convType: String, convId: Int64, text: String, clientId: String, atUids: String = "") async throws -> SendData {
        var body: [String: Any] = [
            "conv_type": convType,
            "conv_id": convId,
            "type": 1,
            "content": text,
            "client_msg_id": clientId
        ]
        if !atUids.isEmpty { body["at_uids"] = atUids }
        return try await post("api/v1/messages", body: body)
    }

    func sendImage(convType: String, convId: Int64, url: String, clientId: String) async throws -> SendData {
        try await post("api/v1/messages", body: [
            "conv_type": convType,
            "conv_id": convId,
            "type": 5,
            "content": url,
            "client_msg_id": clientId
        ])
    }

    func sendVoice(convType: String, convId: Int64, url: String, seconds: Int, clientId: String) async throws -> SendData {
        try await post("api/v1/messages", body: [
            "conv_type": convType,
            "conv_id": convId,
            "type": 6,
            "content": "\(url)|#|{\"duration\":\(seconds)}",
            "client_msg_id": clientId
        ])
    }

    /// 转发：原 type 与 content 原样重发，卡片由服务端重新下发
    func forwardMessage(message: Message, convType: String, convId: Int64) async throws {
        let content = message.content ?? message.text ?? ""
        guard !content.isEmpty else { return }
        let type = message.type == 11 ? 1 : message.type
        _ = try await postRaw("api/v1/messages", body: [
            "conv_type": convType,
            "conv_id": convId,
            "type": type,
            "content": content,
            "client_msg_id": "ios_fwd_\(UUID().uuidString)",
        ])
    }

    func read(convType: String, convId: Int64, lastId: Int64) async throws -> ReadData {
        try await post("api/v1/read", body: [
            "conv_type": convType,
            "conv_id": convId,
            "last_id": lastId
        ])
    }

    func contacts() async throws -> ContactsData { try await get("api/v1/contacts") }

    func groupInfo(id: Int64) async throws -> GroupInfo {
        try await get("api/v1/group", query: ["id": String(id)])
    }

    func quitGroup(id: Int64) async { await postIgnore("api/v1/group/quit", body: ["id": id]) }

    func notices() async throws -> NoticesData { try await get("api/v1/notices") }

    func notice(id: Int64) async throws -> NoticeDetail {
        try await get("api/v1/notice", query: ["id": String(id)])
    }

    func readNotice(id: Int64) async {
        await postIgnore("api/v1/notice/read", body: ["id": id, "all": 0])
    }

    func updateProfile(nickname: String, bio: String) async {
        await postIgnore("api/v1/profile/update", body: ["nickname": nickname, "bio": bio])
    }

    func groupNotices(gid: Int64) async throws -> GroupNoticesData {
        try await get("api/v1/group/notices", query: ["gid": String(gid)])
    }

    func saveGroupNotice(gid: Int64, id: Int64, content: String, imagesJSON: String) async {
        await postIgnore("api/v1/group/notice", body: [
            "gid": gid,
            "id": id,
            "content": content,
            "images": imagesJSON,
            "is_top": 0,
            "need_ack": 0,
            "popup": 0,
            "send_to_new": 0
        ])
    }

    /// 我已知晓（服务端会同时写老哈希确认，避免再弹）
    func ackGroupNotice(id: Int64) async {
        await postIgnore("api/v1/group/notice/ack", body: ["id": id])
    }

    func deleteGroupNotice(gid: Int64, id: Int64) async {
        await postIgnore("api/v1/group/notice/delete", body: ["gid": gid, "id": id])
    }

    func createGroup(name: String, intro: String, members: [Int64]) async throws -> CreateGroupResult {
        try await post("api/v1/group/create", body: [
            "name": name,
            "intro": intro,
            "members": members,
            "avatar": ""
        ])
    }

    func searchUsers(keyword: String) async throws -> SearchResult {
        try await post("api/v1/friends/search", body: ["keyword": keyword])
    }

    func addFriend(toUid: Int64, message: String) async {
        await postIgnore("api/v1/friends/add", body: ["to_uid": toUid, "message": message])
    }

    func muteMember(gid: Int64, uid: Int64, minutes: Int) async {
        await postIgnore("api/v1/group/member/mute", body: ["gid": gid, "user_id": uid, "minutes": minutes])
    }

    func kickMember(gid: Int64, uid: Int64) async {
        await postIgnore("api/v1/group/member/kick", body: ["gid": gid, "user_id": uid])
    }

    func setAdmin(gid: Int64, uid: Int64, role: Int) async {
        await postIgnore("api/v1/group/set-admin", body: ["id": gid, "uid": uid, "role": role])
    }

    func invitable(gid: Int64) async throws -> InvitableData {
        try await get("api/v1/group/invitable", query: ["id": String(gid)])
    }

    func inviteMembers(gid: Int64, uids: [Int64]) async {
        await postIgnore("api/v1/group/invite", body: ["id": gid, "uids": uids])
    }

    func groupInvites() async throws -> GroupInvitesData { try await get("api/v1/group/invites") }

    func handleGroupInvite(id: Int64, pass: Bool) async {
        await postIgnore("api/v1/group/invites/handle", body: ["id": id, "pass": pass ? 1 : 0])
    }

    func blacklist() async throws -> BlacklistData { try await get("api/v1/blacklist") }

    func blockUser(uid: Int64, act: String) async {
        await postIgnore("api/v1/block", body: ["user_id": uid, "act": act])
    }

    func walletInfo() async throws -> WalletInfo { try await get("api/v1/wallet/info") }

    func walletLogs() async throws -> WalletLogsData { try await get("api/v1/wallet/logs") }

    func vipPlans() async throws -> VipPlansData { try await get("api/v1/vip/plans") }

    func convSet(convType: String, convId: Int64, key: String, value: Int) async {
        await postIgnore("api/v1/conversations/set", body: [
            "conv_type": convType,
            "conv_id": convId,
            "key": key,
            "value": value
        ])
    }

    func convDelete(convType: String, convId: Int64) async {
        await postIgnore("api/v1/conversations/delete", body: [
            "conv_type": convType,
            "conv_id": convId
        ])
    }

    func clearConversation(convType: String, convId: Int64) async {
        await postIgnore("api/v1/conversations/clear", body: [
            "conv_type": convType,
            "conv_id": convId
        ])
    }

    func readAll() async { await postIgnore("api/v1/conversations/read-all", body: [:]) }

    func deleteAccount() async {
        await postIgnore("api/v1/account/delete", body: [:])
    }

    func reportMessage(convType: String, msgId: Int64, reason: String, content: String) async {
        await postIgnore("api/v1/report/message", body: [
            "conv_type": convType,
            "msg_id": msgId,
            "reason": reason,
            "content": content
        ])
    }

    func recall(id: Int64, convType: String) async throws -> RecallData {
        try await post("api/v1/recall", body: ["id": id, "conv_type": convType])
    }

    func postIgnore(_ path: String, body: [String: Any]) async {
        let _: EmptyResponse? = try? await post(path, body: body)
    }

    func emojis() async throws -> EmojiList { try await get("api/v1/emoji") }

    func addEmoji(url: String) async { await postIgnore("api/v1/emoji/add", body: ["url": url]) }

    func deleteEmoji(url: String) async { await postIgnore("api/v1/emoji/delete", body: ["url": url]) }

    func friendRequests(box: String = "in") async throws -> FriendRequestsData {
        try await get("api/v1/friend-requests", query: ["box": box])
    }

    func handleFriendRequest(id: Int64, pass: Bool) async {
        await postIgnore("api/v1/friend-requests/handle", body: ["id": id, "pass": pass ? 1 : 0])
    }

    func moments(page: Int = 1, beforeId: Int64 = 0, mine: Int = 0, uid: Int64 = 0) async throws -> MomentsData {
        try await get("api/v1/moments", query: [
            "page": String(page),
            "before_id": String(beforeId),
            "mine": String(mine),
            "uid": String(uid)
        ])
    }

    func publishMoment(content: String, images: [String]) async {
        await postIgnore("api/v1/moments/publish", body: [
            "content": content,
            "images": images,
            "video_url": "",
            "duration": 0,
            "cover": ""
        ])
    }

    func likeMoment(id: Int64) async { await postIgnore("api/v1/moments/like", body: ["id": id]) }

    func commentMoment(id: Int64, content: String) async {
        await postIgnore("api/v1/moments/comment", body: ["id": id, "content": content])
    }

    /// 图片/文件上传，返回服务端相对地址
    // MARK: - 聊天背景（私聊仅自己；群聊仅群主可设、全员可见）
    func appConfig() async throws -> AppConfigData {
        try await get("api/v1/app-config")
    }

    func liveRoom(gid: Int64) async throws -> LiveRoomData {
        try await get("api/v1/group/live/room", query: ["id": String(gid)])
    }

    func startLive(gid: Int64, title: String) async throws -> LiveRoomData {
        try await post("api/v1/group/live/start", body: ["id": gid, "title": title])
    }

    func livePoll(gid: Int64, liveId: Int64, lastCommentId: Int64) async throws -> LivePollData {
        try await get("api/v1/group/live/poll", query: [
            "id": String(gid),
            "live_id": String(liveId),
            "last_comment_id": String(lastCommentId)
        ])
    }

    func liveComment(gid: Int64, liveId: Int64, content: String) async throws -> String {
        try await postRaw("api/v1/group/live/comment", body: [
            "id": gid,
            "live_id": liveId,
            "content": content
        ])
    }

    func groupCallJoin(gid: Int64, callType: Int) async throws -> GroupCallJoinData {
        try await post("api/v1/group/call/join", body: ["id": gid, "call_type": callType])
    }

    func groupCallLeave(gid: Int64) async {
        await postIgnore("api/v1/group/call/leave", body: ["id": gid])
    }

    // MARK: - 一对一通话信令（非 trickle ICE，SDP 带完整 candidate）
    func callCreate(toUid: Int64, callType: Int) async throws -> CallCreateData {
        try await post("api/v1/call/create", body: ["to_uid": toUid, "call_type": callType])
    }

    func callOffer(callId: Int64, sdp: String) async {
        await postIgnore("api/v1/call/offer", body: ["call_id": callId, "sdp": sdp])
    }

    func callAnswer(callId: Int64, sdp: String) async {
        await postIgnore("api/v1/call/answer", body: ["call_id": callId, "sdp": sdp])
    }

    func callHangup(callId: Int64) async {
        await postIgnore("api/v1/call/hangup", body: ["call_id": callId])
    }

    func callInfo(callId: Int64) async throws -> CallInfoData {
        try await get("api/v1/call/info", query: ["call_id": String(callId)])
    }

    func saveVoipToken(_ token: String) async {
        await postIgnore("api/v1/device/voip", body: ["token": token])
    }

    func chatBg(convType: String, convId: Int64) async throws -> ChatBgResp {
        try await get("api/v1/chat/bg", query: ["conv_type": convType, "conv_id": String(convId)])
    }

    func setChatBg(convType: String, convId: Int64, url: String) async throws -> ChatBgResp {
        try await post("api/v1/chat/bg", body: [
            "conv_type": convType,
            "conv_id": convId,
            "url": url
        ])
    }

    func upload(data: Data, filename: String, kind: String = "chat") async throws -> UploadData {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        func append(_ s: String) { body.append(s.data(using: .utf8)!) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"kind\"\r\n\r\n\(kind)\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: application/octet-stream\r\n\r\n")
        body.append(data)
        append("\r\n--\(boundary)--\r\n")

        var req = URLRequest(url: APIClient.base.appendingPathComponent("api/v1/upload"))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = SessionStore.shared.token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        let (respData, resp): (Data, URLResponse)
        do {
            (respData, resp) = try await session.upload(for: req, from: body)
        } catch {
            throw APIError.network(error.localizedDescription)
        }
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 { throw APIError.auth }
        guard let decoded = try? JSONDecoder().decode(APIResp<UploadData>.self, from: respData), decoded.code == 0, let payload = decoded.data else {
            throw APIError.server("上传失败")
        }
        return payload
    }
}
