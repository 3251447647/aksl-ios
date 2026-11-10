import SwiftUI
import QuartzCore

private struct TabIsActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// 当前页面所属 tab 是否在屏上：页面常驻，隐藏时据此暂停轮询与重复刷新
    var tabIsActive: Bool {
        get { self[TabIsActiveKey.self] }
        set { self[TabIsActiveKey.self] = newValue }
    }
}

/// 二级页占满全屏时要盖住自绘 tab 栏。页面用 reportsDetailPage() 上报；
/// 用深度计数而非布尔，多层 push（群聊 → 群资料 → 设置）逐层返回时才不会提前恢复。
final class TabBarVisibility: ObservableObject {
    @Published private(set) var depth = 0
    private var pages = Set<UUID>()

    func enter(_ page: UUID) {
        guard pages.insert(page).inserted else { return }
        depth = pages.count
    }

    func leave(_ page: UUID) {
        guard pages.remove(page) != nil else { return }
        depth = pages.count
    }
}

private struct TabBarVisibilityKey: EnvironmentKey {
    static let defaultValue = TabBarVisibility()
}

extension EnvironmentValues {
    var tabBarVisibility: TabBarVisibility {
        get { self[TabBarVisibilityKey.self] }
        set { self[TabBarVisibilityKey.self] = newValue }
    }
}

private struct DetailPageReporter: ViewModifier {
    @Environment(\.tabBarVisibility) private var tabBar
    @State private var page = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear {
                withAnimation(.easeInOut(duration: 0.18)) { tabBar.enter(page) }
            }
            .onDisappear {
                withAnimation(.easeInOut(duration: 0.18)) { tabBar.leave(page) }
            }
    }
}

extension View {
    /// 标记当前视图是二级页：出现时隐藏主界面底部 tab 栏，返回后恢复
    func reportsDetailPage() -> some View {
        modifier(DetailPageReporter())
    }

    /// 恢复系统侧滑返回手势
    func restoresSwipeBack() -> some View {
        background(SwipeBackGestureEnabler())
    }
}

/// 二级页普遍自绘头部并隐藏系统导航栏，SwiftUI 会连带关掉 interactivePopGestureRecognizer，
/// 导致 push 后没有系统右滑返回；这里接管代理，仅在非根页面、非转场中放行。
/// 代理用单例常驻：手势代理是弱引用，一旦变回 nil，根页面右滑会触发没有目标页的 pop。
private final class SwipeBackDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = SwipeBackDelegate()

    func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        guard let nav = navigationController(of: gesture.view) else { return false }
        return nav.viewControllers.count > 1 && nav.transitionCoordinator == nil
    }

    private func navigationController(of view: UIView?) -> UINavigationController? {
        var current = view
        while let v = current {
            if let nav = v.next as? UINavigationController { return nav }
            if let vc = v.next as? UIViewController { return vc.navigationController }
            current = v.superview
        }
        return nil
    }
}

private struct SwipeBackGestureEnabler: UIViewControllerRepresentable {
    final class Installer: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let gesture = navigationController?.interactivePopGestureRecognizer else { return }
            gesture.delegate = SwipeBackDelegate.shared
            gesture.isEnabled = true
        }
    }

    func makeUIViewController(context: Context) -> Installer {
        let vc = Installer()
        vc.view.backgroundColor = .clear
        vc.view.isUserInteractionEnabled = false
        return vc
    }

    func updateUIViewController(_ vc: Installer, context: Context) {}
}

/// 底部导航：与安卓一致的自绘 4 tab（图标 25 + 文字 10.5，选中品牌绿，
/// 聊天 tab 右上红色未读圆）；页面常驻以保留各页滚动位置，而不是切一次重建。
struct MainTabView: View {
    @EnvironmentObject private var app: AppState
    @State private var tab = 0
    /// 点开过的 tab：页面一旦挂载就常驻（保留各页滚动位置），没点开过的先不建，
    /// 避免启动时一次性铺满四个全屏页面
    @State private var mounted: Set<Int> = [0]
    @AppStorage("floatingBubble") private var bubbleOn = false
    @State private var bubbleChat: BubbleChat?
    @StateObject private var tabVisibility = TabBarVisibility()

    /// 有二级页在屏上时整条 tab 栏让位给页面
    private var showTabBar: Bool { tabVisibility.depth == 0 }

    private let tabs: [(icon: String, title: String)] = [
        ("bubble.left.and.bubble.right.fill", "聊天"),
        ("person.2.fill", "通讯录"),
        ("safari.fill", "广场"),
        ("person.crop.circle.fill", "我的")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                if mounted.contains(0) { tabPage(0) { HomeView() } }
                if mounted.contains(1) { tabPage(1) { ContactsView() } }
                if mounted.contains(2) { tabPage(2) { DiscoverView() } }
                if mounted.contains(3) { tabPage(3) { MeView() } }
            }
            .padding(.bottom, showTabBar ? 54 : 0)

            if bubbleOn && showTabBar {
                FloatingBubble {
                    if let conv = app.conversations.first {
                        bubbleChat = BubbleChat(convType: conv.convType, convId: conv.convId, title: conv.name ?? "聊天")
                    } else {
                        select(0)
                    }
                }
            }

            if showTabBar {
                tabBar.transition(.opacity)
            }
        }
        .environment(\.tabBarVisibility, tabVisibility)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(item: $app.incomingCall) { call in
            CallScreen(incoming: call)
        }
        .fullScreenCover(item: $bubbleChat) { c in
            NavigationStack {
                ChatView(convType: c.convType, convId: c.convId, title: c.title)
            }
        }
    }

    @ViewBuilder
    private func tabPage<Content: View>(_ index: Int, @ViewBuilder content: () -> Content) -> some View {
        let active = tab == index
        content()
            .opacity(active ? 1 : 0)
            .allowsHitTesting(active)
            .environment(\.tabIsActive, active)
    }

    /// 切换 tab 并打一帧耗时（DEBUG）：包含本次提交的布局与首帧栅格化
    private func select(_ index: Int) {
        guard index != tab else { return }
        mounted.insert(index)
        let started = AKPerf.start()
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            AKPerf.log("tab.switch", since: started, "-> \(index)")
        }
        tab = index
        CATransaction.commit()
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { idx, item in
                Button {
                    select(idx)
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

struct BubbleChat: Identifiable {
    let id = UUID()
    let convType: String
    let convId: Int64
    let title: String
}
