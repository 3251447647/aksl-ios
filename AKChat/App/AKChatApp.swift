import SwiftUI

@main
struct AKChatApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .task {
                    CallKitManager.shared.setup()
                    await app.bootstrap()
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var app: AppState
    /// 0 跟随系统 / 1 浅色 / 2 深色（对齐安卓设置里的深色模式开关）
    @AppStorage("colorSchemeMode") private var schemeMode = 0

    private var preferred: ColorScheme? {
        switch schemeMode {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    var body: some View {
        Group {
            if app.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: app.isLoggedIn)
        .preferredColorScheme(preferred)
    }
}
