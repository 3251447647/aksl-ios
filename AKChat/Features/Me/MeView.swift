import SwiftUI

struct MeView: View {
    @EnvironmentObject private var app: AppState
    @State private var showLogout = false
    @State private var showEdit = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        AvatarView(url: app.user?.avatar, name: app.user?.displayName ?? "我", size: 62)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(app.user?.displayName ?? "未登录")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(AKColor.text)
                                if let vip = app.user?.vipLevel, vip > 0 {
                                    BadgeView(text: vip >= 2 ? "SVIP" : "VIP")
                                }
                            }
                            Text("AK号：\(app.user?.displayNo ?? "-")")
                                .font(.system(size: 12)).foregroundColor(AKColor.muted)
                            if let bio = app.user?.bio, !bio.isEmpty {
                                Text(bio).font(.system(size: 12)).foregroundColor(AKColor.sub).lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .onTapGesture { showEdit = true }
                }

                Section {
                    NavigationLink { WalletView() } label: { row("钱包", "K币 \(app.user?.coin ?? 0)", "creditcard") }
                    NavigationLink { VipView() } label: { row("会员中心", (app.user?.vipLevel ?? 0) > 0 ? "VIP\(app.user?.vipLevel ?? 0)" : "未开通", "crown") }
                    NavigationLink { FavoritesView() } label: { row("我的收藏", "", "star") }
                    NavigationLink { PrettyNumbersView() } label: { row("我的靓号", (app.user?.prettyYxid?.isEmpty == false) ? (app.user?.prettyYxid ?? "") : "未拥有", "number") }
                }

                Section {
                    NavigationLink { SettingsView() } label: { row("设置", "", "gearshape") }
                    NavigationLink { NoticesView() } label: { row("公告", "", "megaphone") }
                    Link(destination: URL(string: "https://www.aksliao.cn/service.php")!) {
                        row("帮助与客服", "", "questionmark.circle")
                    }
                    Link(destination: URL(string: "https://www.aksliao.cn/about.php")!) {
                        row("关于 AK商聊", "", "info.circle")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showLogout = true
                    } label: {
                        Text("退出登录").frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("我的")
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

    private func row(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(AKColor.brand)
                .frame(width: 28, height: 28)
                .background(AKColor.brandSoft)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title).foregroundColor(AKColor.text)
            Spacer()
            Text(value).font(.system(size: 13)).foregroundColor(AKColor.muted)
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(AKColor.hint)
        }
    }
}
