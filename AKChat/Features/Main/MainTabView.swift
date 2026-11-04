import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var app: AppState
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("聊天", systemImage: "bubble.left.and.bubble.right") }
                .badge(app.unreadTotal > 0 ? app.unreadTotal : 0)
                .tag(0)

            ContactsView()
                .tabItem { Label("通讯录", systemImage: "person.2") }
                .tag(1)

            MomentsView()
                .tabItem { Label("广场", systemImage: "safari") }
                .tag(2)

            MeView()
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(3)
        }
        .tint(AKColor.brand)
    }
}
