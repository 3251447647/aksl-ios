import SwiftUI
import UIKit
import WebKit

// MARK: - 链接分发

/// 站内/站外链接统一入口：普通网页走 App 内置浏览器，安装包与下载页交给系统浏览器。
enum AppLinkRouter {
    private static let downloadExtensions: Set<String> = [
        "apk", "ipa", "plist", "mobileconfig", "zip", "rar", "7z", "dmg", "pkg", "exe", "msi",
        "doc", "docx", "xls", "xlsx", "ppt", "pptx"
    ]

    static func isWebURL(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        return scheme == "http" || scheme == "https"
    }

    /// 下载管理器只有系统浏览器/Safari 能接管，内嵌 WebView 拿到安装包会白屏
    static func shouldOpenExternally(_ url: URL) -> Bool {
        guard isWebURL(url) else { return true }
        let path = url.path.lowercased()
        if path == "/download" || path.hasPrefix("/download/") || path.hasSuffix("/download") { return true }
        if path == "/dl" || path.hasPrefix("/dl/") || path.hasSuffix("/dl") { return true }
        // 服务端安装包端点：/api/v1/app/dl?code=N（302 到 .apk，不能先塞进 WebView）
        if path.hasPrefix("/api/v1/app/dl") { return true }
        if downloadExtensions.contains(url.pathExtension.lowercased()) { return true }
        // 下载中转页：/download.php?file=xxx.apk 这类安装包不在路径后缀里
        let name = (path as NSString).lastPathComponent
        if name.hasPrefix("download.") || name.hasPrefix("dl.") { return true }
        let query = (url.query ?? "").lowercased()
        return ["apk", "ipa", "plist", "mobileconfig"].contains { query.contains("." + $0) }
    }

    static func open(_ url: URL) {
        if shouldOpenExternally(url) {
            UIApplication.shared.open(url)
        } else {
            InAppBrowserCenter.shared.present(url)
        }
    }
}

// MARK: - 顶层展示

/// 从当前最上层控制器 present，保证从任意 sheet / fullScreenCover 之上也能打开；
/// 关闭后原页面仍在原层级，滚动位置与输入内容不丢。
final class InAppBrowserCenter {
    static let shared = InAppBrowserCenter()

    private var presenting = false

    func present(_ url: URL) {
        guard AppLinkRouter.isWebURL(url) else {
            UIApplication.shared.open(url)
            return
        }
        let work = { [weak self] in
            guard let self, !self.presenting else { return }
            guard let window = Self.keyWindow(),
                  let root = window.rootViewController else { return }
            let top = Self.topViewController(from: root)
            self.presenting = true
            let host = UIHostingController(rootView: InAppBrowserView(url: url))
            host.modalPresentationStyle = .fullScreen
            top.present(host, animated: true) { [weak self] in
                self?.presenting = false
            }
            // 转场冲突时 present 可能不回调，兜底解锁，避免之后再也打不开
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.presenting = false
            }
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    private static func keyWindow() -> UIWindow? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        return windows.first(where: { $0.isKeyWindow }) ?? windows.first
    }

    private static func topViewController(from base: UIViewController) -> UIViewController {
        if let presented = base.presentedViewController {
            return topViewController(from: presented)
        }
        if let nav = base as? UINavigationController, let visible = nav.visibleViewController {
            return topViewController(from: visible)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(from: selected)
        }
        return base
    }
}

// MARK: - 浏览器页面

/// 内置浏览器：自绘头部与地址栏 + WKWebView，支持返回、前进、刷新、分享、
/// 系统浏览器打开、深色模式、进度条、失败重试、target=_blank 与 JS 弹窗。
/// SFSafariViewController 拿不到进度/失败事件，也无法接管 target=_blank 与 JS 弹窗，故用 WKWebView。
struct InAppBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var systemScheme
    @AppStorage("colorSchemeMode") private var schemeMode = 0
    @StateObject private var state: BrowserState

    init(url: URL) {
        _state = StateObject(wrappedValue: BrowserState(url: url))
    }

    private var browserScheme: ColorScheme {
        switch schemeMode {
        case 1: return .light
        case 2: return .dark
        default: return systemScheme
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            progressBar
            addressBar
            ZStack {
                BrowserWebView(state: state, colorScheme: browserScheme)
                if let message = state.errorMessage {
                    errorView(message)
                }
                if let request = state.jsRequest {
                    jsDialog(request)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            bottomBar
        }
        .background(AKColor.bg.ignoresSafeArea())
        .preferredColorScheme(browserScheme)
        .onDisappear { state.cancelPendingJS() }
    }

    // MARK: 头部

    private var header: some View {
        ZStack {
            Text(state.displayTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AKColor.text)
                .lineLimit(1)
                .padding(.horizontal, 112)

            HStack(spacing: 2) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AKColor.text)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)

                Button {
                    state.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(state.canGoBack ? AKColor.text : AKColor.placeholder)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .disabled(!state.canGoBack)

                Spacer(minLength: 0)

                ShareLink(item: state.currentURL) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AKColor.text)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)

                Button {
                    openExternally()
                } label: {
                    Text("浏览器打开")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(AKColor.brand)
                        .padding(.horizontal, 8)
                        .frame(height: 30)
                        .background(AKColor.brandSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 46)
        .background(AKColor.card.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { divider }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(AKColor.line.opacity(0.6))
                Rectangle()
                    .fill(AKColor.brand)
                    .frame(width: proxy.size.width * CGFloat(max(0, min(1, state.progress))))
            }
        }
        .frame(height: 2)
        .opacity(state.isLoading ? 1 : 0)
        .animation(.easeOut(duration: 0.2), value: state.isLoading)
    }

    private var addressBar: some View {
        HStack(spacing: 6) {
            Image(systemName: state.currentURL.scheme == "https" ? "lock.fill" : "globe")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AKColor.muted)
            Text(state.displayURL)
                .font(.system(size: 12))
                .foregroundColor(AKColor.sub)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(AKColor.fill)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(AKColor.card)
        .overlay(alignment: .bottom) { divider }
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            Button {
                state.goBack()
            } label: {
                navIcon("chevron.left", enabled: state.canGoBack)
            }
            .buttonStyle(.plain)
            .disabled(!state.canGoBack)

            Spacer(minLength: 0)

            Button {
                state.goForward()
            } label: {
                navIcon("chevron.right", enabled: state.canGoForward)
            }
            .buttonStyle(.plain)
            .disabled(!state.canGoForward)

            Spacer(minLength: 0)

            Button {
                if state.isLoading {
                    state.stop()
                } else {
                    state.reload()
                }
            } label: {
                navIcon(state.isLoading ? "xmark" : "arrow.clockwise", enabled: true)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .frame(height: 46)
        .background(AKColor.card.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { divider }
    }

    private func navIcon(_ name: String, enabled: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(enabled ? AKColor.text : AKColor.placeholder)
            .frame(width: 44, height: 40)
            .contentShape(Rectangle())
    }

    private var divider: some View {
        Rectangle().fill(AKColor.line).frame(height: 0.5)
    }

    // MARK: 失败 / JS 弹窗

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 38))
                .foregroundColor(AKColor.muted)
            Text("网页加载失败")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AKColor.text)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(AKColor.sub)
                .multilineTextAlignment(.center)
                .lineLimit(4)
            Text(state.displayURL)
                .font(.system(size: 11))
                .foregroundColor(AKColor.muted)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack(spacing: 10) {
                Button {
                    state.reload()
                } label: {
                    Text("重试")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .frame(height: 40)
                        .background(AKColor.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    openExternally()
                } label: {
                    Text("在浏览器中打开")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AKColor.text)
                        .padding(.horizontal, 18)
                        .frame(height: 40)
                        .background(AKColor.fill)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 18, y: 8)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AKColor.bg.opacity(0.96))
    }

    private func jsDialog(_ request: JSAlertRequest) -> some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                Text(request.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AKColor.text)
                Text(request.message)
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.sub)
                    .fixedSize(horizontal: false, vertical: true)
                if request.kind == .prompt {
                    TextField("请输入", text: $state.jsText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(.horizontal, 10)
                        .frame(height: 38)
                        .background(AKColor.fill)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                HStack(spacing: 10) {
                    if request.kind != .alert {
                        dialogButton("取消", primary: false) {
                            state.resolveJS(false)
                        }
                    }
                    dialogButton("确定", primary: true) {
                        state.resolveJS(true)
                    }
                }
                .padding(.top, 2)
            }
            .padding(18)
            .frame(maxWidth: 300)
            .background(AKColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.16), radius: 20, y: 8)
            .padding(.horizontal, 32)
        }
    }

    private func dialogButton(_ title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(primary ? .white : AKColor.text)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(primary ? AKColor.brand : AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func openExternally() {
        let target = state.currentURL
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIApplication.shared.open(target)
        }
    }
}

// MARK: - 状态与 WebView

private final class BrowserState: ObservableObject {
    let initialURL: URL
    @Published var currentURL: URL
    @Published var title = ""
    @Published var progress: Double = 0
    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var errorMessage: String?
    @Published var jsRequest: JSAlertRequest?
    @Published var jsText = ""
    weak var webView: WKWebView?

    init(url: URL) {
        initialURL = url
        currentURL = url
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return currentURL.host ?? "网页"
    }

    var displayURL: String {
        var text = currentURL.host ?? currentURL.absoluteString
        if let port = currentURL.port {
            text += ":\(port)"
        }
        let path = currentURL.path
        if !path.isEmpty && path != "/" {
            text += path
        }
        if let query = currentURL.query, !query.isEmpty {
            text += "?" + query
        }
        return text
    }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func stop() { webView?.stopLoading() }

    func reload() {
        errorMessage = nil
        guard let webView else { return }
        if webView.url == nil {
            webView.load(URLRequest(url: currentURL))
        } else {
            webView.reload()
        }
    }

    func presentJS(kind: JSAlertRequest.Kind, title: String, message: String, defaultValue: String,
                   completion: @escaping (Bool, String?) -> Void) {
        jsText = defaultValue
        jsRequest = JSAlertRequest(kind: kind, title: title, message: message, completion: completion)
    }

    func resolveJS(_ ok: Bool) {
        guard let request = jsRequest else { return }
        jsRequest = nil
        request.completion(ok, request.kind == .prompt ? jsText : nil)
    }

    func cancelPendingJS() {
        guard jsRequest != nil else { return }
        resolveJS(false)
    }

    func sync(_ webView: WKWebView) {
        if let url = webView.url {
            currentURL = url
        }
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }
}

private struct JSAlertRequest: Identifiable {
    enum Kind: Equatable {
        case alert
        case confirm
        case prompt
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let message: String
    let completion: (Bool, String?) -> Void
}

private enum BrowserInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

private struct BrowserWebView: UIViewRepresentable {
    @ObservedObject var state: BrowserState
    let colorScheme: ColorScheme

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // 默认持久化数据仓：所有内置浏览器共享 Cookie / 登录态
        configuration.websiteDataStore = .default()
        configuration.applicationNameForUserAgent = "AKChatiOS/\(BrowserInfo.version)"
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        state.webView = webView
        context.coordinator.observe(webView)
        webView.load(URLRequest(url: state.initialURL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let style: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        if webView.overrideUserInterfaceStyle != style {
            webView.overrideUserInterfaceStyle = style
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let state: BrowserState
        private var observations: [NSKeyValueObservation] = []

        init(state: BrowserState) {
            self.state = state
        }

        deinit {
            observations.forEach { $0.invalidate() }
        }

        func observe(_ webView: WKWebView) {
            observations.append(webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                let value = webView.estimatedProgress
                self?.publish { $0.progress = value }
            })
            observations.append(webView.observe(\.title, options: [.new]) { [weak self] webView, _ in
                let value = webView.title ?? ""
                self?.publish { $0.title = value }
            })
            observations.append(webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
                guard let url = webView.url else { return }
                self?.publish { $0.currentURL = url }
            })
            observations.append(webView.observe(\.canGoBack, options: [.new]) { [weak self] webView, _ in
                let value = webView.canGoBack
                self?.publish { $0.canGoBack = value }
            })
            observations.append(webView.observe(\.canGoForward, options: [.new]) { [weak self] webView, _ in
                let value = webView.canGoForward
                self?.publish { $0.canGoForward = value }
            })
            observations.append(webView.observe(\.isLoading, options: [.new]) { [weak self] webView, _ in
                let value = webView.isLoading
                self?.publish { $0.isLoading = value }
            })
        }

        /// WebKit 的 KVO 回调不保证在主线程，统一切回主线程再发 @Published
        private func publish(_ change: @escaping (BrowserState) -> Void) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                change(self.state)
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            state.errorMessage = nil
            state.isLoading = true
            state.progress = 0.05
            state.sync(webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            state.isLoading = false
            state.progress = 1
            state.errorMessage = nil
            state.sync(webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handle(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handle(error)
        }

        private func handle(_ error: Error) {
            let ns = error as NSError
            if ns.code == NSURLErrorCancelled { return }
            state.isLoading = false
            state.progress = 1
            state.errorMessage = ns.localizedDescription
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            let scheme = url.scheme?.lowercased() ?? ""
            if scheme == "http" || scheme == "https" {
                if AppLinkRouter.shouldOpenExternally(url) {
                    decisionHandler(.cancel)
                    UIApplication.shared.open(url)
                    return
                }
                if url.host?.isEmpty == false {
                    state.currentURL = url
                }
                decisionHandler(.allow)
                return
            }
            if scheme == "about" || scheme == "data" || scheme == "blob" {
                decisionHandler(.allow)
                return
            }
            decisionHandler(.cancel)
            UIApplication.shared.open(url)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if !navigationResponse.canShowMIMEType, let url = navigationResponse.response.url {
                decisionHandler(.cancel)
                UIApplication.shared.open(url)
                return
            }
            decisionHandler(.allow)
        }

        /// target=_blank：不新开看不到的窗口，直接在当前浏览器里加载
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            guard let url = navigationAction.request.url else { return nil }
            let scheme = url.scheme?.lowercased() ?? ""
            if scheme == "http" || scheme == "https" {
                if AppLinkRouter.shouldOpenExternally(url) {
                    UIApplication.shared.open(url)
                } else {
                    webView.load(navigationAction.request)
                }
            } else if scheme == "about" || scheme == "data" || scheme == "blob" {
                webView.load(navigationAction.request)
            } else {
                UIApplication.shared.open(url)
            }
            return nil
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            state.presentJS(kind: .alert, title: dialogTitle(webView), message: message, defaultValue: "") { _, _ in
                completionHandler()
            }
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            state.presentJS(kind: .confirm, title: dialogTitle(webView), message: message, defaultValue: "") { ok, _ in
                completionHandler(ok)
            }
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                     defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (String?) -> Void) {
            state.presentJS(kind: .prompt, title: dialogTitle(webView), message: prompt,
                            defaultValue: defaultText ?? "") { ok, text in
                completionHandler(ok ? text : nil)
            }
        }

        private func dialogTitle(_ webView: WKWebView) -> String {
            (webView.url?.host ?? "此网页") + " 提示"
        }
    }
}
