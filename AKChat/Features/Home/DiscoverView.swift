import SwiftUI

/// 广场：朋友圈 / 扫一扫 / 邀请有礼 / 我的收藏 / 系统公告（对齐安卓 DiscoverScreen）
struct DiscoverView: View {
    @EnvironmentObject private var app: AppState
    @State private var showScanner = false
    @State private var showInvite = false
    @State private var scanUid: Int64 = 0
    @State private var showScanProfile = false

    private var momentUnread: Int {
        app.conversations.first { $0.convType == "moment" }?.unread ?? 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                titleBar
                ScrollView {
                    VStack(spacing: 10) {
                        card {
                            NavigationLink {
                                MomentsView()
                            } label: {
                                row("朋友圈", icon: "photo.on.rectangle.angled", tint: AKColor.brand,
                                    trailing: AnyView(HStack(spacing: 8) {
                                        if momentUnread > 0 {
                                            Text("\(min(momentUnread, 99))")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 4)
                                                .frame(minWidth: 18, minHeight: 18)
                                                .background(AKColor.red)
                                                .clipShape(Capsule())
                                        }
                                        AvatarView(url: app.user?.avatar,
                                                   name: app.user?.displayName ?? "我",
                                                   size: 26)
                                    }))
                            }
                            .buttonStyle(.plain)
                            divider
                            Button {
                                showScanner = true
                            } label: {
                                row("扫一扫", icon: "qrcode.viewfinder", tint: Color(hex: 0x57C7FF))
                            }
                            .buttonStyle(.plain)
                            divider
                            Button {
                                showInvite = true
                            } label: {
                                row("邀请有礼", icon: "gift.fill", tint: Color(hex: 0xFF8A65))
                            }
                            .buttonStyle(.plain)
                        }

                        card {
                            NavigationLink {
                                FavoritesView()
                            } label: {
                                row("我的收藏", icon: "giftcard.fill", tint: AKColor.gold)
                            }
                            .buttonStyle(.plain)
                            divider
                            NavigationLink {
                                NoticesView()
                            } label: {
                                row("系统公告", icon: "megaphone.fill", tint: Color(hex: 0x8B7CF6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 10)
                }
            }
            .background(AKColor.bg)
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showScanner) {
                ScannerView { code in
                    showScanner = false
                    openCode(code)
                }
            }
            .sheet(isPresented: $showInvite) {
                NavigationStack { InviteView() }
            }
            .sheet(isPresented: $showScanProfile) {
                NavigationStack { UserProfileView(uid: scanUid) }
            }
        }
    }

    /// 扫码结果：链接里带 id= 或纯数字时直接打开个人主页
    private func openCode(_ code: String) {
        let text = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = text.range(of: "id=") {
            let num = text[range.upperBound...].prefix { $0.isNumber }
            if let uid = Int64(num), uid > 0 {
                scanUid = uid
                showScanProfile = true
                return
            }
        }
        if let uid = Int64(text), uid > 0 {
            scanUid = uid
            showScanProfile = true
        }
    }

    /// 标题：左对齐 17 semibold（与安卓 DiscoverScreen 一致）
    private var titleBar: some View {
        Text("广场")
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(AKColor.text)
            .padding(.leading, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AKColor.card)
    }

    /// 分组容器：安卓为通栏白底，不做圆角
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(AKColor.card)
    }

    /// 广场行：图标 30 圆角 9、上下 13、右侧箭头（对齐安卓 DiscoverCard）
    private func row(_ title: String, icon: String, tint: Color, trailing: AnyView? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(title)
                .font(.system(size: 15.5))
                .foregroundColor(AKColor.text)
            Spacer(minLength: 0)
            if let trailing {
                trailing
                    .padding(.leading, 8)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AKColor.placeholder)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }

    /// 分组内分隔线：从图标右侧 56pt 起（对齐安卓）
    private var divider: some View {
        Rectangle()
            .fill(AKColor.fill)
            .frame(height: 0.6)
            .padding(.leading, 56)
    }
}

/// 邀请有礼：展示我的邀请码与分享入口
struct InviteView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private var code: String {
        app.user?.displayNo ?? ""
    }

    private var inviteLink: URL? {
        guard !code.isEmpty else { return nil }
        return URL(string: "https://www.aksliao.cn/register.php?invite=\(code)")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                codeCard

                Text("好友注册时填写该 AK号，双方都可获得奖励")
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.hint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                shareButton
                posterEntry
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .navigationTitle("邀请有礼")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
        }
    }

    /// 顶部邀请码卡：金色大号号码，整块可点复制
    private var codeCard: some View {
        VStack(spacing: 10) {
            Text("我的邀请码")
                .font(.system(size: 13))
                .foregroundColor(AKColor.sub)

            Button {
                copyCode()
            } label: {
                VStack(spacing: 8) {
                    Text(code.isEmpty ? "-" : code)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(AKColor.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    HStack(spacing: 5) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                        Text(copied ? "已复制" : "点击复制")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(AKColor.hint)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(code.isEmpty)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var shareButton: some View {
        if let url = inviteLink {
            ShareLink(item: url) {
                greenButtonLabel("分享邀请链接", enabled: true)
            }
            .buttonStyle(.plain)
        } else {
            greenButtonLabel("分享邀请链接", enabled: false)
        }
    }

    private func greenButtonLabel(_ title: String, enabled: Bool) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(enabled ? AKColor.brand : AKColor.line)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var posterEntry: some View {
        NavigationLink {
            PosterView(name: app.user?.displayName ?? "我",
                       avatar: app.user?.avatar,
                       number: code,
                       uid: app.user?.id ?? 0)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AKColor.goldSoft)
                        .frame(width: 38, height: 38)
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 17))
                        .foregroundColor(AKColor.gold)
                }
                Text("我的海报")
                    .font(.system(size: 15))
                    .foregroundColor(AKColor.text)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AKColor.placeholder)
            }
            .padding(14)
            .background(AKColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func copyCode() {
        guard !code.isEmpty else { return }
        UIPasteboard.general.string = code
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }
}
