import Foundation
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 全局去掉 iOS 系统导航栏返回按钮的「Back」文字，只保留「<」箭头（与安卓一致）
        UINavigationBar.appearance().backIndicatorImage = UIImage(systemName: "chevron.left")
        UINavigationBar.appearance().backIndicatorTransitionMaskImage = UIImage(systemName: "chevron.left")
        UIBarButtonItem.appearance().setBackButtonTitlePositionAdjustment(
            UIOffset(horizontal: -200, vertical: 0), for: .default
        )
        UITableView.appearance().sectionHeaderTopPadding = 0
        // 图片/接口缓存：减少重复下载，明显加快列表与朋友圈图片加载
        URLCache.shared = URLCache(memoryCapacity: 64 * 1024 * 1024,
                                   diskCapacity: 512 * 1024 * 1024)
        UNUserNotificationCenter.current().delegate = self
        /* 通知授权不再在冷启动时直接弹窗：改为首屏延迟 1 秒请求，调用点在 App 根部 .task
           （PushManager.requestAuthorizationIfNeeded）；这里只负责装上 delegate */
        CrashReporter.install()
        /* 上次崩溃留下的堆栈：已登录则后台静默上报，失败不影响启动 */
        CrashReporter.reportPendingIfNeeded()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        PushManager.shared.saveToken(token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushManager.shared.lastError = error.localizedDescription
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        /* 设置页开关同样约束前台展示：关了接收就完全不弹，关了声音只留横幅 */
        guard LocalNotifier.setting("ak.notify.master") else { return [] }
        var options: UNNotificationPresentationOptions = [.banner, .badge, .list]
        if LocalNotifier.setting("ak.notify.sound") { options.insert(.sound) }
        return options
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        PushManager.shared.handle(response: response)
        completionHandler()
    }
}

final class PushManager {
    static let shared = PushManager()
    private let key = "ak.apns_token"
    /// 每次启动只请求一次授权：首屏 task 可能因视图重建多次触发，靠它拦住重复弹窗
    private var authorizationRequested = false

    var lastError: String?

    var token: String? {
        UserDefaults.standard.string(forKey: key)
    }

    func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: key)
        // 服务端 APNs 接口就绪后在此上报；当前先本地保存，避免无效请求。
    }

    /// 点击通知：把目标会话交给 LocalNotifier 的 pending 字段，MainTabView 负责切 tab 并打开
    func handle(response: UNNotificationResponse) {
        let info = response.notification.request.content.userInfo
        guard let convType = info["conv_type"] as? String, !convType.isEmpty,
              let convId = Self.int64(info["conv_id"]), convId > 0
        else { return }
        let convKey = (info["conv_key"] as? String) ?? "\(convType)-\(convId)"
        Task { @MainActor in
            /* 未登录时停在登录页，不排队会话，避免登录后被旧通知带走 */
            guard SessionStore.shared.isLoggedIn else { return }
            let notifier = LocalNotifier.shared
            notifier.pendingConvType = convType
            notifier.pendingConvId = convId
            notifier.pendingKey = convKey
            /* 冷启动时观察者可能还没建好，pending 字段会留给 MainTabView.onAppear 兜底 */
            NotificationCenter.default.post(name: .akOpenConversation, object: nil)
        }
    }

    /// 远程推送的 userInfo 里 id 可能是数字也可能是字符串
    private static func int64(_ raw: Any?) -> Int64? {
        if let n = raw as? NSNumber { return n.int64Value }
        if let s = raw as? String { return Int64(s) }
        return nil
    }

    /// 首屏延迟请求通知权限（从 didFinishLaunching 移出，冷启动不再一进 App 就盖系统弹窗）：
    /// - 从未决定过：延迟 delay 秒后弹系统授权；
    /// - 已授权（含 provisional / ephemeral）：直接注册远程通知，拿到 deviceToken；
    /// - 已拒绝：不打扰用户，开关在系统设置里。
    func requestAuthorizationIfNeeded(delay: TimeInterval = 1.0) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.authorizationRequested else { return }
            self.authorizationRequested = true
            let center = UNUserNotificationCenter.current()
            center.getNotificationSettings { settings in
                switch settings.authorizationStatus {
                case .notDetermined:
                    DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay)) {
                        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                            guard granted else { return }
                            DispatchQueue.main.async {
                                UIApplication.shared.registerForRemoteNotifications()
                            }
                        }
                    }
                case .authorized, .provisional, .ephemeral:
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                default:
                    break
                }
            }
        }
    }
}
