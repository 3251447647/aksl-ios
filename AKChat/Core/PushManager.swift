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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
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
        [.banner, .sound, .badge, .list]
    }
}

final class PushManager {
    static let shared = PushManager()
    private let key = "ak.apns_token"

    var lastError: String?

    var token: String? {
        UserDefaults.standard.string(forKey: key)
    }

    func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: key)
        // 服务端 APNs 接口就绪后在此上报；当前先本地保存，避免无效请求。
    }
}
