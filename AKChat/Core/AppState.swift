import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var user: User?
    @Published var conversations: [Conversation] = []
    @Published var contacts: ContactsData?
    @Published var friendRequests: [FriendRequest] = []
    @Published var moments: [Moment] = []
    @Published var momentCover: String = ""
    @Published var emojis: [EmojiItem] = []
    @Published var incoming: Message?
    @Published var chatEvent: ChatEvent?
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
        SessionStore.shared.clear()
        user = nil
        conversations = []
        contacts = nil
        isLoggedIn = false
    }

    func refreshConversations() async {
        do {
            let data = try await api.conversations()
            conversations = data.list
            unreadTotal = data.unreadTotal
        } catch {
            errorText = error.localizedDescription
        }
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
        await refreshConversations()
        return data.message
    }

    func loadHistory(convType: String, convId: Int64, beforeId: Int64 = 0) async throws -> [Message] {
        let data = try await api.history(convType: convType, convId: convId, beforeId: beforeId)
        return data.list
    }

    func markRead(convType: String, convId: Int64, lastId: Int64) async {
        guard lastId > 0 else { return }
        _ = try? await api.read(convType: convType, convId: convId, lastId: lastId)
        await refreshConversations()
    }

    func togglePin(_ conv: Conversation) async {
        await api.convSet(convType: conv.convType, convId: conv.convId, key: "top", value: conv.isTop == 1 ? 0 : 1)
        await refreshConversations()
    }

    func toggleMute(_ conv: Conversation) async {
        await api.convSet(convType: conv.convType, convId: conv.convId, key: "mute", value: conv.isMute == 1 ? 0 : 1)
        await refreshConversations()
    }

    func deleteConversation(_ conv: Conversation) async {
        await api.convDelete(convType: conv.convType, convId: conv.convId)
        await refreshConversations()
    }

    func clearConversation(_ conv: Conversation) async {
        await APIClient.shared.clearConversation(convType: conv.convType, convId: conv.convId)
        await refreshConversations()
    }

    /// 一键已读（首页加号菜单）
    func markAllRead() async {
        await api.readAll()
        await refreshConversations()
    }

    func uploadImage(_ data: Data) async throws -> UploadData {
        try await APIClient.shared.upload(data: data, filename: "ios_\(Int(Date().timeIntervalSince1970)).jpg", kind: "chat")
    }

    func sendImage(convType: String, convId: Int64, url: String) async throws -> Message {
        let clientId = "ios_" + UUID().uuidString
        let data = try await APIClient.shared.sendImage(convType: convType, convId: convId, url: url, clientId: clientId)
        await refreshConversations()
        return data.message
    }

    func uploadVoice(fileURL: URL) async throws -> UploadData {
        let data = try Data(contentsOf: fileURL)
        return try await APIClient.shared.upload(data: data, filename: fileURL.lastPathComponent, kind: "voice")
    }

    func sendVoice(convType: String, convId: Int64, url: String, seconds: Int) async throws -> Message {
        let clientId = "ios_" + UUID().uuidString
        let data = try await APIClient.shared.sendVoice(convType: convType, convId: convId, url: url, seconds: seconds, clientId: clientId)
        await refreshConversations()
        return data.message
    }

    func sendSticker(convType: String, convId: Int64, url: String) async throws -> Message {
        let clientId = "sticker_" + UUID().uuidString
        let data = try await APIClient.shared.sendImage(convType: convType, convId: convId, url: url, clientId: clientId)
        await refreshConversations()
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
            incoming = message
            Task { await refreshConversations() }
            return
        }

        let eventConvType = str("conv_type").isEmpty ? (type.hasPrefix("group") ? "group" : "private") : str("conv_type")
        var convId = i64("conv_id")
        if convId == 0 && type == "group_top" { convId = i64("gid") }
        if convId == 0 && type == "group_read" { convId = i64("group_id") }

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

        chatEvent = ChatEvent(
            kind: type,
            convType: eventConvType,
            convId: convId,
            msgId: i64("id"),
            text: str("text"),
            fromUid: i64("from_uid"),
            name: str("from_name"),
            atUids: str("at_uids")
        )

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
