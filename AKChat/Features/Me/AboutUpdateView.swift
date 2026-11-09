import SwiftUI
import UIKit

/// 关于：安卓 AboutScreen 的头部主卡 + 特性 / 简介 / 功能 / 承诺 / 联系 / 协议，不含版本检查
struct AboutView: View {
    private let siteName = "AK商聊"
    private let officialSite = "https://www.aksliao.cn"
    private let features: [(String, UInt32, String, String)] = [
        ("💬", 0x2FBE6E, "即时通讯", "文字、图片、语音、表情、引用、转发，一个都不少。"),
        ("⭐", 0xFF4D6D, "靓号系统", "众多珍稀靓号任你挑选，让你的AK号一眼出众。"),
        ("👑", 0xFFB020, "VIP 会员", "VIP / SVIP 双等级尊贵体验，专属徽章、更高群成员上限。"),
        ("🎁", 0xFF6B4A, "红包 · 转账 · 礼物", "单聊群聊都支持，发红包、转账、送礼物，用K币让互动更有心意。"),
        ("👥", 0x6C8AE4, "群聊体验", "多人群聊、@全体、置顶消息、群公告、全员禁言、群靓号。"),
        ("🛡", 0x2FBE6E, "隐私安全", "密码加密存储，支付密码独立验证，聊天记录本地可控。")
    ]
    private let promises: [(String, String)] = [
        ("永久免费", "基础聊天功能永久免费，让每一次沟通都零门槛。"),
        ("拒绝广告", "界面干净清爽，不推送任何骚扰信息。"),
        ("持续迭代", "功能不断打磨，每周都有新体验。")
    ]

    private var versionName: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        List {
            Group {
                hero
                    .listRowInsets(EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                HStack(spacing: 10) {
                    miniFeature("即时", "消息秒达")
                    miniFeature("安全", "隐私加密")
                    miniFeature("免费", "永久开放")
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 14, trailing: 14))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            Group {
                sectionTitle("产品简介")
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 8, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                Text("\(siteName) 是一款专注于「商务社交 · 高效沟通」的即时通讯应用。\n\n我们相信，好的产品应当让人与人之间的连接更简单、更真诚、更有温度。\n\n无论您是想找一个专属靓号彰显独特身份，还是想与好友畅快聊天、分享生活，\(siteName) 都能为您提供流畅稳定的体验。")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.sub)
                    .lineSpacing(6)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .akCardRow(top: true, bottom: true, radius: 16)
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 14, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                sectionTitle("核心功能")
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 8, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                featuresCard
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 14, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            Group {
                sectionTitle("我们的承诺")
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 8, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                promisesCard
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 14, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                sectionTitle("联系我们")
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 8, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                linksCard
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 14, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                sectionTitle("协议与政策")
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 8, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                policyCard
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 14, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                footer
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 24, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AKColor.bg.ignoresSafeArea())
        .reportsDetailPage()
        .navigationTitle("关于 \(siteName)")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 核心功能 / 承诺 / 联系 / 协议

    private var featuresCard: some View {
        VStack(spacing: 0) {
            ForEach(features.indices, id: \.self) { index in
                let f = features[index]
                HStack(alignment: .top, spacing: 12) {
                    Text(f.0)
                        .font(.system(size: 17))
                        .frame(width: 38, height: 38)
                        .background(Color(hex: f.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(f.2)
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundColor(AKColor.text)
                        Text(f.3)
                            .font(.system(size: 12))
                            .foregroundColor(AKColor.muted)
                            .lineSpacing(3)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)

                if index < features.count - 1 {
                    Rectangle()
                        .fill(AKColor.line)
                        .frame(height: 0.5)
                        .padding(.leading, 64)
                }
            }
        }
        .akCardRow(top: true, bottom: true, radius: 16)
    }

    private var promisesCard: some View {
        VStack(spacing: 0) {
            ForEach(promises.indices, id: \.self) { index in
                let item = promises[index]
                HStack(alignment: .top, spacing: 12) {
                    Text("✓")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Color(hex: 0x2FBE6E))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.0)
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundColor(AKColor.text)
                        Text(item.1)
                            .font(.system(size: 12))
                            .foregroundColor(AKColor.muted)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)

                if index < promises.count - 1 {
                    Rectangle()
                        .fill(AKColor.line)
                        .frame(height: 0.5)
                        .padding(.leading, 56)
                }
            }
        }
        .akCardRow(top: true, bottom: true, radius: 16)
    }

    private var linksCard: some View {
        VStack(spacing: 0) {
            Link(destination: URL(string: officialSite)!) {
                linkRow("🌐", 0x2FBE6E, "官方网站", officialSite)
            }
            divider64
            NavigationLink { CustomerServiceView() } label: {
                linkRow("🎧", 0x6C8AE4, "在线客服", "有任何问题，欢迎随时咨询")
            }
        }
        .akCardRow(top: true, bottom: true, radius: 16)
    }

    private var policyCard: some View {
        VStack(spacing: 0) {
            NavigationLink { PolicyDetailView(kind: .terms) } label: {
                linkRow("📄", 0x2FBE6E, "用户协议", "使用前请阅读本协议", chevron: false)
            }
            divider64
            NavigationLink { PolicyDetailView(kind: .privacy) } label: {
                linkRow("🔒", 0x6C8AE4, "隐私政策", "我们如何收集与保护你的信息", chevron: false)
            }
        }
        .akCardRow(top: true, bottom: true, radius: 16)
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("\(siteName) · v\(versionName)")
            Text("© 2026 All Rights Reserved")
        }
        .font(.system(size: 11))
        .foregroundColor(AKColor.placeholder)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 头部主卡

    private var hero: some View {
        VStack(spacing: 0) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 66, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .frame(width: 74, height: 74)
                .background(AKColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(siteName)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 12)

            Text("v\(versionName)")
                .font(.system(size: 11.5))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.top, 8)

            Text("让沟通更有温度")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.9))
                .padding(.top, 12)
            Text("一款为商务社交而生的即时通讯应用")
                .font(.system(size: 12.5))
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, 2)

            HStack(spacing: 10) {
                Link(destination: URL(string: officialSite)!) {
                    Text("下载 App")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(Color(hex: 0x1FA45B))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 9)
                        .background(AKColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                NavigationLink { CustomerServiceView() } label: {
                    Text("在线客服")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.top, 16)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color(hex: 0x2FBE6E), Color(hex: 0x1FA45B)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func miniFeature(_ title: String, _ desc: String) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 14.5, weight: .bold))
                .foregroundColor(Color(hex: 0x2FBE6E))
            Text(desc)
                .font(.system(size: 11))
                .foregroundColor(AKColor.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func linkRow(_ icon: String, _ color: UInt32, _ title: String, _ desc: String,
                         chevron: Bool = true) -> some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 16))
                .frame(width: 38, height: 38)
                .background(Color(hex: color))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14.5))
                    .foregroundColor(AKColor.text)
                Text(desc)
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15))
                    .foregroundColor(AKColor.placeholder)
            }
        }
        .padding(14)
        .contentShape(Rectangle())
    }

    private func sectionTitle(_ title: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(hex: 0x2FBE6E))
                .frame(width: 3, height: 13)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AKColor.sub)
        }
        .padding(.leading, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider64: some View {
        Rectangle()
            .fill(AKColor.line)
            .frame(height: 0.5)
            .padding(.leading, 64)
    }
}

/// 用户协议 / 隐私政策：站点没有独立协议页，先在 App 内展示正文
struct PolicyDetailView: View {
    enum Kind { case terms, privacy }

    let kind: Kind

    private var title: String {
        switch kind {
        case .terms: return "用户协议"
        case .privacy: return "隐私政策"
        }
    }
    private var sections: [(String, String)] {
        switch kind {
        case .terms:
            return [
                ("一、协议范围", "本协议是你与 AK商聊 之间关于注册、登录和使用本应用及相关服务的约定。注册即视为已阅读并同意本协议全部内容。"),
                ("二、账号", "你需要使用真实可用的邮箱完成注册。账号仅限本人使用，不得转让、出租或出借。请自行保管登录密码与支付密码，因保管不当造成的损失由你自行承担。"),
                ("三、使用规范", "不得利用本应用发布违法、侵权、骚扰、欺诈或危害他人的内容，不得发送垃圾信息、批量注册账号或干扰服务正常运行。违反上述约定的账号可能被限制功能、禁言或封禁。"),
                ("四、内容与财产", "你在本应用中发布的内容由你自行负责。K币、靓号、会员等虚拟权益按页面展示的规则提供，充值后不支持退款，请确认后再操作。"),
                ("五、服务变更与终止", "我们可能根据运营需要调整功能或暂停部分服务，并尽量提前公告。你可以随时停止使用本应用并申请注销账号。"),
                ("六、联系我们", "对本协议有疑问，可通过「我的 → 联系客服」与我们联系。")
            ]
        case .privacy:
            return [
                ("一、我们收集的信息", "注册与登录：邮箱地址、昵称、密码（加密存储）。个人资料：你主动填写的头像、简介等。使用过程：好友关系、群聊成员、聊天消息、充值记录。设备信息：设备型号、系统版本、推送标识，用于消息推送与故障排查。"),
                ("二、权限用途", "相册：发送图片与表情。相机与麦克风：拍照、语音消息、音视频通话与直播。通知：接收新消息提醒。以上权限均在你授权后才会使用，可随时在系统设置中关闭。"),
                ("三、信息的使用", "收集的信息仅用于提供聊天、群聊、朋友圈、支付与客服等功能，以及保障账号与平台安全。我们不会将你的个人信息出售给第三方。"),
                ("四、信息的存储与保护", "数据存储于我们的服务器，密码采用不可逆加密保存，支付密码单独校验。聊天记录同时保存在你的设备上，卸载应用或清理数据会一并删除本地记录。"),
                ("五、信息共享", "除法律法规要求或你明确授权外，我们不会向第三方提供你的个人信息。为完成支付、推送等功能，会按最小必要原则使用相应的第三方服务。"),
                ("六、你的权利", "你可以随时在个人资料中查看与修改信息，在隐私设置中调整展示范围，或通过客服申请导出、更正与注销账号。"),
                ("七、联系我们", "对隐私政策有疑问，可通过「我的 → 联系客服」与我们联系。")
            ]
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(sections.indices, id: \.self) { index in
                    let item = sections[index]
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.0)
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundColor(AKColor.text)
                        Text(item.1)
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.sub)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)

                    if index < sections.count - 1 {
                        Rectangle()
                            .fill(AKColor.line)
                            .frame(height: 0.5)
                            .padding(.leading, 16)
                    }
                }
            }
            .background(AKColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(14)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .reportsDetailPage()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 检查更新：进入即查，用服务端 iOS 最新 version_code 与本地 CFBundleVersion 比较
struct CheckUpdateView: View {
    @State private var info: IOSVersionInfo?
    @State private var checking = false
    @State private var checked = false
    @State private var errorText: String?

    private var currentCode: Int {
        Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") ?? 0
    }

    private var versionName: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var latestCode: Int { info?.versionCode ?? 0 }
    private var hasUpdate: Bool { latestCode > currentCode }

    /// force_update=1 或本地低于 min_supported_code 都必须更新
    private var forced: Bool {
        guard let info, hasUpdate else { return false }
        if info.forceUpdate == 1 { return true }
        return info.minSupportedCode > 0 && currentCode < info.minSupportedCode
    }

    private var changelogLines: [String] {
        (info?.changelog ?? "")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if checking || !checked {
                    ProgressView()
                        .padding(.top, 90)
                    Text("正在检查更新…")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.sub)
                        .padding(.top, 16)
                } else if let errorText {
                    Text("检查失败：" + errorText)
                        .font(.system(size: 13.5))
                        .foregroundColor(AKColor.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 70)
                    Button {
                        Task { await check() }
                    } label: {
                        Text("重试")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 26)
                            .frame(height: 42)
                            .background(AKColor.brand)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 18)
                } else if hasUpdate {
                    updateCard
                } else {
                    Text("当前已是最新版本")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AKColor.text)
                        .padding(.top, 66)
                    Text("当前版本 v\(versionName)")
                        .font(.system(size: 12.5))
                        .foregroundColor(AKColor.muted)
                        .padding(.top, 8)
                    Button {
                        Task { await check() }
                    } label: {
                        Text("重新检查")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 26)
                            .frame(height: 42)
                            .background(AKColor.brand)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 22)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .reportsDetailPage()
        .navigationTitle("检查更新")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !checked { await check() }
        }
    }

    private var updateCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("发现新版本 v" + (info?.versionName ?? ""))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AKColor.brand)
                .padding(.bottom, 14)

            if changelogLines.isEmpty {
                Text("修复问题并优化体验")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.sub)
                    .lineSpacing(6)
            } else {
                ForEach(changelogLines.indices, id: \.self) { i in
                    Text("· " + changelogLines[i])
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.sub)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if forced {
                Text("此版本为强制更新，需更新后才能继续使用")
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.red)
                    .padding(.top, 12)
            }

            if let size = info?.fileSize, size > 0 {
                Text("安装包 " + sizeText(size))
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.hint)
                    .padding(.top, 6)
            }

            Button {
                openUpdate()
            } label: {
                Text("立即更新")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AKColor.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 18)

            Text("按钮会打开 App Store 或 IPA 安装地址；没有配置地址时打开官网下载页")
                .font(.system(size: 11))
                .foregroundColor(AKColor.hint)
                .padding(.top, 10)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.brandSoft)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sizeText(_ bytes: Int64) -> String {
        if bytes >= 1024 * 1024 * 1024 {
            return String(format: "%.1fG", Double(bytes) / 1024 / 1024 / 1024)
        }
        if bytes >= 1024 * 1024 {
            return String(format: "%.1fM", Double(bytes) / 1024 / 1024)
        }
        return "\(bytes / 1024)K"
    }

    private func openUpdate() {
        let raw = (info?.ipaUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = "https://www.aksliao.cn/download/"
        guard let url = URL(string: raw.isEmpty ? fallback : raw) else { return }
        UIApplication.shared.open(url)
    }

    private func check() async {
        guard !checking else { return }
        checking = true
        errorText = nil
        defer {
            checking = false
            checked = true
        }
        do {
            info = try await APIClient.shared.iosAppVersion()
        } catch {
            // 老服务端还没有 /app/version/ios，回落到安卓接口里的 ios_* 字段
            do {
                let legacy = try await APIClient.shared.appVersion()
                info = IOSVersionInfo(legacy: legacy)
            } catch {
                errorText = error.localizedDescription
                info = nil
            }
        }
    }
}
