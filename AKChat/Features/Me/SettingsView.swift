import SwiftUI
import UIKit

/// 设置：安卓同款分组圆角卡 + 图标行（对齐安卓 SettingsScreen）
struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @AppStorage("ak.notify.sound") private var sound = true
    @AppStorage("ak.notify.vibrate") private var vibrate = true
    @State private var showLogout = false
    @State private var showDelete = false
    @AppStorage("colorSchemeMode") private var schemeMode = 0
    @AppStorage("floatingBubble") private var bubbleOn = false
    @State private var cacheText = ""
    @State private var tip = ""
    @State private var showTip = false

    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let themeTitles = ["跟随系统", "浅色", "深色"]

    var body: some View {
        List {
            // 外观与通知
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    iconBox("moon.fill")
                    Text("深色模式")
                        .font(.system(size: 15))
                        .foregroundColor(AKColor.text)
                    Spacer(minLength: 8)
                    themeSwitch
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                divider
                switchRow(icon: "speaker.wave.2.fill", title: "消息声音", isOn: $sound)
                divider
                switchRow(icon: "iphone.radiowaves.left.and.right", title: "消息震动", isOn: $vibrate)
                divider
                switchRow(icon: "circle.circle.fill", title: "聊天悬浮球", isOn: $bubbleOn)
                divider
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    rowLabel(icon: "bell.fill", title: "通知设置", trailing: "")
                }
                .buttonStyle(.plain)
            }
            .akCardRow(top: true, bottom: true, radius: 14)
            .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 14, trailing: 12))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            // 通用
            VStack(spacing: 0) {
                Button {
                    clearCache()
                } label: {
                    rowLabel(icon: "sparkles", title: "清除缓存", trailing: cacheText)
                }
                .buttonStyle(.plain)
                divider
                NavigationLink {
                    AboutUpdateView()
                } label: {
                    rowLabel(icon: "info.circle.fill", title: "关于", trailing: "v\(version)")
                }
                .buttonStyle(.plain)
                divider
                NavigationLink {
                    AboutUpdateView()
                } label: {
                    rowLabel(icon: "arrow.triangle.2.circlepath", title: "检查更新", trailing: "")
                }
                .buttonStyle(.plain)
            }
            .akCardRow(top: true, bottom: true, radius: 14)
            .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 14, trailing: 12))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            // 帮助与协议
            VStack(spacing: 0) {
                Link(destination: URL(string: "https://www.aksliao.cn/about.php")!) {
                    rowLabel(icon: "globe", title: "关于我们", trailing: "")
                }
                divider
                Link(destination: URL(string: "https://www.aksliao.cn/service.php")!) {
                    rowLabel(icon: "headphones", title: "联系客服", trailing: "")
                }
                divider
                Link(destination: URL(string: "https://www.aksliao.cn/register.php")!) {
                    rowLabel(icon: "doc.text.fill", title: "用户协议与隐私政策", trailing: "")
                }
            }
            .akCardRow(top: true, bottom: true, radius: 14)
            .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 14, trailing: 12))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            // 账号
            VStack(spacing: 0) {
                NavigationLink {
                    PrivacySettingsView()
                } label: {
                    rowLabel(icon: "lock.fill", title: "隐私与安全", trailing: "")
                }
                .buttonStyle(.plain)
                divider
                NavigationLink {
                    FavoritesView()
                } label: {
                    rowLabel(icon: "star.fill", title: "我的收藏", trailing: "")
                }
                .buttonStyle(.plain)
                divider
                NavigationLink {
                    EmojiManagerView()
                } label: {
                    rowLabel(icon: "face.smiling", title: "我的表情", trailing: "")
                }
                .buttonStyle(.plain)
                divider
                NavigationLink {
                    BlacklistView()
                } label: {
                    rowLabel(icon: "hand.raised.fill", title: "黑名单", trailing: "")
                }
                .buttonStyle(.plain)
            }
            .akCardRow(top: true, bottom: true, radius: 14)
            .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 14, trailing: 12))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            // 退出与注销
            VStack(spacing: 0) {
                Button {
                    showLogout = true
                } label: {
                    Text("退出登录")
                        .font(.system(size: 15))
                        .foregroundColor(AKColor.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                divider
                Button {
                    showDelete = true
                } label: {
                    Text("注销账号")
                        .font(.system(size: 15))
                        .foregroundColor(AKColor.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .akCardRow(top: true, bottom: true, radius: 14)
            .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 30, trailing: 12))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AKColor.bg.ignoresSafeArea())
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshCacheSize() }
        .alert("退出登录？", isPresented: $showLogout) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) { app.logout() }
        }
        .alert("确定注销账号？", isPresented: $showDelete) {
            Button("取消", role: .cancel) {}
            Button("确认注销", role: .destructive) {
                Task {
                    await APIClient.shared.deleteAccount()
                    app.logout()
                }
            }
        } message: {
            Text("注销后账号与聊天记录无法恢复。")
        }
        .alert("提示", isPresented: $showTip) {
            Button("好", role: .cancel) {}
        } message: {
            Text(tip)
        }
    }

    // MARK: - 行与分组

    private var divider: some View {
        Rectangle()
            .fill(AKColor.line)
            .frame(height: 0.6)
            .padding(.leading, 58)
    }

    private func iconBox(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 17))
            .foregroundColor(AKColor.sub)
            .frame(width: 30, height: 30)
            .background(AKColor.fill)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func rowLabel(icon: String, title: String, trailing: String) -> some View {
        HStack(spacing: 12) {
            iconBox(icon)
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(AKColor.text)
            Spacer(minLength: 8)
            if !trailing.isEmpty {
                Text(trailing)
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.hint)
                    .padding(.trailing, 4)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 15))
                .foregroundColor(AKColor.placeholder)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    private func switchRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            iconBox(icon)
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(AKColor.text)
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(AKColor.brand)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var themeSwitch: some View {
        HStack(spacing: 0) {
            ForEach(themeTitles.indices, id: \.self) { index in
                Button {
                    schemeMode = index
                } label: {
                    Text(themeTitles[index])
                        .font(.system(size: 11.5, weight: schemeMode == index ? .medium : .regular))
                        .foregroundColor(schemeMode == index ? AKColor.text : AKColor.sub)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(schemeMode == index ? AKColor.card : Color.clear)
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
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return 0 }
        let keys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey]
        guard let en = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: keys) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in en {
            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isRegularFile == true {
                total += Int64(values?.fileSize ?? 0)
            }
        }
        return total
    }

    private static func clearCache() -> Int64 {
        let freed = cacheBytes()
        URLCache.shared.removeAllCachedResponses()
        if let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
           let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for item in items {
                try? FileManager.default.removeItem(at: item)
            }
        }
        return freed
    }

    private static func fmtCache(_ bytes: Int64) -> String {
        if bytes >= 1024 * 1024 * 1024 {
            return String(format: "%.1fG", Double(bytes) / 1024 / 1024 / 1024)
        }
        if bytes >= 1024 * 1024 {
            return String(format: "%.1fM", Double(bytes) / 1024 / 1024)
        }
        if bytes >= 1024 {
            return "\(bytes / 1024)K"
        }
        return "\(bytes)B"
    }

    private func refreshCacheSize() {
        DispatchQueue.global(qos: .utility).async {
            let bytes = SettingsView.cacheBytes()
            let text = bytes > 0 ? SettingsView.fmtCache(bytes) : ""
            DispatchQueue.main.async {
                cacheText = text
            }
        }
    }

    private func clearCache() {
        DispatchQueue.global(qos: .utility).async {
            let freed = SettingsView.clearCache()
            let text = freed > 0 ? "已清理 \(SettingsView.fmtCache(freed))" : "没有可清理的缓存"
            DispatchQueue.main.async {
                cacheText = ""
                tip = text
                showTip = true
            }
        }
    }
}
