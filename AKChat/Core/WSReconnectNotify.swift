import Foundation

extension Notification.Name {
    /// WS 重新连上：聊天页立刻补拉当前会话，不必等下一次 5 秒轮询。
    static let akWsReconnected = Notification.Name("ak.ws.reconnected")
}
