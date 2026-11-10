import SwiftUI
import PhotosUI

/// 用户主页：会员渐变资料卡 + 个性签名 + 朋友圈入口 + 聊天记录入口 + 底部操作栏（对齐安卓 UserProfileScreen）
struct UserProfileView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let uid: Int64
    /// 群聊里打开时带上 gid：服务端据此返回群内身份/管理权限（安卓同参数）
    var gid: Int64 = 0
    var presetName: String = ""

    @State private var profile: UserProfile?
    @State private var loading = true
    @State private var error: String?
    @State private var showSettings = false
    @State private var showRemark = false
    @State private var remarkText = ""
    @State private var showDelete = false
    @State private var showChat = false
    @State private var showCall = false
    @State private var showAddFriend = false
    @State private var showNotFriend = false
    @State private var showBlockConfirm = false
    @State private var showReport = false
    @State private var showSharePicker = false
    @State private var reportReason = ""
    @State private var reportNote = ""
    @State private var toastText: String?
    @State private var verifyMsg = "你好，我们在同一个群"
    @State private var chatBg: String = ""
    @State private var showBgPicker = false
    @State private var bgItem: PhotosPickerItem?
    /// /api/v1/user 返回的群内身份与权限（仅群内打开时有值）
    @State private var group: ProfileGroup?
    @State private var showGroupNick = false
    @State private var groupNickText = ""
    @State private var showMuteMenu = false
    @State private var showKick = false
    @State private var adminBusy = false
    @State private var adminOverride: Bool?

    /// 群上下文 id：群内打开用服务端下发的 gid，群外为 0
    private var groupId: Int64 { group?.gid ?? gid }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    if loading {
                        ProgressView().padding(.top, 60)
                    } else if let p = profile {
                        hero(p)
                        if !p.bio.isEmpty { bioCard(p) }
                        momentsCell(p)
                        if p.isSelf == 0 && p.isFriend == 1 { chatSearchRow(p) }
                        if let g = group { groupCard(p, g) }
                    } else {
                        Text(error ?? "加载失败")
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.muted)
                            .padding(.top, 60)
                    }
                }
                .padding(.bottom, 16)
            }
            if let p = profile {
                actionBar(p)
            }
        }
        .background(AKColor.bg)
        .overlay(alignment: .bottom) { toastView }
        .reportsDetailPage()
        .navigationTitle(profile?.isSelf == 1 ? "我的主页" : "个人主页")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if let p = profile, p.isSelf == 0 {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                            .foregroundColor(AKColor.text)
                    }
                }
            }
        }
        .task { await load() }
        .fullScreenCover(isPresented: $showCall) {
            CallScreen()
        }
        .photosPicker(isPresented: $showBgPicker, selection: $bgItem, matching: .images)
        .onChange(of: bgItem) { item in
            guard let item else { return }
            Task {
                defer { bgItem = nil }
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else { return }
                    let up = try await APIClient.shared.upload(data: data, filename: "bg.jpg", kind: "bg")
                    let r = try await APIClient.shared.setChatBg(convType: "private", convId: uid, url: up.url)
                    await MainActor.run { chatBg = r.bg ?? "" }
                } catch let err {
                    await MainActor.run { error = err.localizedDescription }
                }
            }
        }
        .navigationDestination(isPresented: $showSettings) {
            settingsPage
                .reportsDetailPage()
                .restoresSwipeBack()
        }
        .sheet(isPresented: $showSharePicker) {
            CardSharePickerView(kind: "user", cardId: uid, cardName: profile?.displayName ?? presetName) { showToast($0) }
        }
        .sheet(isPresented: $showReport) {
            reportSheet
        }
        .navigationDestination(isPresented: $showChat) {
            if let p = profile {
                ChatView(convType: "private", convId: p.id, title: p.displayName)
            }
        }
        .alert("加为好友", isPresented: $showAddFriend) {
            TextField("填写验证信息", text: $verifyMsg)
            Button("取消", role: .cancel) {}
            Button("发送") {
                Task {
                    let msg = verifyMsg.trimmingCharacters(in: .whitespaces)
                    if msg.isEmpty {
                        showToast("请填写验证信息")
                        return
                    }
                    do {
                        _ = try await APIClient.shared.postRaw(
                            "api/v1/friends/add",
                            body: ["to_uid": uid, "message": msg]
                        )
                        showToast("申请已发送")
                        await load()
                    } catch let err {
                        showToast(err.localizedDescription)
                    }
                }
            }
        } message: {
            Text("对方：\(profile?.displayName ?? presetName)")
        }
        .alert("还不是好友", isPresented: $showNotFriend) {
            Button("取消", role: .cancel) {}
            Button("加为好友") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showAddFriend = true
                }
            }
        } message: {
            Text("添加好友后才能发消息，现在发送好友申请？")
        }
        .alert("删除好友", isPresented: $showDelete) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                Task {
                    do {
                        _ = try await APIClient.shared.postRaw("api/v1/friend/delete", body: ["user_id": uid])
                        showToast("已删除好友")
                        dismiss()
                    } catch let err {
                        showToast(err.localizedDescription)
                    }
                }
            }
        } message: {
            Text("将删除「\(profile?.displayName ?? presetName)」并清空聊天记录，此操作不可恢复。")
        }
    }

    // MARK: - 资料卡

    private func hero(_ p: UserProfile) -> some View {
        let svip = p.vipLevel == 2
        let vip = p.vipLevel == 1
        let premium = svip || vip
        let accent: Color = svip ? Color(hex: 0xF3D27C)
            : (vip ? Color(hex: 0xE9E2FF) : (p.isPretty == 1 ? Color(hex: 0xFFE0A6) : AKColor.text))
        let border: Color = svip ? Color(hex: 0xD4AF37) : (vip ? Color(hex: 0x9B8CFF) : AKColor.line)

        return HStack(alignment: .top, spacing: 14) {
            AvatarView(url: p.avatar, name: p.displayName, size: 70)
                .padding(3)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(accent.opacity(0.75), lineWidth: 1.2)
                )
            VStack(alignment: .leading, spacing: 0) {
                heroNameRow(p, accent: accent)
                if !p.remark.isEmpty {
                    Text("昵称：\(p.nickname)")
                        .font(.system(size: 11.5))
                        .foregroundColor(premium ? Color.white.opacity(0.7) : AKColor.placeholder)
                        .lineLimit(1)
                        .padding(.top, 4)
                }
                heroPills(p, premium: premium, accent: accent)
                    .padding(.top, 8)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(heroBackground(p))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(border.opacity(premium ? 0.72 : 0.5), lineWidth: premium ? 1 : 0.6)
        )
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }

    private func heroNameRow(_ p: UserProfile, accent: Color) -> some View {
        HStack(spacing: 4) {
            Text(p.displayName)
                .font(.system(size: titleSize(p.displayName), weight: .bold))
                .foregroundColor(accent)
                .lineLimit(1)
            if p.isPretty == 1 {
                PrettyBadge(number: p.prettyYxid)
            }
            if p.vipLevel > 0 {
                VipBadge(level: p.vipLevel)
            }
            if p.isBot == 1 {
                BadgeView(text: "AI机器人", color: AKColor.link, background: AKColor.blueSoft)
            }
        }
    }

    private func heroPills(_ p: UserProfile, premium: Bool, accent: Color) -> some View {
        HStack(spacing: 6) {
            Text(p.isPretty == 1 ? "靓号：\(showNumber(p))" : "AK号：\(showNumber(p))")
                .font(.system(size: 11.5, weight: p.isPretty == 1 ? .bold : .regular))
                .foregroundColor(numberColor(p, premium: premium, accent: accent))
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(premium ? Color.white.opacity(0.13) : AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            HStack(spacing: 5) {
                Circle()
                    .fill(p.online == 1 ? Color(hex: 0x34D399) : AKColor.placeholder)
                    .frame(width: 5, height: 5)
                Text(p.online == 1 ? "在线" : "离线")
                    .font(.system(size: 10.5))
                    .foregroundColor(onlineColor(p, premium: premium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(onlineBackground(p, premium: premium))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func numberColor(_ p: UserProfile, premium: Bool, accent: Color) -> Color {
        if premium { return accent }
        return p.isPretty == 1 ? AKColor.gold : AKColor.sub
    }

    private func onlineColor(_ p: UserProfile, premium: Bool) -> Color {
        if premium { return Color.white.opacity(0.8) }
        return p.online == 1 ? Color(hex: 0x22C55E) : AKColor.muted
    }

    private func onlineBackground(_ p: UserProfile, premium: Bool) -> Color {
        if premium { return Color.white.opacity(0.12) }
        return p.online == 1 ? AKColor.brandSoft : AKColor.fill
    }

    @ViewBuilder
    private func heroBackground(_ p: UserProfile) -> some View {
        if p.vipLevel == 2 {
            LinearGradient(colors: [Color(hex: 0x2B2418), Color(hex: 0x0D0B08)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if p.vipLevel == 1 {
            LinearGradient(colors: [Color(hex: 0x332A7A), Color(hex: 0x19154A)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            AKColor.card
        }
    }

    private func showNumber(_ p: UserProfile) -> String {
        p.showYxid.isEmpty ? p.yxId : p.showYxid
    }

    private func titleSize(_ name: String) -> CGFloat {
        var units: CGFloat = 0
        for ch in name {
            units += ch.unicodeScalars.first.map { $0.value > 127 } == true ? 1 : 0.55
        }
        let base: CGFloat = 19
        let minSize: CGFloat = 11
        let full: CGFloat = 16
        let floor = full * 2.2
        if units <= full { return base }
        if units >= floor { return minSize }
        return base - (base - minSize) * ((units - full) / (floor - full))
    }

    private func bioCard(_ p: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("个性签名")
                .font(.system(size: 12))
                .foregroundColor(AKColor.muted)
            Text(linkified(p.bio))
                .font(.system(size: 13.5))
                .foregroundColor(AKColor.text)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                // 签名里的链接统一走内置浏览器，tel: 等交给系统
                .environment(\.openURL, OpenURLAction { url in
                    AppLinkRouter.open(url)
                    return .handled
                })
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(AKColor.card)
    }

    /// 链接 / 号码可点（对齐安卓 LinkifiedText）
    private func linkified(_ text: String) -> AttributedString {
        var out = AttributedString(text)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue
                                                 | NSTextCheckingResult.CheckingType.phoneNumber.rawValue) else {
            return out
        }
        let full = text as NSString
        detector.enumerateMatches(in: text, range: NSRange(location: 0, length: full.length)) { result, _, _ in
            guard let result else { return }
            let target: String?
            if let url = result.url {
                // 裸域名被 NSDataDetector 补成 http，内置浏览器会白屏，改补 https
                let raw = full.substring(with: result.range)
                target = raw.lowercased().hasPrefix("http") ? url.absoluteString : "https://" + raw
            } else if let phone = result.phoneNumber {
                target = "tel:" + phone
            } else {
                target = nil
            }
            guard let target, let url = URL(string: target) else { return }
            if let range = Range(result.range, in: text),
               let attRange = out.range(of: String(text[range])) {
                out[attRange].link = url
            }
        }
        return out
    }

    private func momentsCell(_ p: UserProfile) -> some View {
        NavigationLink {
            MomentsView()
        } label: {
            HStack(spacing: 6) {
                Text("朋友圈")
                    .font(.system(size: 15.5))
                    .foregroundColor(AKColor.text)
                Spacer(minLength: 0)
                if p.moments.isEmpty {
                    Text("TA 还没有发布过动态")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.placeholder)
                } else {
                    HStack(spacing: 4) {
                        ForEach(p.moments.prefix(4)) { m in
                            momentThumb(m)
                        }
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.placeholder)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(AKColor.card)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func momentThumb(_ m: ProfileMoment) -> some View {
        if !m.img.isEmpty, let url = APIClient.fullURL(m.img) {
            AsyncImage(url: url) { phase in
                if let img = phase.image {
                    img.resizable().scaledToFill()
                } else {
                    AKColor.line
                }
            }
            .frame(width: 44, height: 44)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            Text(m.text)
                .font(.system(size: 8))
                .foregroundColor(AKColor.placeholder)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(width: 44, height: 44)
                .background(AKColor.line)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    private func chatSearchRow(_ p: UserProfile) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(AKColor.line).frame(height: 0.6)
            NavigationLink {
                MessageSearchView(scopeType: "private", scopeId: p.id, scopeTitle: p.displayName)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(AKColor.sub)
                    Text("查找聊天记录")
                        .font(.system(size: 15))
                        .foregroundColor(AKColor.text)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(AKColor.placeholder)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 15)
                .background(AKColor.card)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// 群资料卡（对齐安卓 UserProfileScreen 的 group 段）
    private func groupCard(_ p: UserProfile, _ g: ProfileGroup) -> some View {
        VStack(spacing: 0) {
            if p.isSelf == 1 {
                Button {
                    showSettings = true
                } label: {
                    groupInfoRow("我在本群的昵称",
                                 value: g.targetNick.isEmpty ? "未设置" : g.targetNick,
                                 arrow: true, danger: false)
                }
                .buttonStyle(.plain)
            } else {
                groupInfoRow("群昵称",
                             value: g.targetNick.isEmpty ? "未设置" : g.targetNick,
                             arrow: false, danger: false)
                if g.muteUntil > 0 {
                    groupDivider
                    groupInfoRow("禁言状态",
                                 value: g.muteText.isEmpty ? "禁言中" : g.muteText,
                                 arrow: false, danger: true)
                }
                if g.canNick == 1 {
                    groupDivider
                    Button {
                        showSettings = true
                    } label: {
                        groupInfoRow("设置群昵称", value: "", arrow: true, danger: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(AKColor.card)
    }

    private var groupDivider: some View {
        Rectangle().fill(AKColor.line).frame(height: 0.6)
    }

    private func groupInfoRow(_ title: String, value: String, arrow: Bool, danger: Bool) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(AKColor.text)
            Spacer(minLength: 0)
            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 13))
                    .foregroundColor(danger ? AKColor.red : AKColor.muted)
                    .lineLimit(1)
                    .frame(maxWidth: 180, alignment: .trailing)
            }
            if arrow {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.placeholder)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .contentShape(Rectangle())
    }

    // MARK: - 底部操作

    @ViewBuilder
    private func actionBar(_ p: UserProfile) -> some View {
        VStack(spacing: 8) {
            if p.isSelf == 1 || p.isBot == 1 {
                primaryButton("发消息") { showChat = true }
            } else if p.isFriend == 1 {
                HStack(spacing: 0) {
                    callButton("语音通话", "phone.fill") {
                        showCall = true
                        Task {
                            await CallManager.shared.start(peerUid: p.id, name: p.displayName, avatar: p.avatar, type: 1)
                        }
                    }
                    Rectangle().fill(AKColor.brand.opacity(0.2)).frame(width: 0.8, height: 16)
                    callButton("视频通话", "video.fill") {
                        showCall = true
                        Task {
                            await CallManager.shared.start(peerUid: p.id, name: p.displayName, avatar: p.avatar, type: 2)
                        }
                    }
                }
                .frame(height: 44)
                .background(AKColor.brandSoft)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                primaryButton("发消息") { showChat = true }
            } else {
                primaryButton("加为好友") { showAddFriend = true }
                Button {
                    showNotFriend = true
                } label: {
                    Text("发消息")
                        .font(.system(size: 15))
                        .foregroundColor(AKColor.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(AKColor.fill)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AKColor.card)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(AKColor.brand)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func callButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 14.5, weight: .medium))
            }
            .foregroundColor(AKColor.brand)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 设置

    private var settingsPage: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                BackButton()
                    .frame(width: 34, height: 34)
                Spacer(minLength: 0)
            }
            .overlay(
                Text("设置")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AKColor.text)
            )
            .padding(.horizontal, 8)
            .frame(height: 46)
            .frame(maxWidth: .infinity)
            .background(AKColor.card)
            .overlay(alignment: .bottom) {
                Rectangle().fill(AKColor.line).frame(height: 0.5)
            }

            ScrollView {
                VStack(spacing: 0) {
                    if profile?.isFriend == 1 {
                        settingsTitle("好友设置")
                        settingsCard {
                            settingsRow("设置备注", value: profile?.remark ?? "", showArrow: true) {
                                remarkText = profile?.remark ?? ""
                                showRemark = true
                            }
                            settingsDivider
                            toggleRow("消息免打扰", key: "is_mute", on: profile?.isMute == 1)
                            settingsDivider
                            toggleRow("置顶聊天", key: "is_top", on: profile?.isTop == 1)
                        }
                    }

                    settingsTitle("聊天")
                    settingsCard {
                        settingsRow("聊天背景", value: chatBg.isEmpty ? "默认" : "已设置", showArrow: true) {
                            closeSettingsThen { showBgPicker = true }
                        }
                        settingsDivider
                        NavigationLink {
                            QRCodeView(uid: uid,
                                       name: profile?.displayName ?? presetName,
                                       avatar: profile?.avatar,
                                       number: profile?.showYxid.isEmpty == false ? (profile?.showYxid ?? "") : (profile?.yxId ?? ""),
                                       isPretty: profile?.isPretty == 1)
                        } label: {
                            settingsRowContent("我的二维码", value: "", showArrow: true, destructive: false)
                        }
                        .buttonStyle(.plain)
                        if !chatBg.isEmpty {
                            settingsDivider
                            Button {
                                Task {
                                    if let r = try? await APIClient.shared.setChatBg(convType: "private", convId: uid, url: "") {
                                        await MainActor.run { chatBg = r.bg ?? "" }
                                    }
                                }
                            } label: {
                                settingsRowContent("恢复默认背景", value: "", showArrow: false, destructive: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let g = group, g.canNick == 1 || g.canMute == 1 || g.canKick == 1
                        || (g.myRole == 1 && g.targetRole != 1) {
                        settingsTitle("群内设置")
                        settingsCard {
                            /* 群主可把普通成员设为管理员，已是管理员的可取消（与安卓同样的开关） */
                            if g.myRole == 1 && g.targetRole != 1 {
                                adminToggleRow(g)
                                settingsDivider
                            }
                            if g.canNick == 1 {
                                settingsRow("设置群昵称",
                                            value: g.targetNick.isEmpty ? "未设置" : g.targetNick,
                                            showArrow: true) {
                                    groupNickText = g.targetNick
                                    showGroupNick = true
                                }
                                .alert("设置群昵称", isPresented: $showGroupNick) {
                                    TextField("留空则显示昵称", text: $groupNickText)
                                    Button("取消", role: .cancel) {}
                                    Button("保存") {
                                        Task { await saveGroupNick() }
                                    }
                                } message: {
                                    Text("群昵称只在本群内显示，最多 16 个字。")
                                }
                                if g.canMute == 1 || g.canKick == 1 { settingsDivider }
                            }
                            if g.canMute == 1 {
                                Button {
                                    if g.muteUntil > 0 {
                                        Task { await mute(0) }
                                    } else {
                                        showMuteMenu = true
                                    }
                                } label: {
                                    settingsRowContent(g.muteUntil > 0 ? "解除禁言" : "禁言",
                                                       value: g.muteUntil > 0
                                                           ? (g.muteText.isEmpty ? "禁言中" : g.muteText) : "",
                                                       showArrow: true, destructive: false)
                                }
                                .buttonStyle(.plain)
                                .confirmationDialog("禁言", isPresented: $showMuteMenu,
                                                    titleVisibility: .visible) {
                                    Button("10 分钟") { Task { await mute(10) } }
                                    Button("1 小时") { Task { await mute(60) } }
                                    Button("1 天") { Task { await mute(1440) } }
                                    Button("永久") { Task { await mute(-1) } }
                                    Button("取消", role: .cancel) {}
                                } message: {
                                    Text("被禁言的成员在禁言期间无法在本群发言。")
                                }
                                if g.canKick == 1 { settingsDivider }
                            }
                            if g.canKick == 1 {
                                Button {
                                    showKick = true
                                } label: {
                                    settingsRowContent("踢出本群", value: "",
                                                       showArrow: false, destructive: true)
                                }
                                .buttonStyle(.plain)
                                .alert("踢出本群", isPresented: $showKick) {
                                    Button("取消", role: .cancel) {}
                                    Button("踢出", role: .destructive) {
                                        Task { await kick() }
                                    }
                                } message: {
                                    Text("确定把「\(profile?.displayName ?? presetName)」移出本群吗？")
                                }
                            }
                        }
                    }

                    settingsTitle("隐私")
                    settingsCard {
                        if profile?.isBlocked == 1 {
                            Button {
                                Task { await setBlocked(false) }
                            } label: {
                                settingsRowContent("取消拉黑", value: "", showArrow: false, destructive: false)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                showBlockConfirm = true
                            } label: {
                                settingsRowContent("拉黑", value: "", showArrow: false, destructive: true)
                            }
                            .buttonStyle(.plain)
                        }
                        if profile?.isFriend == 1 {
                            settingsDivider
                            Button {
                                closeSettingsThen { showDelete = true }
                            } label: {
                                settingsRowContent("删除好友", value: "", showArrow: false, destructive: true)
                            }
                            .buttonStyle(.plain)
                        }
                        settingsDivider
                        Button {
                            reportReason = ""
                            reportNote = ""
                            closeSettingsThen { showReport = true }
                        } label: {
                            settingsRowContent("举报该用户", value: "被骚扰了？点我", showArrow: false, destructive: true)
                        }
                        .buttonStyle(.plain)
                    }

                    if profile?.isFriend == 1 {
                        settingsTitle("推荐")
                        settingsCard {
                            Button {
                                closeSettingsThen { showSharePicker = true }
                            } label: {
                                settingsRowContent("分享好友名片", value: "", showArrow: false, destructive: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 14)
            }
            .background(AKColor.bg)
        }
        .background(AKColor.bg)
        .overlay(alignment: .bottom) { toastView }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .alert("设置备注", isPresented: $showRemark) {
            TextField("备注名", text: $remarkText)
            Button("取消", role: .cancel) {}
            Button("保存") {
                Task {
                    do {
                        _ = try await APIClient.shared.postRaw(
                            "api/v1/friend/remark",
                            body: ["user_id": uid, "remark": remarkText.trimmingCharacters(in: .whitespaces)]
                        )
                        await load()
                        showToast("备注已保存")
                    } catch let err {
                        showToast(err.localizedDescription)
                    }
                }
            }
        }
        .alert("拉黑", isPresented: $showBlockConfirm) {
            Button("取消", role: .cancel) {}
            Button("拉黑", role: .destructive) {
                Task {
                    await setBlocked(true)
                    showSettings = false
                }
            }
        } message: {
            Text("拉黑后对方将无法给你发送私聊消息、看不到你的动态，也无法添加你为好友。")
        }
    }

    private func settingsTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5))
            .foregroundColor(AKColor.hint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 6)
            .padding(.top, 18)
            .padding(.bottom, 8)
    }

    private func settingsCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func settingsRow(_ title: String, value: String = "", showArrow: Bool,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            settingsRowContent(title, value: value, showArrow: showArrow, destructive: false)
        }
        .buttonStyle(.plain)
    }

    private func settingsRowContent(_ title: String, value: String, showArrow: Bool,
                                    destructive: Bool) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(destructive ? AKColor.red : AKColor.text)
            Spacer(minLength: 0)
            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 13.5))
                    .foregroundColor(AKColor.muted)
                    .lineLimit(1)
                    .padding(.trailing, 2)
            }
            if showArrow {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.placeholder)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .contentShape(Rectangle())
    }

    private var settingsDivider: some View {
        Rectangle().fill(AKColor.line).frame(height: 0.6).padding(.leading, 16)
    }

    private func toggleRow(_ title: String, key: String, on: Bool) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(AKColor.text)
            Spacer(minLength: 0)
            Toggle("", isOn: Binding(
                get: { on },
                set: { want in
                    Task {
                        await APIClient.shared.convSet(convType: "private", convId: uid,
                                                       key: key, value: want ? 1 : 0)
                        await load()
                        await app.refreshConversations()
                    }
                }
            ))
            .labelsHidden()
            .tint(AKColor.brand)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
    }

    /// 群主专属：设为/取消群管理员（对齐安卓开关式交互）
    private func adminToggleRow(_ g: ProfileGroup) -> some View {
        HStack(spacing: 6) {
            Text("设为群管理员")
                .font(.system(size: 15))
                .foregroundColor(AKColor.text)
            Spacer(minLength: 0)
            Toggle("", isOn: Binding(
                get: { adminOverride ?? (g.targetRole == 2) },
                set: { want in
                    guard !adminBusy else { return }
                    adminBusy = true
                    adminOverride = want
                    Task { await setAdmin(want) }
                }
            ))
            .labelsHidden()
            .tint(AKColor.brand)
            .disabled(adminBusy)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
    }

    // MARK: - 群内管理

    private func setAdmin(_ on: Bool) async {
        do {
            let msg = try await APIClient.shared.postRaw(
                "api/v1/group/set-admin",
                body: ["id": groupId, "uid": uid, "role": on ? 2 : 0]
            )
            showToast(msg.isEmpty ? (on ? "已设为管理员" : "已取消管理员") : msg)
            await load()
        } catch let err {
            adminOverride = !on
            showToast(err.localizedDescription)
        }
        adminBusy = false
    }

    private func mute(_ minutes: Int) async {
        do {
            let msg = try await APIClient.shared.postRaw(
                "api/v1/group/member/mute",
                body: ["gid": groupId, "user_id": uid, "minutes": minutes]
            )
            showToast(msg.isEmpty ? (minutes == 0 ? "已解除禁言" : "已禁言") : msg)
            await load()
        } catch let err {
            showToast(err.localizedDescription)
        }
    }

    private func kick() async {
        do {
            let msg = try await APIClient.shared.postRaw(
                "api/v1/group/member/kick",
                body: ["gid": groupId, "user_id": uid]
            )
            showToast(msg.isEmpty ? "已移出群聊" : msg)
            showSettings = false
            await load()
        } catch let err {
            showToast(err.localizedDescription)
        }
    }

    private func saveGroupNick() async {
        let nick = String(groupNickText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(16))
        do {
            let msg = try await APIClient.shared.postRaw(
                "api/v1/group/member/nick",
                body: ["gid": groupId, "user_id": uid, "nickname": nick]
            )
            showToast(msg.isEmpty ? "群昵称已保存" : msg)
            await load()
        } catch let err {
            showToast(err.localizedDescription)
        }
    }

    private var reportSheet: some View {
        VStack(spacing: 0) {
            reportHeader
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("请选择举报原因")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.muted)
                    ForEach(reportReasons, id: \.self) { reason in
                        Button {
                            reportReason = reason
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: reportReason == reason ? "largecircle.fill.circle" : "circle")
                                    .font(.system(size: 17))
                                    .foregroundColor(reportReason == reason ? AKColor.brand : AKColor.hint)
                                Text(reason)
                                    .font(.system(size: 14))
                                    .foregroundColor(AKColor.text)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Text("补充说明（选填）")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.muted)
                        .padding(.top, 6)
                    TextField("请描述具体情况…", text: $reportNote, axis: .vertical)
                        .font(.system(size: 13))
                        .lineLimit(3...4)
                        .padding(10)
                        .frame(minHeight: 76, alignment: .topLeading)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(AKColor.line, lineWidth: 1)
                        )
                        .onChange(of: reportNote) { value in
                            if value.count > 500 { reportNote = String(value.prefix(500)) }
                        }
                    Text("\(reportNote.count)/500")
                        .font(.system(size: 11))
                        .foregroundColor(AKColor.placeholder)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Button {
                        submitReport()
                    } label: {
                        Text("提交举报")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(reportReason.isEmpty ? AKColor.muted : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(reportReason.isEmpty ? AKColor.line : AKColor.brand)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(reportReason.isEmpty)
                    .padding(.top, 6)
                }
                .padding(16)
            }
            .background(AKColor.bg)
        }
        .background(AKColor.bg)
    }

    private var reportReasons: [String] {
        ["色情低俗", "诈骗/赌博", "骚扰广告", "侵权内容"]
    }

    private var reportHeader: some View {
        HStack(spacing: 0) {
            BackButton()
                .frame(width: 34, height: 34)
            Spacer(minLength: 0)
        }
        .overlay(
            Text("举报该用户")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AKColor.text)
        )
        .padding(.horizontal, 8)
        .frame(height: 46)
        .frame(maxWidth: .infinity)
        .background(AKColor.card)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AKColor.line).frame(height: 0.5)
        }
    }

    private func submitReport() {
        guard !reportReason.isEmpty else { return }
        let reason = reportReason
        let note = reportNote.trimmingCharacters(in: .whitespaces)
        showReport = false
        Task {
            do {
                let msg = try await APIClient.shared.postRaw(
                    "api/v1/report",
                    body: ["target_type": "user", "target_id": uid, "reason": reason, "content": note]
                )
                showToast(msg.isEmpty ? "举报已提交，感谢反馈" : msg)
            } catch let err {
                showToast(err.localizedDescription)
            }
        }
    }

    private func setBlocked(_ blocked: Bool) async {
        do {
            let msg = try await APIClient.shared.postRaw(
                "api/v1/block",
                body: ["user_id": uid, "act": blocked ? "add" : "remove"]
            )
            showToast(msg.isEmpty ? (blocked ? "已加入黑名单" : "已取消拉黑") : msg)
            await load()
        } catch let err {
            showToast(err.localizedDescription)
        }
    }

    private var toastView: some View {
        Group {
            if let toastText {
                Text(toastText)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color(hex: 0x1A1D26).opacity(0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 40)
                    .padding(.bottom, 90)
            }
        }
    }

    private func showToast(_ message: String) {
        toastText = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if toastText == message { toastText = nil }
        }
    }

    private func closeSettingsThen(_ action: @escaping () -> Void) {
        showSettings = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            action()
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let payload: UserProfilePayload = try await APIClient.shared.get(
                "api/v1/user",
                query: ["uid": "\(uid)", "gid": "\(gid)"]
            )
            profile = payload.profile
            group = payload.group
            adminOverride = nil
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        if let r = try? await APIClient.shared.chatBg(convType: "private", convId: uid) {
            chatBg = r.bg ?? ""
        }
    }
}

/// /api/v1/user 的 group 段（对齐安卓 UserProfileGroupDto）
private struct ProfileGroup: Decodable {
    let gid: Int64
    let myRole: Int
    let targetRole: Int
    let targetNick: String
    let muteUntil: Int64
    let muteText: String
    let canNick: Int
    let canMute: Int
    let canKick: Int

    enum CodingKeys: String, CodingKey {
        case gid
        case myRole = "my_role"
        case targetRole = "target_role"
        case targetNick = "target_nick"
        case muteUntil = "mute_until"
        case muteText = "mute_text"
        case canNick = "can_nick"
        case canMute = "can_mute"
        case canKick = "can_kick"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gid = (try? c.decode(Int64.self, forKey: .gid)) ?? 0
        myRole = (try? c.decode(Int.self, forKey: .myRole)) ?? 0
        targetRole = (try? c.decode(Int.self, forKey: .targetRole)) ?? 0
        targetNick = (try? c.decode(String.self, forKey: .targetNick)) ?? ""
        muteUntil = (try? c.decode(Int64.self, forKey: .muteUntil)) ?? 0
        muteText = (try? c.decode(String.self, forKey: .muteText)) ?? ""
        canNick = (try? c.decode(Int.self, forKey: .canNick)) ?? 0
        canMute = (try? c.decode(Int.self, forKey: .canMute)) ?? 0
        canKick = (try? c.decode(Int.self, forKey: .canKick)) ?? 0
    }
}

/// 一次 /api/v1/user 请求同时解出资料与群内身份（Core 的 UserProfile 不含 group 字段）
private struct UserProfilePayload: Decodable {
    let profile: UserProfile
    let group: ProfileGroup?

    enum CodingKeys: String, CodingKey { case group }

    init(from decoder: Decoder) throws {
        profile = try UserProfile(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        group = try? c.decode(ProfileGroup.self, forKey: .group)
    }
}
