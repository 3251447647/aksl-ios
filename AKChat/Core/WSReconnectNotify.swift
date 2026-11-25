import Foundation

extension Notification.Name {
    /// WS 重新连上：聊天页立刻补拉当前会话，不必等下一次 5 秒轮询。
    static let akWsReconnected = Notification.Name("ak.ws.reconnected")
    /// 点击通知：主界面把 LocalNotifier 里待打开的会话切出来。
    static let akOpenConversation = Notification.Name("ak.open.conversation")
}
