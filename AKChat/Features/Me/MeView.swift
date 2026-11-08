import SwiftUI

/// 我的：深色资料头 + 会员卡 + 数据 + 四宫格入口 + 账号与安全（对齐安卓 MeScreen）
struct MeView: View {
    @EnvironmentObject private var app: AppState
    @State private var showLogout = false
    @State private var showEdit = false
    @State private var copied = false

    private var displayName: String { app.user?.displayName ?? "未登录" }
    private var number: String { app.user?.displayNo ?? "-" }
    private var vipLevel: Int { app.user?.vipLevel ?? 0 }
    private var vipDays: Int { app.user?.vipDays ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    header
                    memberCard
                    statsCard
                    quickGrid
                    infoSection
                    serviceSection
                    logoutButton
                }
                .padding(.bottom, 18)
            }
            .background(AKColor.bg.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showEdit) {
                NavigationStack { EditProfileView() }
                    .environmentObject(app)
            }
            .alert("退出登录？", isPresented: $showLogout) {
                Button("取消", role: .cancel) {}
                Button("退出", role: .destructive) { app.logout() }
            }
        }
    }

    // MARK: - 深色资料头

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Button {
                    showEdit = true
                } label: {
                    HStack(spacing: 3) {
                        Text("编辑资料").font(.system(size: 12.5))
                        Image(systemName: "chevron.right").font(.system(size: 10))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Color.white.opacity(0.16))
                    .clipShape(Capsule())
                }
            }

            ZStack {
                Circle()
                    .stroke(LinearGradient(colors: [Color(hex: 0xFFE9A8), Color(hex: 0xD8A93A)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 2)
                    .frame(width: 82, height: 82)
                AvatarView(url: app.user?.avatar, name: displayName, size: 74)
            }

            HStack(spacing: 6) {
                Text(displayName)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(Color(hex: 0xF3E4B7))
                if app.user?.prettyYxid?.isEmpty == false {
                    BadgeView(text: "靓 \(app.user?.prettyYxid ?? "")", color: Color(hex: 0xB03A3A), background: Color(hex: 0x2A1414))
                }
                if vipLevel > 0 {
                    BadgeView(text: vipLevel >= 2 ? "SVIP" : "VIP", color: Color(hex: 0xE4C87A), background: Color(hex: 0x2B2415))
                }
            }

            Button {
                UIPasteboard.general.string = number
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            } label: {
                HStack(spacing: 6) {
                    Text("AK号：\(number)").font(.system(size: 13))
                    Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.system(size: 11))
                }
                .foregroundColor(.white.opacity(0.92))
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(Color.white.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color(hex: 0x2A2A2C), Color(hex: 0x141416)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - 会员卡

    private var memberCard: some View {
        NavigationLink {
            VipView()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color(hex: 0x141416)).frame(width: 44, height: 44)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: 0xE7C066))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(vipLevel >= 2 ? "至尊 SVIP" : (vipLevel == 1 ? "VIP 会员" : "开通会员"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: 0xF0DCA4))
                    Text(vipLevel > 0 ? "剩余 \(vipDays) 天" : "解锁靓号标识与专属特权")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Text(vipLevel > 0 ? "续费" : "开通")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: 0xF0DCA4))
                    .padding(.horizontal, 16)
                    .frame(height: 32)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                LinearGradient(colors: [Color(hex: 0x2B2A28), Color(hex: 0x141414)],
                               startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 12)
        }
    }

    // MARK: - 数据

    private var statsCard: some View {
        HStack {
            VStack(spacing: 4) {
                Text("\(app.user?.coin ?? 0)")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Color(hex: 0xE0A93B))
                Text("K币").font(.system(size: 12)).foregroundColor(AKColor.muted)
            }
            .frame(maxWidth: .infinity)
            Rectangle().fill(AKColor.line).frame(width: 0.5, height: 36)
            VStack(spacing: 4) {
                Text("\(vipDays)")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Color(hex: 0xE0A93B))
                Text("会员天数").font(.system(size: 12)).foregroundColor(AKColor.muted)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
    }

    // MARK: - 四宫格

    private var quickGrid: some View {
        HStack(spacing: 0) {
            quickLink("靓号商城", "number.square.fill", Color(hex: 0x5B8DEF)) { PrettyNumbersView() }
            quickLink("VIP 会员", "star.circle.fill", Color(hex: 0xF0B429)) { VipView() }
            quickLink("K币钱包", "creditcard.fill", Color(hex: 0x5AB8F0)) { WalletView() }
            quickLink("我的收藏", "gift.fill", Color(hex: 0xF08A6C)) { FavoritesView() }
        }
        .padding(.vertical, 14)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
    }

    private func quickLink<D: View>(_ title: String, _ icon: String, _ color: Color,
                                    @ViewBuilder destination: () -> D) -> some View {
        NavigationLink {
            destination()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 19))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(title).font(.system(size: 11.5)).foregroundColor(AKColor.sub)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 分组

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("账号与安全")
                .font(.system(size: 12.5))
                .foregroundColor(AKColor.muted)
                .padding(.leading, 18)
            VStack(spacing: 0) {
                Button { showEdit = true } label: {
                    row("个人资料", "编辑", "person.fill", Color(hex: 0x5B8DEF))
                }
                divider
                NavigationLink { PrivacySettingsView() } label: {
                    row("隐私设置", "", "lock.fill", Color(hex: 0x8B7BF0))
                }
            }
            .background(AKColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 12)
        }
    }

    private var serviceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("我的服务")
                .font(.system(size: 12.5))
                .foregroundColor(AKColor.muted)
                .padding(.leading, 18)
            VStack(spacing: 0) {
                NavigationLink {
                    PosterView(name: displayName, avatar: app.user?.avatar, number: number, uid: app.user?.id ?? 0)
                } label: { row("我的海报", "", "square.and.arrow.up", Color(hex: 0x5AB8F0)) }
                divider
                NavigationLink { SettingsView() } label: { row("设置", "", "gearshape.fill", Color(hex: 0x9AA0AC)) }
                divider
                NavigationLink { NoticesView() } label: { row("系统公告", "", "megaphone.fill", Color(hex: 0x8B7BF0)) }
                divider
                Link(destination: URL(string: "https://www.aksliao.cn/service.php")!) {
                    row("帮助与客服", "", "questionmark.circle.fill", Color(hex: 0x5B8DEF))
                }
            }
            .background(AKColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 12)
        }
    }

    private var divider: some View {
        Rectangle().fill(AKColor.line).frame(height: 0.5).padding(.leading, 56)
    }

    private var logoutButton: some View {
        Button(role: .destructive) {
            showLogout = true
        } label: {
            Text("退出登录")
                .font(.system(size: 15))
                .foregroundColor(AKColor.red)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(AKColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 12)
        }
    }

    private func row(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title).font(.system(size: 14.5)).foregroundColor(AKColor.text)
            Spacer()
            if !value.isEmpty {
                Text(value).font(.system(size: 13)).foregroundColor(AKColor.muted)
            }
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(AKColor.hint)
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .contentShape(Rectangle())
    }
}
