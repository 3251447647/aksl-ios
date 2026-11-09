import SwiftUI
import PhotosUI

/// 用户主页：会员渐变资料卡 + 个性签名 + 朋友圈入口 + 聊天记录入口 + 底部操作栏（对齐安卓 UserProfileScreen）
struct UserProfileView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let uid: Int64
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
    @State private var reportReason = ""
    @State private var reportNote = ""
    @State private var toastText: String?
    @State private var verifyMsg = "你好，我们在同一个群"
    @State private var chatBg: String = ""
    @State private var showBgPicker = false
    @State private var bgItem: PhotosPickerItem?

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
        .sheet(isPresented: $showSettings) {
            settingsSheet
        }
        .sheet(isPresented: $showReport) {
            reportSheet
        }
        .sheet(isPresented: $showChat) {
            if let p = profile {
                NavigationStack {
                    ChatView(convType: "private", convId: p.id, title: p.displayName)
                }
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
            Text(p.bio)
                .font(.system(size: 13.5))
                .foregroundColor(AKColor.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(AKColor.card)
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

    // MARK: - 底部操作

    @ViewBuilder
    private func actionBar(_ p: UserProfile) -> some View {
        VStack(spacing: 8) {
            if p.isSelf == 1 || p.isBot == 1 {
                primaryButton("发消息") { showChat = true }
            } else if p.isFriend == 1 {
                HStack(spacing: 0) {
                    callButton("语音通话", "phone.fill") {
                        Task {
                            await CallManager.shared.start(peerUid: p.id, name: p.displayName, avatar: p.avatar, type: 1)
                            showCall = true
                        }
                    }
                    Rectangle().fill(AKColor.brand.opacity(0.2)).frame(width: 0.8, height: 16)
                    callButton("视频通话", "video.fill") {
                        Task {
                            await CallManager.shared.start(peerUid: p.id, name: p.displayName, avatar: p.avatar, type: 2)
                            showCall = true
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

    private var settingsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    VStack(spacing: 0) {
                        if profile?.isFriend == 1 {
                            settingsRow("设置备注", value: profile?.remark ?? "", showArrow: true) {
                                remarkText = profile?.remark ?? ""
                                showRemark = true
                            }
                            settingsDivider
                            toggleRow("消息免打扰", key: "is_mute", on: profile?.isMute == 1)
                            settingsDivider
                            toggleRow("置顶聊天", key: "is_top", on: profile?.isTop == 1)
                            settingsDivider
                        }
                        NavigationLink {
                            QRCodeView(uid: uid, name: profile?.displayName ?? presetName,
                                       avatar: profile?.avatar)
                        } label: {
                            settingsRowContent("我的二维码", value: "", showArrow: true, destructive: false)
                        }
                        .buttonStyle(.plain)
                        settingsDivider
                        settingsRow("聊天背景", value: chatBg.isEmpty ? "默认" : "已设置", showArrow: true) {
                            closeSettingsThen { showBgPicker = true }
                        }
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
                    .background(AKColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(spacing: 0) {
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
                    .background(AKColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(12)
            }
            .background(AKColor.bg)
            .overlay(alignment: .bottom) { toastView }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { showSettings = false }
                        .font(.system(size: 15))
                        .foregroundColor(AKColor.text)
                }
            }
        }
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
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.muted)
                    .lineLimit(1)
            }
            if showArrow {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.placeholder)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
        .contentShape(Rectangle())
    }

    private var settingsDivider: some View {
        Rectangle().fill(AKColor.line).frame(height: 0.6).padding(.leading, 18)
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
        .padding(.horizontal, 18)
        .frame(height: 52)
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
            profile = try await APIClient.shared.userProfile(id: uid)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        if let r = try? await APIClient.shared.chatBg(convType: "private", convId: uid) {
            chatBg = r.bg ?? ""
        }
    }
}
