import SwiftUI
import UIKit

/// 我的：资料头 + 会员卡 + 数据 + 四宫格入口 + 账号与安全（对齐安卓 MeScreen）
struct MeView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var showLogout = false
    @State private var copied = false

    private var displayName: String { app.user?.displayName ?? "未登录" }
    private var number: String { app.user?.displayNo ?? "-" }
    private var vipLevel: Int { app.user?.vipLevel ?? 0 }
    private var vipDays: Int { app.user?.vipDays ?? 0 }
    private var prettyNo: String { app.user?.prettyYxid ?? "" }
    private var premium: Bool { vipLevel > 0 }

    /// 与安卓一致：SVIP 金、VIP 蓝紫、普通跟随正文色（靓号时为浅金）
    private var headerAccent: Color {
        if vipLevel == 2 { return Color(hex: 0xF3D27C) }
        if vipLevel == 1 { return Color(hex: 0xE9E2FF) }
        if !prettyNo.isEmpty { return Color(hex: 0xFFE0A6) }
        return AKColor.text
    }

    private var headerGradient: LinearGradient {
        if vipLevel == 2 {
            return LinearGradient(colors: [Color(hex: 0x2B2418), Color(hex: 0x0D0B08)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if vipLevel == 1 {
            return LinearGradient(colors: [Color(hex: 0x332A7A), Color(hex: 0x19154A)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        let top = colorScheme == .dark ? Color(hex: 0x18202B) : Color(hex: 0xF2F6FF)
        return LinearGradient(colors: [top, AKColor.card], startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    VipBanner(vipLevel: vipLevel, vipDays: vipDays) { VipView() }
                        .padding(.top, 12)
                    statsCard
                        .padding(.top, 12)
                    MeQuickGrid()
                        .padding(.top, 12)
                    MeMenuSections()
                        .padding(.top, 18)
                    logoutButton
                        .padding(.top, 18)
                    Spacer().frame(height: 96)
                }
            }
            .background(AKColor.bg.ignoresSafeArea())
            .navigationBarHidden(true)
            .alert("退出登录？", isPresented: $showLogout) {
                Button("取消", role: .cancel) {}
                Button("退出", role: .destructive) { app.logout() }
            }
        }
    }

    // MARK: - 资料头

    private var header: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                NavigationLink {
                    EditProfileView()
                } label: {
                    AvatarView(url: app.user?.avatar, name: displayName, size: 82)
                        .clipShape(Circle())
                        .padding(3)
                        .overlay(
                            Circle().strokeBorder(headerAccent.opacity(0.72), lineWidth: 1.2)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                HStack(spacing: 5) {
                    Text(displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(headerAccent)
                        .lineLimit(1)
                    if !prettyNo.isEmpty {
                        PrettyBadge(number: prettyNo)
                    }
                    if vipLevel > 0 {
                        VipBadge(level: vipLevel)
                    }
                }
                .padding(.top, 9)

                Button {
                    UIPasteboard.general.string = number
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    HStack(spacing: 5) {
                        Text("AK号：\(number)")
                            .font(.system(size: 12.5))
                            .foregroundColor(premium ? Color.white.opacity(0.9) : AKColor.muted)
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundColor(premium ? Color.white.opacity(0.8) : AKColor.muted)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(premium ? Color.white.opacity(0.16) : AKColor.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 7)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 20)

            NavigationLink {
                EditProfileView()
            } label: {
                HStack(spacing: 1) {
                    Text("编辑资料")
                        .font(.system(size: 12))
                        .foregroundColor(premium ? Color.white.opacity(0.9) : AKColor.sub)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(premium ? Color.white.opacity(0.8) : AKColor.muted)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(premium ? Color.white.opacity(0.16) : AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(premium ? Color.white.opacity(0.2) : AKColor.line, lineWidth: 0.6)
                )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
            .padding(.top, 6)
        }
        .background(headerGradient.ignoresSafeArea(edges: .top))
    }

    // MARK: - 会员卡

    private struct VipBanner<Destination: View>: View {
        let vipLevel: Int
        let vipDays: Int
        @ViewBuilder let destination: () -> Destination

        private var accent: Color {
            if vipLevel == 2 { return Color(hex: 0xF3D27C) }
            if vipLevel == 1 { return Color(hex: 0xE9E2FF) }
            return AKColor.gold
        }

        private var border: Color {
            if vipLevel == 2 { return Color(hex: 0xD4AF37) }
            if vipLevel == 1 { return Color(hex: 0x9B8CFF) }
            return AKColor.line
        }

        private var bannerBg: LinearGradient {
            if vipLevel == 2 {
                return LinearGradient(colors: [Color(hex: 0x2B2418), Color(hex: 0x0D0B08)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            if vipLevel == 1 {
                return LinearGradient(colors: [Color(hex: 0x332A7A), Color(hex: 0x19154A)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            return LinearGradient(colors: [AKColor.cardAlt, AKColor.fill],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }

        var body: some View {
            NavigationLink {
                destination()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: vipLevel == 2 ? "star.fill" : "rosette")
                        .font(.system(size: 22))
                        .foregroundColor(vipLevel > 0 ? accent : AKColor.text)
                        .frame(width: 38, height: 38)
                        .background(vipLevel > 0 ? Color.white.opacity(0.2) : AKColor.fill)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vipLevel == 2 ? "至尊 SVIP" : (vipLevel == 1 ? "VIP 会员" : "开通会员"))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(accent)
                        Text(vipDays > 0 ? "剩余 \(vipDays) 天" : "解锁更多专属特权")
                            .font(.system(size: 12.5))
                            .foregroundColor(vipLevel > 0 ? Color.white.opacity(0.7) : AKColor.muted)
                    }
                    Spacer(minLength: 8)
                    Text(vipDays > 0 ? "续费" : "开通")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(vipLevel > 0 ? Color.white.opacity(0.16) : AKColor.fill)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(vipLevel > 0 ? Color.white.opacity(0.2) : AKColor.line,
                                                   lineWidth: 0.6)
                        )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .background(bannerBg)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(border.opacity(0.65), lineWidth: vipLevel > 0 ? 1 : 0.6)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
        }
    }

    // MARK: - 数据

    private var statsCard: some View {
        HStack(spacing: 0) {
            statCell("\(app.user?.coin ?? 0)", "K币")
            Rectangle().fill(AKColor.fill).frame(width: 0.5, height: 30)
            statCell("\(vipDays)", "会员天数")
        }
        .padding(.vertical, 18)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 14)
    }

    private func statCell(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(AKColor.gold)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(AKColor.muted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 四宫格

    /// 无输入子视图：AppState 发布触发外层 body 重算时，SwiftUI 发现入参未变会跳过这整块
    private struct MeQuickGrid: View {
        var body: some View {
            HStack(spacing: 0) {
                quickLink("靓号商城", "rosette", Color(hex: 0x3B82F6)) { PrettyNumbersView() }
                quickLink("VIP 会员", "star.fill", AKColor.gold) { VipView() }
                quickLink("K币钱包", "creditcard.fill", Color(hex: 0x4BB8FF)) { WalletView() }
                quickLink("我的收藏", "gift.fill", Color(hex: 0xFF8A65)) { FavoritesView() }
            }
            .padding(.vertical, 16)
            .background(AKColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 14)
        }

        private func quickLink<D: View>(_ title: String, _ icon: String, _ color: Color,
                                        @ViewBuilder destination: () -> D) -> some View {
            NavigationLink {
                destination()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(
                            LinearGradient(colors: [color.opacity(0.82), color],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Text(title)
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.sub)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 分组

    private struct MeMenuSections: View {
        var body: some View {
            VStack(spacing: 0) {
                menuSection("账号与安全") {
                    NavigationLink { EditProfileView() } label: {
                        menuCell("person.fill", Color(hex: 0x4C8DFF), "个人资料", trailing: "编辑")
                    }
                    .buttonStyle(.plain)
                    menuDivider
                    NavigationLink { PrivacySettingsView() } label: {
                        menuCell("lock.fill", Color(hex: 0x8B7CF6), "隐私设置")
                    }
                    .buttonStyle(.plain)
                }
                menuSection("我的服务") {
                    NavigationLink { NoticesView() } label: {
                        menuCell("megaphone.fill", Color(hex: 0xFF9F43), "官方公告")
                    }
                    .buttonStyle(.plain)
                    menuDivider
                    NavigationLink { CustomerServiceView() } label: {
                        menuCell("headphones", Color(hex: 0x2FA84F), "联系客服")
                    }
                    menuDivider
                    NavigationLink { InviteRewardView() } label: {
                        menuCell("giftcard.fill", Color(hex: 0xFF6B81), "邀请好友")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 14)
                menuSection("设置") {
                    NavigationLink { SettingsView() } label: {
                        menuCell("gearshape.fill", Color(hex: 0x6C8AE4), "设置", trailing: "通知 · 缓存")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 14)
            }
        }

        private func menuSection<Content: View>(_ title: String,
                                                @ViewBuilder content: () -> Content) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.muted)
                    .padding(.leading, 20)
                VStack(spacing: 0) { content() }
                    .background(AKColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 14)
            }
        }

        private var menuDivider: some View {
            Rectangle().fill(AKColor.line).frame(height: 0.5).padding(.leading, 62)
        }

        private func menuCell(_ icon: String, _ tint: Color, _ title: String,
                              trailing: String = "") -> some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 19))
                    .foregroundColor(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(AKColor.text)
                Spacer(minLength: 4)
                if !trailing.isEmpty {
                    Text(trailing)
                        .font(.system(size: 12.5))
                        .foregroundColor(AKColor.muted)
                        .padding(.trailing, 4)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 15))
                    .foregroundColor(AKColor.placeholder)
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
    }

    private var logoutButton: some View {
        Button(role: .destructive) {
            showLogout = true
        } label: {
            Text("退出登录")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AKColor.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(AKColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 14)
        }
    }
}

/// 一处圆角：整组列表的首行 / 末行各自带圆角，中间行直角，拼成安卓同款圆角卡
struct AKCornerShape: Shape {
    var top: Bool
    var bottom: Bool
    var radius: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        let tl = top ? radius : 0
        let tr = top ? radius : 0
        let br = bottom ? radius : 0
        let bl = bottom ? radius : 0
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        if tr > 0 {
            p.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr,
                     startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        if br > 0 {
            p.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br,
                     startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        }
        p.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        if bl > 0 {
            p.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl,
                     startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        }
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        if tl > 0 {
            p.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl,
                     startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }
        p.closeSubpath()
        return p
    }
}

extension View {
    /// List 行内画安卓式卡片底：top/bottom 决定该行是否带圆角
    func akCardRow(top: Bool = false, bottom: Bool = false, radius: CGFloat = 14) -> some View {
        background(AKCornerShape(top: top, bottom: bottom, radius: radius).fill(AKColor.card))
    }
}
