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
            ScrollView {
                VStack(spacing: 10) {
                    VStack(spacing: 0) {
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
                    .background(AKColor.card)

                    VStack(spacing: 0) {
                        NavigationLink {
                            FavoritesView()
                        } label: {
                            row("我的收藏", icon: "star.circle.fill", tint: AKColor.gold)
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
                    .background(AKColor.card)
                }
                .padding(.top, 10)
            }
            .background(AKColor.bg)
            .navigationTitle("广场")
            .navigationBarTitleDisplayMode(.inline)
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

    /// 广场行：图标 38 圆角 10、行高 54、右侧箭头
    private func row(_ title: String, icon: String, tint: Color, trailing: AnyView? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(title)
                .font(.system(size: 15.5))
                .foregroundColor(AKColor.text)
            Spacer(minLength: 0)
            if let trailing {
                trailing
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AKColor.placeholder)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .contentShape(Rectangle())
    }

    /// 分组内分隔线：与安卓同样从图标右侧开始
    private var divider: some View {
        Rectangle()
            .fill(AKColor.fill)
            .frame(height: 0.5)
            .padding(.leading, 66)
    }
}

/// 邀请有礼：展示我的邀请码与分享入口
struct InviteView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    private var code: String {
        app.user?.displayNo ?? ""
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    Text("我的邀请码")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.sub)
                    Text(code)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(AKColor.gold)
                    Text("好友注册时填写该 AK号，双方都可获得奖励")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.hint)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            Section {
                Button {
                    UIPasteboard.general.string = code
                } label: {
                    Text("复制邀请码").frame(maxWidth: .infinity)
                }
                if let url = URL(string: "https://www.aksliao.cn/register.php?invite=\(code)") {
                    ShareLink(item: url) {
                        Text("分享邀请链接").frame(maxWidth: .infinity)
                    }
                }
                NavigationLink("我的海报") {
                    PosterView(name: app.user?.displayName ?? "我",
                               avatar: app.user?.avatar,
                               number: code,
                               uid: app.user?.id ?? 0)
                }
            }
        }
        .navigationTitle("邀请有礼")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
        }
    }
}
