import SwiftUI

/// 广场：朋友圈 / 扫一扫 / 邀请有礼 / 我的收藏 / 系统公告（对齐安卓 DiscoverScreen）
struct DiscoverView: View {
    @EnvironmentObject private var app: AppState
    @State private var showScanner = false
    @State private var showInvite = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        MomentsView()
                    } label: {
                        HStack(spacing: 12) {
                            icon("photo.on.rectangle.angled", AKColor.brand)
                            Text("朋友圈").foregroundColor(AKColor.text)
                            Spacer()
                            if let avatar = app.user?.avatar, let u = APIClient.fullURL(avatar) {
                                AsyncImage(url: u) { phase in
                                    if let img = phase.image { img.resizable().scaledToFill() } else { AKColor.fill }
                                }
                                .frame(width: 30, height: 30)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            }
                            if app.conversations.contains(where: { $0.convType == "moment" && $0.unread > 0 }) {
                                Circle().fill(AKColor.red).frame(width: 8, height: 8)
                            }
                        }
                    }
                    Button {
                        showScanner = true
                    } label: {
                        HStack(spacing: 12) {
                            icon("qrcode.viewfinder", AKColor.link)
                            Text("扫一扫").foregroundColor(AKColor.text)
                            Spacer()
                        }
                    }
                    Button {
                        showInvite = true
                    } label: {
                        HStack(spacing: 12) {
                            icon("gift.fill", Color(hex: 0xFF8A5C))
                            Text("邀请有礼").foregroundColor(AKColor.text)
                            Spacer()
                        }
                    }
                }

                Section {
                    NavigationLink {
                        FavoritesView()
                    } label: {
                        HStack(spacing: 12) {
                            icon("star.circle.fill", AKColor.gold)
                            Text("我的收藏").foregroundColor(AKColor.text)
                            Spacer()
                        }
                    }
                    NavigationLink {
                        NoticesView()
                    } label: {
                        HStack(spacing: 12) {
                            icon("megaphone.fill", Color(hex: 0x8B7BF0))
                            Text("系统公告").foregroundColor(AKColor.text)
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("广场")
            .fullScreenCover(isPresented: $showScanner) {
                ScannerView()
            }
            .sheet(isPresented: $showInvite) {
                NavigationStack { InviteView() }
            }
        }
    }

    private func icon(_ name: String, _ color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 17))
            .foregroundColor(.white)
            .frame(width: 38, height: 38)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
