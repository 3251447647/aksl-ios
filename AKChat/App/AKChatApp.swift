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

    var body: some View {
        Group {
            if app.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: app.isLoggedIn)
        .updateGate()
    }
}
