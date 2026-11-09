import SwiftUI
import UIKit
import UserNotifications

/// 正文字号三档，值存 UserDefaults(ak.fontSize)
enum AKFontSize: String, CaseIterable {
    case small
    case standard
    case large

    var title: String {
        switch self {
        case .small: return "小"
        case .standard: return "标准"
        case .large: return "大"
        }
    }
}

/// 用户协议 / 隐私政策弹层：网站暂无独立正文页，这里给说明与官网入口
private struct AgreementDoc: Identifiable {
    let id = UUID()
    let title: String
}

/// 设置：分组与文案对齐安卓 SettingsScreen / AppSettingsScreens / PrivacyScreen
struct SettingsView: View {
    @EnvironmentObject private var app: AppState

    /// 0 跟随系统 / 1 浅色 / 2 深色
    @AppStorage("colorSchemeMode") private var schemeMode = 0
    @AppStorage("ak.notify.master") private var notifyMaster = true
    @AppStorage("ak.notify.sound") private var sound = true
    @AppStorage("ak.notify.vibrate") private var vibrate = true
    @AppStorage("ak.fontSize") private var fontSizeRaw = AKFontSize.standard.rawValue

    @State private var showEdit = false
    @State private var showLogout = false
    @State private var showDelete = false
    @State private var showTip = false
    @State private var tip = ""
    @State private var cacheText = ""
    @State private var bannerText = "去设置"
    @State private var agreement: AgreementDoc?

    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let themeTitles = ["跟随系统", "浅色", "深色"]
    private let fontSizes = AKFontSize.allCases

    private var fontSize: AKFontSize {
        AKFontSize(rawValue: fontSizeRaw) ?? .standard
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                group("账号与安全") {
                    Button {
                        showEdit = true
                    } label: {
                        row("person.fill", "个人资料", value: "编辑")
                    }
                    .buttonStyle(.plain)
                    divider
                    NavigationLink {
                        PrivacySettingsView()
                    } label: {
                        row("lock.fill", "隐私设置")
                    }
                    .buttonStyle(.plain)
                    divider
                    NavigationLink {
                        ChangePasswordView(type: "login")
                    } label: {
                        row("key.fill", "修改密码")
                    }
                    .buttonStyle(.plain)
                }

                group("消息通知") {
                    switchRow("bell.fill", "新消息通知", isOn: $notifyMaster)
                    divider
                    switchRow("speaker.wave.2.fill", "声音", isOn: $sound)
                    divider
                    switchRow("iphone.radiowaves.left.and.right", "震动", isOn: $vibrate)
                    divider
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        row("bell.and.waves.left.and.right.fill", "横幅", value: bannerText)
                    }
                    .buttonStyle(.plain)
                }
                footnote("横幅需系统允许：新消息到达时在屏幕顶部弹出，不开横幅时仅在通知中心提醒。")

                group("聊天") {
                    HStack(spacing: 12) {
                        iconBox("moon.fill")
                        Text("深色模式")
                            .font(.system(size: 15))
                            .foregroundColor(AKColor.text)
                        Spacer(minLength: 8)
                        segmented(themeTitles, index: schemeMode) { schemeMode = $0 }
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)

                    divider

                    HStack(spacing: 12) {
                        iconBox("textformat.size")
                        Text("字体大小")
                            .font(.system(size: 15))
                            .foregroundColor(AKColor.text)
                        Spacer(minLength: 8)
                        segmented(fontSizes.map(\.title),
                                  index: fontSizes.firstIndex(of: fontSize) ?? 1) { index in
                            fontSizeRaw = fontSizes[index].rawValue
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)

                    divider

                    Button {
                        tip = "聊天背景在聊天资料页设置：私聊仅自己可见，群聊由群主设置后全员可见。"
                        showTip = true
                    } label: {
                        row("photo.fill", "聊天背景", value: "按会话设置")
                    }
                    .buttonStyle(.plain)
                }
                footnote("字体大小已保存；聊天与朋友圈正文的缩放会在后续版本跟随该设置。\n聊天背景按会话设置：进入聊天后点右上角打开聊天资料页即可更换。")

                group("通用") {
                    Button {
                        clearCache()
                    } label: {
                        row("trash.fill", "清除缓存", value: cacheText)
                    }
                    .buttonStyle(.plain)
                    divider
                    NavigationLink {
                        AboutUpdateView()
                    } label: {
                        row("arrow.triangle.2.circlepath", "检查更新")
                    }
                    .buttonStyle(.plain)
                }

                group("关于") {
                    NavigationLink {
                        AboutUpdateView()
                    } label: {
                        row("info.circle.fill", "版本", value: "v\(version)")
                    }
                    .buttonStyle(.plain)
                    divider
                    Button {
                        agreement = AgreementDoc(title: "用户协议")
                    } label: {
                        row("doc.text.fill", "用户协议")
                    }
                    .buttonStyle(.plain)
                    divider
                    Button {
                        agreement = AgreementDoc(title: "隐私政策")
                    } label: {
                        row("hand.raised.fill", "隐私政策")
                    }
                    .buttonStyle(.plain)
                    divider
                    NavigationLink { CustomerServiceView() } label: {
                        row("headphones", "客服")
                    }
                    divider
                    Button {
                        showDelete = true
                    } label: {
                        row("person.crop.circle.badge.xmark", "注销账号", danger: true)
                    }
                    .buttonStyle(.plain)
                    divider
                    Button {
                        showLogout = true
                    } label: {
                        row("rectangle.portrait.and.arrow.right", "退出登录", danger: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 30)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshCacheSize()
            refreshBanner()
        }
        .sheet(isPresented: $showEdit) {
            NavigationStack { EditProfileView() }
                .environmentObject(app)
        }
        .sheet(item: $agreement) { doc in
            AgreementSheet(title: doc.title)
        }
        .alert("退出登录？", isPresented: $showLogout) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) { app.logout() }
        }
        .alert("注销账号", isPresented: $showDelete) {
            Button("返回", role: .cancel) {}
            Button("确认注销", role: .destructive) {
                Task {
                    await APIClient.shared.deleteAccount()
                    app.logout()
                }
            }
        } message: {
            Text("注销后，以下数据将被永久删除且无法恢复：\n• 个人资料、头像、简介将被清空，昵称统一显示为「已注销账号」\n• 账号名与手机号将被释放，可以用同一个名字重新注册\n• 你会退出所有群聊，其他用户也无法再给你发送消息\n• 聊天记录会保留（对方仍可查看历史消息）\n• 靓号将被回收，其他用户可以重新获取\n• 绑定的手机号等资料将被清除\n• 当前这个账号本身将无法再次登录\n注销不可撤销")
        }
        .alert("提示", isPresented: $showTip) {
            Button("好", role: .cancel) {}
        } message: {
            Text(tip)
        }
    }

    // MARK: - 分组与行

    private func group<Content: View>(_ title: String,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 12.5))
                .foregroundColor(AKColor.muted)
                .padding(.leading, 20)
                .padding(.top, 18)
                .padding(.bottom, 8)
            VStack(spacing: 0) { content() }
                .background(AKColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 14)
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(AKColor.muted)
            .lineSpacing(4)
            .padding(.horizontal, 26)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Rectangle()
            .fill(AKColor.line)
            .frame(height: 0.6)
            .padding(.leading, 58)
    }

    private func iconBox(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 15))
            .foregroundColor(AKColor.sub)
            .frame(width: 30, height: 30)
            .background(AKColor.fill)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func row(_ icon: String, _ title: String, value: String = "",
                     danger: Bool = false) -> some View {
        HStack(spacing: 12) {
            iconBox(icon)
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(danger ? AKColor.red : AKColor.text)
            Spacer(minLength: 8)
            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.hint)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(AKColor.placeholder)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    /// 整行与开关行为一致：点行或点开关都切换同一个值
    private func switchRow(_ icon: String, _ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 12) {
                iconBox(icon)
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(AKColor.text)
                Spacer(minLength: 8)
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(AKColor.brand)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func segmented(_ options: [String], index: Int,
                           onPick: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { i in
                Button {
                    onPick(i)
                } label: {
                    Text(options[i])
                        .font(.system(size: 11.5, weight: i == index ? .medium : .regular))
                        .foregroundColor(i == index ? AKColor.text : AKColor.sub)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(i == index ? AKColor.card : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(AKColor.fill)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    // MARK: - 缓存

    private static func cacheBytes() -> Int64 {
        var total = Int64(URLCache.shared.currentMemoryUsage)
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return total
        }
        let keys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey]
        guard let en = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: keys) else {
            return total
        }
        for case let url as URL in en {
            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isRegularFile == true {
                total += Int64(values?.fileSize ?? 0)
            }
        }
        return total
    }

    private static func clearCacheNow() {
        URLCache.shared.removeAllCachedResponses()
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
              let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return
        }
        for item in items {
            try? FileManager.default.removeItem(at: item)
        }
    }

    private static func mb(_ bytes: Int64) -> String {
        String(format: "%.1f", Double(bytes) / 1024 / 1024)
    }

    private func refreshCacheSize() {
        DispatchQueue.global(qos: .utility).async {
            let bytes = SettingsView.cacheBytes()
            DispatchQueue.main.async {
                cacheText = bytes > 0 ? "\(SettingsView.mb(bytes))MB" : ""
            }
        }
    }

    private func clearCache() {
        DispatchQueue.global(qos: .utility).async {
            let before = SettingsView.cacheBytes()
            SettingsView.clearCacheNow()
            let freed = max(0, before - SettingsView.cacheBytes())
            DispatchQueue.main.async {
                cacheText = ""
                tip = freed > 0 ? "已清理 \(SettingsView.mb(freed))MB" : "没有可清理的缓存"
                showTip = true
                refreshCacheSize()
            }
        }
    }

    // MARK: - 系统横幅

    private func refreshBanner() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let on = settings.authorizationStatus == .authorized && settings.alertSetting == .enabled
            DispatchQueue.main.async {
                bannerText = on ? "去设置" : "去开启"
            }
        }
    }
}

/// 协议说明弹层
private struct AgreementSheet: View {
    let title: String

    @Environment(\.dismiss) private var dismiss

    private var summary: String {
        if title == "隐私政策" {
            return "我们只收集提供服务所必需的信息：账号资料、聊天收发记录、登录设备。密码加密存储，支付密码独立验证，聊天记录本地可控。\n\n完整的《隐私政策》正文以 AK商聊 官方发布的内容为准。"
        }
        return "使用 AK商聊 即表示你同意平台的服务规则：如实注册、合规使用、不发布违法违规内容。\n\n完整的《用户协议》正文以 AK商聊 官方发布的内容为准。"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(summary)
                        .font(.system(size: 14))
                        .foregroundColor(AKColor.sub)
                        .lineSpacing(6)
                    Link("在浏览器中打开官网",
                         destination: URL(string: "https://www.aksliao.cn")!)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AKColor.brand)
                        .padding(.top, 6)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AKColor.bg.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
