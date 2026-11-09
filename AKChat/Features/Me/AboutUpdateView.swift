import SwiftUI

/// 关于与版本更新：安卓 AboutScreen 的头部主卡 + 特性 / 简介 / 联系分组，末尾接检查更新
struct AboutUpdateView: View {
    @State private var info: AppVersionInfo?
    @State private var checking = false
    @State private var errorText: String?
    @State private var checkedAt: Date?

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

    private var currentVersion: String {
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(versionName) (\(b))"
    }

    private var hasUpdate: Bool {
        guard let info, let cur = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else { return false }
        return info.latestCode > (Int(cur) ?? 0)
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
            }

            Group {
                sectionTitle("版本更新")
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 8, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                versionCard
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 14, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                if let errorText {
                    Text(errorText)
                        .font(.system(size: 12.5))
                        .foregroundColor(AKColor.red)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 14, trailing: 14))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }

                footer
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 24, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AKColor.bg.ignoresSafeArea())
        .navigationTitle("关于 \(siteName)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if info == nil { await check() }
        }
    }

    // MARK: - 版本更新卡

    private var versionCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("当前版本")
                    .font(.system(size: 15))
                    .foregroundColor(AKColor.text)
                Spacer(minLength: 8)
                Text(currentVersion)
                    .font(.system(size: 13.5))
                    .foregroundColor(AKColor.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)

            divider

            Button {
                Task { await check() }
            } label: {
                HStack(spacing: 8) {
                    Text("检查更新")
                        .font(.system(size: 15))
                        .foregroundColor(AKColor.text)
                    Spacer(minLength: 8)
                    if checking {
                        ProgressView()
                    } else if let info {
                        Text(hasUpdate
                             ? (info.latestName.isEmpty ? "\(info.latestCode)" : info.latestName)
                             : "已是最新")
                            .font(.system(size: 13.5))
                            .foregroundColor(AKColor.muted)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15))
                        .foregroundColor(AKColor.placeholder)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(checking)

            if let info, hasUpdate {
                divider
                VStack(alignment: .leading, spacing: 6) {
                    Text("新版本 \(info.latestName.isEmpty ? "\(info.latestCode)" : info.latestName)")
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundColor(AKColor.text)
                    if !info.changelog.isEmpty {
                        Text(info.changelog)
                            .font(.system(size: 12.5))
                            .foregroundColor(AKColor.sub)
                            .lineSpacing(4)
                    }
                    if let u = URL(string: info.url), !info.url.isEmpty {
                        Link(destination: u) {
                            Text("前往下载")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(AKColor.brand)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AKColor.brandSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if checkedAt != nil {
                divider
                Text("已是最新版本")
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.hint)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .akCardRow(top: true, bottom: true, radius: 16)
    }

    // MARK: - 核心功能 / 承诺 / 联系

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
            Text("易")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(Color(hex: 0x2FBE6E))
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

    private func linkRow(_ icon: String, _ color: UInt32, _ title: String, _ desc: String) -> some View {
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
            Image(systemName: "chevron.right")
                .font(.system(size: 15))
                .foregroundColor(AKColor.placeholder)
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

    private var divider: some View {
        Rectangle()
            .fill(AKColor.line)
            .frame(height: 0.5)
            .padding(.leading, 16)
    }

    private var divider64: some View {
        Rectangle()
            .fill(AKColor.line)
            .frame(height: 0.5)
            .padding(.leading, 64)
    }

    private func check() async {
        checking = true
        defer { checking = false }
        do {
            info = try await APIClient.shared.appVersion()
            errorText = nil
            checkedAt = Date()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
