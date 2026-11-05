import SwiftUI

struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    let uid: Int64
    var presetName: String = ""

    @State private var profile: UserProfile?
    @State private var loading = true
    @State private var error: String?
    @State private var info: String?
    @State private var showRemark = false
    @State private var showQR = false
    @State private var remarkText = ""
    @State private var showDelete = false
    @State private var showChat = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if loading {
                    ProgressView().padding(.top, 60)
                } else if let p = profile {
                    header(p)
                    actionRow(p)
                    detailCard(p)
                } else {
                    Text(error ?? "加载失败")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.muted)
                        .padding(.top, 60)
                }
                if let info {
                    Text(info).font(.system(size: 12)).foregroundColor(AKColor.sub)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let error, profile != nil {
                    Text(error).font(.system(size: 12)).foregroundColor(AKColor.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .background(AKColor.bg)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showQR) {
            if let p = profile {
                QRCodeView(uid: p.id, name: p.remark.isEmpty ? p.nickname : p.remark, avatar: p.avatar)
            }
        }
        .sheet(isPresented: $showChat) {
            if let p = profile {
                NavigationStack {
                    ChatView(convType: "private", convId: p.id, title: p.displayName)
                }
            }
        }
        .alert("设置备注", isPresented: $showRemark) {
            TextField("备注名", text: $remarkText)
            Button("取消", role: .cancel) {}
            Button("保存") {
                Task {
                    await APIClient.shared.setRemark(userId: uid, remark: remarkText.trimmingCharacters(in: .whitespaces))
                    await load()
                    info = "备注已保存"
                }
            }
        }
        .alert("删除好友？", isPresented: $showDelete) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                Task {
                    await APIClient.shared.deleteFriend(userId: uid)
                    info = "已删除好友"
                    await load()
                }
            }
        } message: {
            Text("聊天记录会保留在会话列表。")
        }
    }

    private func header(_ p: UserProfile) -> some View {
        VStack(spacing: 10) {
            AvatarView(url: p.avatar, name: p.displayName, size: 76)
            HStack(spacing: 5) {
                Text(p.displayName)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(akNameColor(vipLevel: p.vipLevel, isPretty: p.isPretty, isGroup: false))
                if p.vipLevel > 0 { VipBadge(level: p.vipLevel) }
                if p.isPretty == 1 { PrettyBadge(number: p.prettyYxid) }
                if p.isBot == 1 {
                    BadgeView(text: "AI机器人", color: AKColor.link, background: AKColor.blueSoft)
                }
            }
            Text("AK号：\(p.showYxid.isEmpty ? p.yxId : p.showYxid)")
                .font(.system(size: 12))
                .foregroundColor(AKColor.muted)
            if !p.bio.isEmpty {
                Text(p.bio)
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.sub)
                    .multilineTextAlignment(.center)
            }
            if p.online == 1 {
                HStack(spacing: 4) {
                    Circle().fill(AKColor.brand).frame(width: 6, height: 6)
                    Text("在线").font(.system(size: 11)).foregroundColor(AKColor.brand)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func actionRow(_ p: UserProfile) -> some View {
        HStack(spacing: 10) {
            if p.isSelf == 0 {
                Button {
                    showChat = true
                } label: {
                    actionLabel("发消息", "bubble.left.fill", AKColor.brand)
                }
                Button {
                    remarkText = p.remark
                    showRemark = true
                } label: {
                    actionLabel("备注", "square.and.pencil", AKColor.link)
                }
                Button {
                    showQR = true
                } label: {
                    actionLabel("二维码", "qrcode", AKColor.gold)
                }
            }
            if p.isBlocked == 1 {
                Button {
                    Task {
                        await APIClient.shared.blockUser(uid: uid, act: "remove")
                        await load()
                        info = "已取消拉黑"
                    }
                } label: {
                    actionLabel("取消拉黑", "hand.raised.slash.fill", AKColor.gold)
                }
            } else if p.isSelf == 0 {
                Button {
                    Task {
                        await APIClient.shared.blockUser(uid: uid, act: "add")
                        await load()
                        info = "已加入黑名单"
                    }
                } label: {
                    actionLabel("拉黑", "hand.raised.fill", AKColor.sub)
                }
            }
        }
    }

    private func actionLabel(_ title: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundColor(color)
                .frame(width: 44, height: 40)
                .background(AKColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(title).font(.system(size: 11)).foregroundColor(AKColor.sub)
        }
        .frame(maxWidth: .infinity)
    }

    private func detailCard(_ p: UserProfile) -> some View {
        VStack(spacing: 0) {
            if !p.remark.isEmpty {
                infoRow("备注", p.remark)
                Divider().padding(.leading, 14)
            }
            infoRow("AK号", p.showYxid.isEmpty ? p.yxId : p.showYxid)
            if !p.vipExpireText.isEmpty && p.vipLevel > 0 {
                Divider().padding(.leading, 14)
                infoRow("会员到期", p.vipExpireText)
            }
            if p.isFriend == 1 && p.isSelf == 0 {
                Divider().padding(.leading, 14)
                Button {
                    showDelete = true
                } label: {
                    HStack {
                        Text("删除好友").font(.system(size: 14)).foregroundColor(AKColor.red)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                }
            }
        }
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.system(size: 14)).foregroundColor(AKColor.sub)
            Spacer()
            Text(value).font(.system(size: 14)).foregroundColor(AKColor.text).lineLimit(1)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            profile = try await APIClient.shared.userProfile(id: uid)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
