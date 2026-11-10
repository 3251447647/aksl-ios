import Foundation
import Combine
import CoreFoundation

/// 扩展连接 LiveKit 所需的凭证（由主 App 写入 App Group）。
///
/// 扩展使用独立 identity（<主播 uid>_bc），和主 App 的麦克风/摄像头连接并存，
/// 避免 LiveKit 因 identity 相同把主 App 踢下线。
struct BroadcastSessionConfig: Codable, Equatable {
    let url: String
    let token: String
    let room: String
    let identity: String
}

/// 主 App 与屏幕共享扩展共享的配置。
///
/// 扩展负责采集画面与系统播放声音并直接发布到 LiveKit；主 App 负责发布
/// 主播麦克风轨。这里记录「是否在共享中」与扩展连接凭证，App 被杀后重新
/// 进入直播间时也能清理残留的系统广播。
enum BroadcastBridge {
    static let appGroupID = "group.com.yixin.chat.ios"
    static let extensionBundleID = "com.yixin.chat.ios.broadcast"

    private static let activeKey = "ak.broadcast.active"
    private static let startedAtKey = "ak.broadcast.started_at"
    private static let sessionKey = "ak.broadcast.session"
    private static let extensionMicKey = "ak.broadcast.extension_mic"

    private static let defaults = UserDefaults(suiteName: appGroupID)

    /// 没有 App Group entitlement 时 containerURL 为 nil；UserDefaults(suiteName:) 仍会返回对象，不能作为判据。
    static var appGroupAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil
    }

    static var isFlaggedActive: Bool {
        guard appGroupAvailable else { return false }
        defaults?.synchronize()
        guard defaults?.bool(forKey: activeKey) == true else { return false }
        let started = defaults?.double(forKey: startedAtKey) ?? 0
        return Date().timeIntervalSince1970 - started < 24 * 3600
    }

    static func markStarted() {
        defaults?.set(true, forKey: activeKey)
        defaults?.set(Date().timeIntervalSince1970, forKey: startedAtKey)
        defaults?.synchronize()
    }

    static func markStopped() {
        defaults?.set(false, forKey: activeKey)
        defaults?.set(0, forKey: startedAtKey)
        defaults?.synchronize()
    }

    /// 写入扩展连接凭证；App Group 不可用或写不进去时返回 false，调用方应退回 App 内共享。
    @discardableResult
    static func saveSession(_ config: BroadcastSessionConfig) -> Bool {
        guard appGroupAvailable, let data = try? JSONEncoder().encode(config) else { return false }
        defaults?.set(data, forKey: sessionKey)
        defaults?.synchronize()
        return defaults?.data(forKey: sessionKey) != nil
    }

    static var session: BroadcastSessionConfig? {
        guard appGroupAvailable, let data = defaults?.data(forKey: sessionKey) else { return nil }
        return try? JSONDecoder().decode(BroadcastSessionConfig.self, from: data)
    }

    static func clearSession() {
        defaults?.removeObject(forKey: sessionKey)
        defaults?.synchronize()
    }

    /// 扩展是否接管麦克风：默认 false，麦克风由主 App 的独立音轨发布；
    /// 只有主 App 明确无法发布麦克风时才打开，避免双麦回声。
    static var extensionMicEnabled: Bool {
        get { appGroupAvailable && defaults?.bool(forKey: extensionMicKey) == true }
        set {
            defaults?.set(newValue, forKey: extensionMicKey)
            defaults?.synchronize()
        }
    }
}

/// 主 App 与扩展之间的控制通知。
///
/// 不能用 LiveKit BroadcastManager 的全局 "iOS_BroadcastRequestStop"：
/// Darwin 通知是整机共享的，别的 LiveKit 应用停止广播会把本应用的扩展一起停掉。
/// 这里用带包名前缀的自定义名字，开始/结束也走自己的通知，避免影响其他应用。
enum BroadcastControl {
    static let startedNotification = "com.yixin.chat.ios.broadcast.started"
    static let stoppedNotification = "com.yixin.chat.ios.broadcast.stopped"
    static let stopNotification = "com.yixin.chat.ios.broadcast.stop"

    static func postStarted() { post(startedNotification) }
    static func postStopped() { post(stoppedNotification) }
    static func requestStop() { post(stopNotification) }

    private static func post(_ name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString),
            nil,
            nil,
            true
        )
    }
}

/// 把自定义 Darwin 通知转成 Combine 信号，供 SwiftUI 订阅。
/// 只监听本应用包名前缀的通知，不会把别的 LiveKit 应用的广播当成自己的。
final class BroadcastStateCenter {
    static let shared = BroadcastStateCenter()

    let started = PassthroughSubject<Void, Never>()
    let stopped = PassthroughSubject<Void, Never>()

    private init() {
        addObserver(BroadcastControl.startedNotification)
        addObserver(BroadcastControl.stoppedNotification)
    }

    private func addObserver(_ name: String) {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, notificationName, _, _ in
                guard let observer, let notificationName else { return }
                let center = Unmanaged<BroadcastStateCenter>.fromOpaque(observer).takeUnretainedValue()
                let key = notificationName.rawValue as String
                DispatchQueue.main.async {
                    if key == BroadcastControl.startedNotification {
                        center.started.send(())
                    } else if key == BroadcastControl.stoppedNotification {
                        center.stopped.send(())
                    }
                }
            },
            name as CFString,
            nil,
            .deliverImmediately
        )
    }
}

/// 主 App 侧判断系统广播这条路能不能用。
/// 签名缺少 App Groups、或 IPA 里没有嵌入扩展时都退回 App 内共享。
enum ScreenBroadcastSupport {
    static var appGroupAvailable: Bool {
        BroadcastBridge.appGroupAvailable
    }

    static var extensionInstalled: Bool {
        guard let pluginsURL = Bundle.main.builtInPlugInsURL else { return false }
        let url = pluginsURL.appendingPathComponent("AKChatBroadcast.appex")
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        return Bundle(url: url)?.bundleIdentifier == BroadcastBridge.extensionBundleID
    }

    static var isAvailable: Bool {
        appGroupAvailable && extensionInstalled
    }
}
