import Foundation
import UserNotifications
import UIKit
import AudioToolbox

/// 本地通知兜底：未接入 APNs 时，App 运行中收到新消息用本地通知提醒
final class LocalNotifier {
    static let shared = LocalNotifier()

    /// 与设置页 @AppStorage 共用的键
    private enum Keys {
        static let master = "ak.notify.master"
        static let sound = "ak.notify.sound"
        static let vibrate = "ak.notify.vibrate"
    }

    /// 当前正在查看的会话，key 形如 "group-990084"
    var activeKey: String?
    /// 点击通知后要打开的会话：PushManager 写入，MainTabView 取走
    var pendingKey: String?
    var pendingConvType: String?
    var pendingConvId: Int64?

    private var lastPost: [String: Date] = [:]

    func key(_ convType: String, _ convId: Int64) -> String { "\(convType)-\(convId)" }

    /// 开关默认开启：键不存在时 UserDefaults.bool 返回 false，不能直接用
    static func setting(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    func post(convType: String, convId: Int64, type: Int, sender: String, body: String) {
        /* 11 是系统提示（入群/撤回/红包领取等）：与安卓一致不弹通知 */
        if type == 11 { return }
        /* 用户关掉「接收新消息通知」：直接不发，开关不能只是摆设 */
        guard Self.setting(Keys.master) else { return }

        let k = key(convType, convId)
        if activeKey == k { return }
        if let t = lastPost[k], Date().timeIntervalSince(t) < 3 { return }
        lastPost[k] = Date()

        let soundOn = Self.setting(Keys.sound)
        let vibrateOn = Self.setting(Keys.vibrate)

        let content = UNMutableNotificationContent()
        content.title = sender
        content.body = body
        /* 关声音时 sound 传 nil 即静音；iOS 本地通知没有「只震动」参数，
           所以无声但开了震动时在进程内补一次系统震动（有声音时交给系统，仅静音模式下震） */
        content.sound = soundOn ? .default : nil
        if !soundOn && vibrateOn {
            DispatchQueue.main.async {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
        content.userInfo = ["conv_type": convType, "conv_id": convId, "conv_key": k]
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    /// 消息摘要，与安卓通知文案保持一致
    static func digest(_ m: Message) -> String {
        switch m.type {
        case 2, 3, 20: return "[系统]"
        case 5: return "[图片]"
        case 6: return "[语音]"
        case 7, 21: return "[红包]"
        case 8, 22: return "[转账]"
        case 9, 23: return "[礼物]"
        case 10: return "[位置]"
        case 12, 13: return "[名片]"
        case 14: return "[通话]"
        case 15: return "[视频]"
        case 16: return "[动态]"
        case 17: return "[聊天记录]"
        case 18: return "[文件]"
        case 19: return "[直播]"
        case 31: return "[相册]"
        /* 11 是系统消息，post 里已拦截；这里兜底成可读文案，避免出现空串 */
        case 11: return "[系统]"
        case 1:
            let raw = m.text ?? m.content ?? ""
            return raw.isEmpty || raw.hasPrefix("{") ? "[消息]" : raw
        default:
            return "[消息]"
        }
    }
}
