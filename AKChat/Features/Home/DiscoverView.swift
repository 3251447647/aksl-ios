import SwiftUI

/// 广场：朋友圈 / 扫一扫 / 邀请有礼 / 每日免费抽奖（对齐安卓 DiscoverScreen）
struct DiscoverView: View {
    @EnvironmentObject private var app: AppState
    @State private var showScanner = false
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
                            NavigationLink {
                                InviteRewardView()
                            } label: {
                                row("邀请有礼", icon: "gift.fill", tint: Color(hex: 0xFF8A65))
                            }
                            .buttonStyle(.plain)
                        }

                        card {
                            NavigationLink {
                                LotteryView()
                            } label: {
                                row("每日免费抽奖", icon: "die.face.5.fill", tint: AKColor.gold,
                                    trailing: AnyView(Text("免费")
                                        .font(.system(size: 10.5, weight: .semibold))
                                        .foregroundColor(AKColor.gold)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(AKColor.goldSoft)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))))
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
            .navigationDestination(isPresented: $showScanProfile) {
                UserProfileView(uid: scanUid)
                    .restoresSwipeBack()
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
