import SwiftUI

/// 底部导航：与安卓一致的自绘 4 tab（图标 25 + 文字 10.5，选中品牌绿，
/// 聊天 tab 右上红色未读圆）；页面常驻以保留各页滚动位置，而不是切一次重建。
struct MainTabView: View {
    @EnvironmentObject private var app: AppState
    @State private var tab = 0

    private let tabs: [(icon: String, title: String)] = [
        ("bubble.left.and.bubble.right.fill", "聊天"),
        ("person.2.fill", "通讯录"),
        ("safari.fill", "广场"),
        ("person.crop.circle.fill", "我的")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                HomeView().opacity(tab == 0 ? 1 : 0).allowsHitTesting(tab == 0)
                ContactsView().opacity(tab == 1 ? 1 : 0).allowsHitTesting(tab == 1)
                DiscoverView().opacity(tab == 2 ? 1 : 0).allowsHitTesting(tab == 2)
                MeView().opacity(tab == 3 ? 1 : 0).allowsHitTesting(tab == 3)
            }
            .padding(.bottom, 54)

            tabBar
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(item: $app.incomingCall) { call in
            CallScreen(incoming: call)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { idx, item in
                Button {
                    tab = idx
                } label: {
                    VStack(spacing: 2) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: item.icon)
                                .font(.system(size: 21))
                                .frame(width: 26, height: 24)
                            if idx == 0 && app.unreadTotal > 0 {
                                Text(app.unreadTotal > 99 ? "99+" : "\(app.unreadTotal)")
                                    .font(.system(size: 8.5, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 15, minHeight: 15)
                                    .background(AKColor.red)
                                    .clipShape(Capsule())
                                    .offset(x: 9, y: -5)
                            }
                        }
                        Text(item.title)
                            .font(.system(size: 10.5))
                    }
                    .foregroundColor(tab == idx ? AKColor.brand : AKColor.muted)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 7)
        .padding(.bottom, 2)
        .background(
            AKColor.card
                .overlay(alignment: .top) {
                    Rectangle().fill(AKColor.line).frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
