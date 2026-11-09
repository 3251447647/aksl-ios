import SwiftUI
import UIKit
import UserNotifications

/// 设置：深色模式 / 语音播放 / 通知设置 / 清除缓存 / 关于 / 检查更新（对齐安卓 SettingsScreen）
struct SettingsView: View {
    /// 0 跟随系统 / 1 浅色 / 2 深色
    @AppStorage("colorSchemeMode") private var schemeMode = 0
    @AppStorage("ak.notify.master") private var notifyMaster = true

    @State private var showTip = false
    @State private var tip = ""
    @State private var cacheText = ""

    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let themeTitles = ["跟随系统", "浅色", "深色"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                group {
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

                    NavigationLink {
                        NotifySettingsView()
                    } label: {
                        row("bell.fill", "通知设置", value: notifyMaster ? "" : "已关闭")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 10)

                group {
                    Button {
                        clearCache()
                    } label: {
                        row("trash.fill", "清除缓存", value: cacheText)
                    }
                    .buttonStyle(.plain)

                    divider

                    NavigationLink {
                        AboutView()
                    } label: {
                        row("info.circle.fill", "关于", value: "v\(version)")
                    }
                    .buttonStyle(.plain)

                    divider

                    NavigationLink {
                        CheckUpdateView()
                    } label: {
                        row("arrow.triangle.2.circlepath", "检查更新")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 14)
            }
            .padding(.bottom, 30)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .reportsDetailPage()
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshCacheSize() }
        .alert("提示", isPresented: $showTip) {
            Button("好", role: .cancel) {}
        } message: {
            Text(tip)
        }
    }

    // MARK: - 分组与行

    private func group<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(AKColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 12)
    }

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

    private func row(_ icon: String, _ title: String, value: String = "") -> some View {
        HStack(spacing: 12) {
            iconBox(icon)
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(AKColor.text)
            Spacer(minLength: 8)
            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.hint)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AKColor.placeholder)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
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
}

/// 通知设置：接收/声音/震动 + 系统横幅（对齐安卓 NotifySettingsPage）
struct NotifySettingsView: View {
    @AppStorage("ak.notify.master") private var notifyMaster = true
    @AppStorage("ak.notify.sound") private var sound = true
    @AppStorage("ak.notify.vibrate") private var vibrate = true
    @State private var bannerText = "去设置"

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                VStack(spacing: 0) {
                    switchRow("接收新消息通知", isOn: $notifyMaster)
                    line
                    switchRow("声音", isOn: $sound)
                    line
                    switchRow("震动", isOn: $vibrate)
                    line
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("横幅通知（系统）")
                                    .font(.system(size: 15))
                                    .foregroundColor(AKColor.text)
                                Text("新消息到达时在屏幕顶部弹出，需系统允许横幅/悬浮通知")
                                    .font(.system(size: 12))
                                    .foregroundColor(AKColor.muted)
                            }
                            Spacer(minLength: 8)
                            Text(bannerText)
                                .font(.system(size: 13))
                                .foregroundColor(AKColor.brand)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .background(AKColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text("免打扰时段需系统通知调度支持，当前版本暂未开放。")
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
            }
            .padding(14)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .navigationTitle("通知设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshBanner() }
    }

    private var line: some View {
        Rectangle().fill(AKColor.line).frame(height: 0.5)
    }

    private func switchRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 8) {
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

    private func refreshBanner() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let on = settings.authorizationStatus == .authorized && settings.alertSetting == .enabled
            DispatchQueue.main.async {
                bannerText = on ? "去设置" : "去开启"
            }
        }
    }
}
