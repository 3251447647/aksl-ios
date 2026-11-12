import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var user: User?
    @Published var conversations: [Conversation] = []
    @Published var contacts: ContactsData?
    @Published var friendRequests: [FriendRequest] = []
    @Published var moments: [Moment] = []
    @Published var momentCover: String = ""
    @Published var emojis: [EmojiItem] = []
    /*
     * 逐条消息与 WS 事件不走 @Published：赋值会让每个持有 AppState 的视图
     * （4 个常驻 tab、所有 EnvironmentObject 页面）都重算一次 body，
     * 消息越多越明显。改成独立管道后只有聊天页订阅，其他页面不受影响。
     */
    let inbox = PassthroughSubject<Message, Never>()
    let events = PassthroughSubject<ChatEvent, Never>()
    @Published var incomingCall: IncomingCall?
    @Published var unreadTotal: Int = 0
    @Published var isLoggedIn: Bool
    @Published var loading = false
    @Published var errorText: String?
    @Published var botUid: Int64 = 0
    @Published var botQuick: [String] = []

    private let api = APIClient.shared
    private let ws = WSClient()
    private var wsStarted = false

    /// 会话列表刷新的合并状态：WS 每来一条消息、每次已读都会触发刷新，
    /// 逐个直发会让 4 个常驻 tab 的 body 反复重算，也会打满接口。
    /// 单飞 + 1 秒节流 + 尾随补刷：突发消息只发一次请求，最后一条消息仍会落到列表。
    private var convRefreshTask: Task<Void, Never>?
    private var convRefreshTail: Task<Void, Never>?
    private var convRefreshedAt: CFAbsoluteTime = 0
    private static let convRefreshInterval: CFAbsoluteTime = 1.0
    /// 已上报过的已读游标：同一游标重复 markRead 不再发请求
    private var readCursor: [String: Int64] = [:]

    init() {
        isLoggedIn = SessionStore.shared.isLoggedIn
        user = SessionStore.shared.user
    }

    func bootstrap() async {
        guard isLoggedIn else { return }
        do {
            let me = try await api.me()
            user = me
            SessionStore.shared.user = me
            await refreshConversations()
            await loadAppConfig()
            startSocket()
        } catch {
            if let apiError = error as? APIError, case .auth = apiError {
                logout()
            } else {
                errorText = error.localizedDescription
            }
        }
    }

    func loadAppConfig() async {
        guard let cfg = try? await api.appConfig() else { return }
        botUid = cfg.botUid ?? 0
        botQuick = cfg.botQuickButtons ?? []
    }

    func login(account: String, password: String) async {
        loading = true
        errorText = nil
        defer { loading = false }
        do {
            let data = try await api.login(account: account, password: password)
            SessionStore.shared.token = data.token
            SessionStore.shared.refreshToken = data.refreshToken
            SessionStore.shared.user = data.user
            user = data.user
            isLoggedIn = true
            await refreshConversations()
            await loadAppConfig()
            startSocket()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func register(nickname: String, password: String, email: String, code: String, invite: String) async {
        loading = true
        errorText = nil
        defer { loading = false }
        do {
            let data = try await api.register(nickname: nickname, password: password, email: email, code: code, invite: invite)
            SessionStore.shared.token = data.token
            SessionStore.shared.refreshToken = data.refreshToken
            SessionStore.shared.user = data.user
            user = data.user
            isLoggedIn = true
            await refreshConversations()
            await loadAppConfig()
            startSocket()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func logout() {
        ws.stop()
        wsStarted = false
        convRefreshTail?.cancel()
        convRefreshTail = nil
        convRefreshedAt = 0
        readCursor.removeAll()
        SessionStore.shared.clear()
        user = nil
        conversations = []
        contacts = nil
        isLoggedIn = false
    }

    /// force=true：用户主动操作（下拉刷新、置顶/免打扰/删除/一键已读）需要立刻拿到最新列表
    func refreshConversations(force: Bool = false) async {
        if let running = convRefreshTask {
            await running.value
            if !force {
                /* 这次请求可能没包含等待期间到达的消息：补一次尾随刷新（共享同一个任务，不会叠请求） */
                await scheduleConvRefresh(after: Self.convRefreshInterval)
                return
            }
        }
        if !force {
            let elapsed = CFAbsoluteTimeGetCurrent() - convRefreshedAt
            if elapsed < Self.convRefreshInterval {
                /* 1 秒内刚刷过：突发消息交给尾随补刷，调用方等那一次的结果 */
                await scheduleConvRefresh(after: Self.convRefreshInterval - elapsed)
                return
            }
        } else {
            /* 用户主动刷新马上发请求，排着的尾随补刷就多余了 */
            convRefreshTail?.cancel()
            convRefreshTail = nil
        }
        let task = Task { await self.fetchConversations() }
        convRefreshTask = task
        await task.value
        convRefreshTask = nil
        convRefreshedAt = CFAbsoluteTimeGetCurrent()
    }

    private func fetchConversations() async {
        let started = AKPerf.start()
        do {
            let data = try await api.conversations()
            applyConversations(data)
            AKPerf.log("app.conversations", since: started, "\(data.list.count) 个会话 · \(data.unreadTotal) 未读")
        } catch {
            setError(error)
        }
    }

    /// @Published 赋值不看新旧值，值没变也会让所有观察者重算 body
    private func applyConversations(_ data: ConversationList) {
        if conversations != data.list { conversations = data.list }
        if unreadTotal != data.unreadTotal { unreadTotal = data.unreadTotal }
    }

    private func scheduleConvRefresh(after delay: TimeInterval) async {
        let tail: Task<Void, Never>
        if let existing = convRefreshTail {
            tail = existing
        } else {
            tail = Task {
                try? await Task.sleep(nanoseconds: UInt64(max(delay, 0.05) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                convRefreshTail = nil
                await refreshConversations(force: true)
            }
            convRefreshTail = tail
        }
        await tail.value
    }

    private func setError(_ error: Error) {
        let text = error.localizedDescription
        if errorText != text { errorText = text }
    }

    func loadContacts() async {
        do {
            contacts = try await api.contacts()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func sendText(convType: String, convId: Int64, text: String, atUids: String = "") async throws -> Message {
        let clientId = "ios_" + UUID().uuidString
        let data = try await api.sendText(convType: convType, convId: convId, text: text, clientId: clientId, atUids: atUids)
        /* 会话列表刷新不阻塞发送：输入区要在消息返回后立刻解锁 */
        Task { await refreshConversations() }
        return data.message
    }

    func loadHistory(convType: String, convId: Int64, beforeId: Int64 = 0, anchorId: Int64 = 0) async throws -> [Message] {
        let data = try await api.history(convType: convType, convId: convId, beforeId: beforeId, anchorId: anchorId)
        return data.list
    }

    func markRead(convType: String, convId: Int64, lastId: Int64) async {
        guard lastId > 0 else { return }
        let key = "\(convType)_\(convId)"
        if readCursor[key, default: 0] >= lastId { return }
        if (try? await api.read(convType: convType, convId: convId, lastId: lastId)) != nil {
            readCursor[key] = lastId
        }
        /* 打开会话时不该为了刷列表而卡住消息渲染 */
        Task { await refreshConversations() }
    }

    func togglePin(_ conv: Conversation) async {
        await api.convSet(convType: conv.convType, convId: conv.convId, key: "top", value: conv.isTop == 1 ? 0 : 1)
        await refreshConversations(force: true)
    }

    func toggleMute(_ conv: Conversation) async {
        let next = conv.isMute == 1 ? 0 : 1
        /* 本地先落状态：刷新回来前的消息也要按新免打扰口径处理 */
        if let idx = conversations.firstIndex(where: {
            $0.convType == conv.convType && $0.convId == conv.convId
        }) {
            conversations[idx].isMute = next
        }
        await api.convSet(convType: conv.convType, convId: conv.convId, key: "mute", value: next)
        await refreshConversations(force: true)
    }

    /// 会话是否免打扰：本地通知与将来 APNs 前台展示共用同一口径
    func isConvMuted(convType: String, convId: Int64) -> Bool {
        conversations.contains { $0.convType == convType && $0.convId == convId && $0.isMute == 1 }
    }

    func deleteConversation(_ conv: Conversation) async {
        await api.convDelete(convType: conv.convType, convId: conv.convId)
        await refreshConversations(force: true)
    }

    func clearConversation(_ conv: Conversation) async {
        await APIClient.shared.clearConversation(convType: conv.convType, convId: conv.convId)
        await refreshConversations(force: true)
    }

    /// 一键已读（首页加号菜单）
    func markAllRead() async {
        await api.readAll()
        await refreshConversations(force: true)
    }

    func uploadImage(_ data: Data) async throws -> UploadData {
        try await APIClient.shared.upload(data: data, filename: "ios_\(Int(Date().timeIntervalSince1970)).jpg", kind: "chat")
    }

    func sendImage(convType: String, convId: Int64, url: String) async throws -> Message {
        let clientId = "ios_" + UUID().uuidString
        let data = try await APIClient.shared.sendImage(convType: convType, convId: convId, url: url, clientId: clientId)
        Task { await refreshConversations() }
        return data.message
    }

    func uploadVoice(fileURL: URL) async throws -> UploadData {
        let data = try Data(contentsOf: fileURL)
        return try await APIClient.shared.upload(data: data, filename: fileURL.lastPathComponent, kind: "voice")
    }

    func sendVoice(convType: String, convId: Int64, url: String, seconds: Int) async throws -> Message {
        let clientId = "ios_" + UUID().uuidString
        let data = try await APIClient.shared.sendVoice(convType: convType, convId: convId, url: url, seconds: seconds, clientId: clientId)
        Task { await refreshConversations() }
        return data.message
    }

    func sendSticker(convType: String, convId: Int64, url: String) async throws -> Message {
        let clientId = "sticker_" + UUID().uuidString
        let data = try await APIClient.shared.sendImage(convType: convType, convId: convId, url: url, clientId: clientId)
        Task { await refreshConversations() }
        return data.message
    }

    func loadEmojis() async {
        if let list = try? await APIClient.shared.emojis() {
            emojis = list.list
        } else {
            emojis = []
        }
    }

    func addEmoji(url: String) async {
        await APIClient.shared.addEmoji(url: url)
        await loadEmojis()
    }

    func loadFriendRequests() async {
        if let data = try? await APIClient.shared.friendRequests() {
            friendRequests = data.list
        } else {
            friendRequests = []
        }
    }

    func handleFriendRequest(_ req: FriendRequest, pass: Bool) async {
        await APIClient.shared.handleFriendRequest(id: req.id, pass: pass)
        await loadFriendRequests()
        await loadContacts()
    }

    func loadMoments() async {
        if let data = try? await APIClient.shared.moments() {
            moments = data.list
            momentCover = data.cover
        } else {
            moments = []
        }
    }

    func publishMoment(content: String, images: [String],
                       videoUrl: String = "", duration: Int = 0, cover: String = "") async {
        await APIClient.shared.publishMoment(content: content, images: images,
                                             videoUrl: videoUrl, duration: duration, cover: cover)
        await loadMoments()
    }

    func likeMoment(_ moment: Moment) async {
        await APIClient.shared.likeMoment(id: moment.id)
        await loadMoments()
    }

    func commentMoment(_ moment: Moment, content: String) async {
        await APIClient.shared.commentMoment(id: moment.id, content: content)
        await loadMoments()
    }

    func recall(convType: String, id: Int64) async throws {
        _ = try await APIClient.shared.recall(id: id, convType: convType)
    }

    func updateProfile(nickname: String, bio: String) async {
        await APIClient.shared.updateProfile(nickname: nickname, bio: bio)
        if let me = try? await APIClient.shared.me() {
            user = me
            SessionStore.shared.user = me
        }
    }

    private func startSocket() {
        guard !wsStarted else { return }
        wsStarted = true
        ws.onMessage = { [weak self] text in
            guard let self else { return }
            Task { @MainActor in self.handleSocket(text) }
        }
        ws.onState = { _ in }
        ws.start()
    }

    private func handleSocket(_ text: String) {
        guard
            let raw = text.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
            let type = object["type"] as? String
        else { return }

        let payload = object["data"] as? [String: Any] ?? [:]

        func i64(_ key: String) -> Int64 {
            if let n = payload[key] as? NSNumber { return n.int64Value }
            if let s = payload[key] as? String { return Int64(s) ?? 0 }
            return 0
        }
        func str(_ key: String) -> String {
            if let s = payload[key] as? String { return s }
            if let n = payload[key] as? NSNumber { return n.stringValue }
            return ""
        }

        if type == "message" {
            guard
                let payloadData = try? JSONSerialization.data(withJSONObject: payload),
                let message = try? JSONDecoder().decode(Message.self, from: payloadData)
            else { return }
            inbox.send(message)
            /* 本地通知兜底：不是自己发的、会话未免打扰时提醒；消息本身照常入库 */
            if message.fromUid != (user?.id ?? 0), message.recalled != 1 {
                if !isConvMuted(convType: message.convType, convId: message.convId) {
                    LocalNotifier.shared.post(
                        convType: message.convType,
                        convId: message.convId,
                        sender: message.fromName ?? "新消息",
                        body: LocalNotifier.digest(message)
                    )
                }
            }
            Task { await refreshConversations() }
            return
        }

        let eventConvType = str("conv_type").isEmpty
            ? ((type.hasPrefix("group") || type == "redpacket_grab") ? "group" : "private")
            : str("conv_type")
        var convId = i64("conv_id")
        if convId == 0 && (type == "group_top" || type == "group_notice") { convId = i64("gid") }
        if convId == 0 && (type == "group_read" || type == "redpacket_grab") { convId = i64("group_id") }
        /* 红包领取事件带的是 msg_id，不是 id：映射后聊天页才能按消息精确刷新卡片 */
        var msgId = i64("id")
        if msgId == 0 { msgId = i64("msg_id") }

        if type == "call" {
            let status = Int(i64("status"))
            if status == 0, CallManager.shared.phase == .idle || CallManager.shared.phase == .ended {
                incomingCall = IncomingCall(
                    id: i64("call_id"),
                    callerId: i64("caller_id"),
                    name: str("caller_name"),
                    avatar: str("caller_avatar").isEmpty ? nil : str("caller_avatar"),
                    callType: Int(i64("call_type"))
                )
            } else if status >= 2 {
                incomingCall = nil
            }
        }

        events.send(ChatEvent(
            kind: type,
            convType: eventConvType,
            convId: convId,
            msgId: msgId,
            text: str("text"),
            fromUid: i64("from_uid"),
            name: str("from_name"),
            atUids: str("at_uids")
        ))

        if type != "typing" {
            Task { await refreshConversations() }
        }
    }
}

/// WS 事件：撤回 / 已读 / 正在输入 / 置顶 / 公告 / 删除 / 朋友圈
struct ChatEvent: Equatable {
    var kind: String
    var convType: String
    var convId: Int64
    var msgId: Int64
    var text: String
    var fromUid: Int64
    var name: String
    var atUids: String
}
