import Foundation
import UserNotifications
import UIKit

/// 本地通知兜底：未接入 APNs 时，App 运行中收到新消息用本地通知提醒
final class LocalNotifier {
    static let shared = LocalNotifier()

    /// 当前正在查看的会话，key 形如 "group-990084"
    var activeKey: String?
    /// 点击通知后要打开的会话
    var pendingKey: String?
    var pendingConvType: String?
    var pendingConvId: Int64?

    private var lastPost: [String: Date] = [:]

    func key(_ convType: String, _ convId: Int64) -> String { "\(convType)-\(convId)" }

    func post(convType: String, convId: Int64, sender: String, body: String) {
        let k = key(convType, convId)
        if activeKey == k { return }
        if let t = lastPost[k], Date().timeIntervalSince(t) < 3 { return }
        lastPost[k] = Date()

        let content = UNMutableNotificationContent()
        content.title = sender
        content.body = body
        content.sound = .default
        content.userInfo = ["conv_type": convType, "conv_id": convId]
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    /// 消息摘要，与安卓通知文案保持一致
    static func digest(_ m: Message) -> String {
        switch m.type {
        case 2, 3, 20: return "[充值]"
        case 7, 21: return "[红包]"
        case 8, 22: return "[转账]"
        case 9, 23: return "[礼物]"
        case 4: return "[图片]"
        case 5: return "[语音]"
        case 6: return "[视频]"
        case 10: return "[位置]"
        case 12: return "[个人名片]"
        case 13: return "[群名片]"
        case 15: return "[聊天记录]"
        case 19: return "[直播]"
        default: break
        }
        let raw = m.text ?? m.content ?? ""
        return raw.isEmpty ? "[消息]" : raw
    }
}
