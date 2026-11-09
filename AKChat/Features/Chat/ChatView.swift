import SwiftUI
import PhotosUI
import Combine
import UIKit
import AVKit

struct ProfileTarget: Identifiable {
    let id: Int64
}

/// 长按菜单里需要二次确认的操作
private enum ChatConfirm: Identifiable {
    case recall(Message)
    case delete(Message)

    var id: String {
        switch self {
        case .recall(let m): return "recall_\(m.listKey)"
        case .delete(let m): return "delete_\(m.listKey)"
        }
    }
}

struct ChatView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    let convType: String
    let convId: Int64
    let title: String

    @State private var messages: [Message] = []
    @State private var text = ""
    @State private var showEmoji = false
    @StateObject private var voice = VoiceService()
    @State private var sending = false
    @State private var loading = false
    @State private var loadingMore = false
    @State private var hasMore = false
    @State private var errorText: String?
    @State private var showGroupInfo = false
    @State private var reportTarget: Message?
    @State private var confirm: ChatConfirm?
    @State private var replyTo: Message?
    @State private var payTarget: Message?
    @State private var recordPayload: String?
    @State private var showRecord = false
    @State private var videoURL: URL?
    @State private var showVideo = false
    @State private var showNotices = false
    @State private var showCamera = false
    @State private var lastTypingSent: TimeInterval = 0
    @FocusState private var inputFocused: Bool
    @State private var previewImage: PreviewImage?
    @State private var pinText: String?
    @State private var pinMsgId: Int64 = 0
    @State private var typingName: String?
    @State private var typingToken = 0
    @State private var members: [GroupMember] = []
    @State private var showAtPicker = false
    @State private var atUids: [Int64] = []
    @State private var pendingNotice: GroupNotice?
    @State private var showNotice = false
    @State private var scrollTarget: String?
    @State private var localSeq: Int64 = -1
    @State private var profileTarget: ProfileTarget?
    @State private var showForward = false
    @State private var forwardMessages: [Message] = []
    @State private var chatBg: String?
    @State private var showLive = false
    @State private var liveGid: Int64 = 0
    @State private var active: GroupActiveData?
    @State private var groupInfo: GroupInfo?
    @State private var showGroupCall = false
    @State private var showMore = false
    @State private var showPhotoPicker = false
    @State private var showRedPacket = false
    @State private var showTransfer = false
    @State private var showGift = false
    @State private var callType = 1
    @State private var previewGroupId: Int64 = 0
    @State private var showGroupPreview = false
    @State private var showCall = false
    @State private var menuTarget: Message?
    @State private var selectMode = false
    @State private var selectedKeys: Set<String> = []
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var pendingPhotos: [UIImage] = []
    @State private var showPhotoPreview = false
    @State private var photoCaption = ""
    @State private var voiceMode = false
    @State private var voiceCancel = false
    @State private var recordBusy = false
    @State private var recordReleased = false
    @State private var playedVoice: Set<String> = []
    @State private var showBgPicker = false
    @State private var bgItem: PhotosPickerItem?
    @State private var showEmojiPicker = false
    @State private var emojiItems: [PhotosPickerItem] = []
    @State private var forwardTitle = "聊天记录"
    @State private var errorToken = 0
    @State private var unreadAnchor: Int64 = 0
    @State private var pinScopeTarget: Message?
    @State private var localPinId: Int64 = 0

    private var myId: Int64 { app.user?.id ?? 0 }
    private var isGroup: Bool { convType == "group" }

    /// 私聊对方在会话列表里的信息（靓号/VIP 徽章用）
    private var peerConv: Conversation? {
        app.conversations.first { $0.convType == convType && $0.convId == convId }
    }

    /// 群内进行中的通话/直播横条（对齐安卓 GroupActiveBar）
    @ViewBuilder
    private var activeBar: some View {
        if let live = active?.live, live.liveId > 0 {
            Button {
                showLive = true
            } label: {
                barContent(icon: "dot.radiowaves.left.and.right",
                           title: live.title.isEmpty ? "群直播进行中" : live.title,
                           subtitle: "\(live.hostName) · \(live.viewers) 人观看",
                           tint: Color(hex: 0xFF4D6D))
            }
            .buttonStyle(.plain)
        } else if let call = active?.call, call.callId > 0 {
            Button {
                callType = call.callType == 2 ? 2 : 1
                showGroupCall = true
            } label: {
                barContent(icon: call.callType == 2 ? "video.fill" : "phone.fill",
                           title: call.callType == 2 ? "群视频通话进行中" : "群语音通话进行中",
                           subtitle: "\(call.callerName) 发起 · \(call.members) 人在线",
                           tint: AKColor.brand)
            }
            .buttonStyle(.plain)
        }
    }

    private func barContent(icon: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(AKColor.text).lineLimit(1)
                Text(subtitle).font(.system(size: 11)).foregroundColor(AKColor.muted).lineLimit(1)
            }
            Spacer(minLength: 0)
            Text("加入")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(tint)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(AKColor.cardAlt)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AKColor.line).frame(height: 0.5)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            if let pinText {
                pinBar(pinText)
            }
            if isGroup, let notice = groupNoticeText {
                noticeBar(notice)
            }
            if isGroup {
                activeBar
            }
            messageList

            if !isGroup, convId == app.botUid, !app.botQuick.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(app.botQuick, id: \.self) { q in
                            Button {
                                text = q
                                Task { await send() }
                            } label: {
                                Text(q)
                                    .font(.system(size: 12))
                                    .foregroundColor(AKColor.text)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(AKColor.card)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                }
            }

            if selectMode {
                selectBar
            } else if let muteHint {
                mutedBar(muteHint)
            } else {
                if let replyTo {
                    replyBar(replyTo)
                }
                if voice.recording {
                    recordingStrip
                }
                inputBar
                if showEmoji {
                    StickerAlbumView(
                        emojis: app.emojis,
                        onPickEmoji: { insertText($0) },
                        onSticker: { url in Task { await sendSticker(url) } },
                        onAdd: { showEmojiPicker = true },
                        onDelete: { url in
                            Task {
                                await APIClient.shared.deleteEmoji(url: url)
                                await app.loadEmojis()
                                flash("已删除表情")
                            }
                        }
                    )
                }
                if showMore {
                    MorePanel(
                        isGroup: isGroup,
                        onPhoto: { showMore = false; showPhotoPicker = true },
                        onCamera: { showMore = false; showCamera = true },
                        onRedPacket: { showMore = false; showRedPacket = true },
                        onTransfer: { showMore = false; showTransfer = true },
                        onGift: { showMore = false; showGift = true },
                        onVoiceCall: { showMore = false; startCall(1) },
                        onVideoCall: { showMore = false; startCall(2) },
                        onGroupCall: { type in
                            showMore = false
                            callType = type
                            showGroupCall = true
                        },
                        onGroupLive: {
                            showMore = false
                            liveGid = convId
                            showLive = true
                        },
                        onChatBg: { showMore = false; showBgPicker = true }
                    )
                }
            }
        }
        .background(
            ZStack {
                if let chatBg, let u = APIClient.fullURL(chatBg) {
                    AsyncImage(url: u) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFill()
                        } else {
                            AKColor.bg
                        }
                    }
                    .clipped()
                    AKColor.bg.opacity(0.42)
                } else {
                    AKColor.bg
                }
            }
            .ignoresSafeArea()
        )
        .overlay {
            if voice.recording {
                RecordingOverlay(cancel: voiceCancel)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottom) {
            if let errorText {
                Text(errorText)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .padding(.bottom, 90)
            }
        }
        .sheet(isPresented: $showGroupInfo) {
            NavigationStack {
                GroupInfoView(groupId: convId)
            }
        }
        .sheet(isPresented: $showAtPicker) {
            AtMemberPicker(members: members, myRole: myRole) { uid, name in
                appendAt(uid: uid, name: name)
            }
        }
        .overlay {
            if showNotice {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea()
                        .onTapGesture { }
                    GroupNoticePopup(
                        notice: pendingNotice,
                        onClose: {
                            showNotice = false
                            if let n = pendingNotice {
                                Task { await APIClient.shared.ackGroupNotice(gid: convId, noticeId: n.id) }
                            }
                        },
                        groupName: groupInfo?.name ?? title,
                        groupAvatar: groupInfo?.avatar,
                        onOpenProfile: {
                            showNotice = false
                            if let n = pendingNotice {
                                Task { await APIClient.shared.ackGroupNotice(gid: convId, noticeId: n.id) }
                            }
                            showGroupInfo = true
                        }
                    )
                }
                .transition(.opacity)
            }
        }
        .fullScreenCover(item: $previewImage) { item in
            MediaPagerView(
                items: item.items,
                index: item.index,
                onForward: { msg in
                    forwardMessages = [msg]
                    forwardTitle = forwardRecordTitle
                    showForward = true
                },
                onFavorite: { msg in
                    Task {
                        await APIClient.shared.addFavorite(message: msg, convName: title)
                        flash("已收藏")
                    }
                },
                onRecall: { msg in confirm = .recall(msg) },
                onDelete: { msg in deleteLocal(msg) },
                canRecall: { msg in canRecall(msg) }
            )
        }
        .sheet(item: $profileTarget) { target in
            NavigationStack {
                UserProfileView(uid: target.id)
            }
        }
        .sheet(isPresented: $showForward) {
            ForwardPickerView(messages: forwardMessages, title: forwardTitle)
        }
        .sheet(item: $menuTarget) { msg in
            ChatMessageMenuSheet(
                message: msg,
                isGroup: isGroup,
                mine: msg.fromUid == myId,
                myRole: myRole,
                pinned: pinMsgId == msg.id,
                canRecall: canRecall(msg),
                canPin: canPin && msg.id > 0 && msg.type != 11,
                canAddEmoji: msg.type == 5 && msg.fromUid != myId,
                onPick: { key in handleMenu(key, msg: msg) }
            )
        }
        .sheet(isPresented: $showPhotoPreview) {
            PhotoSendPreview(
                images: pendingPhotos,
                caption: $photoCaption,
                onCancel: {
                    showPhotoPreview = false
                    pendingPhotos = []
                    photoCaption = ""
                },
                onSend: { cap in
                    let imgs = pendingPhotos
                    showPhotoPreview = false
                    pendingPhotos = []
                    photoCaption = ""
                    Task { await sendPhotos(imgs, caption: cap) }
                }
            )
        }
        .alert(item: $confirm) { c in
            switch c {
            case .recall(let msg):
                return Alert(
                    title: Text(msg.fromUid == myId ? "撤回消息" : "撤回该消息"),
                    message: Text("撤回后对方将看不到这条消息，确认撤回？"),
                    primaryButton: .destructive(Text("撤回")) { Task { await recall(msg) } },
                    secondaryButton: .cancel(Text("取消"))
                )
            case .delete(let msg):
                return Alert(
                    title: Text("删除消息"),
                    message: Text("删除后本机将看不到这条消息，且无法恢复。确定删除吗？"),
                    primaryButton: .destructive(Text("删除")) { deleteLocal(msg) },
                    secondaryButton: .cancel(Text("取消"))
                )
            }
        }
        .confirmationDialog(
            "置顶消息",
            isPresented: Binding(
                get: { pinScopeTarget != nil },
                set: { if !$0 { pinScopeTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("仅自己可见") { applyPinScope(shared: false) }
            Button("双方可见") { applyPinScope(shared: true) }
            Button("取消", role: .cancel) { pinScopeTarget = nil }
        } message: {
            Text("「仅自己可见」只在你这边显示；「双方可见」写入服务端，对方也能看到。")
        }
        .sheet(item: $reportTarget) { msg in
            NavigationStack {
                ReportMessageSheet(message: msg) { reason, note in
                    Task {
                        await APIClient.shared.reportMessage(
                            convType: convType,
                            msgId: msg.id,
                            reason: reason,
                            content: note
                        )
                        errorText = "举报已提交"
                    }
                }
            }
        }
        .sheet(item: $payTarget) { msg in
            NavigationStack {
                Group {
                    if msg.type == 7 || msg.type == 21 {
                        RedPacketDetailSheet(
                            infoId: redPacketId(msg),
                            convType: convType,
                            convId: convId,
                            myId: myId
                        ) { Task { await reloadAfterPay() } }
                    } else if msg.type == 8 || msg.type == 22 {
                        TransferClaimSheet(message: msg, convType: convType, convId: convId, myId: myId) {
                            Task { await reloadAfterPay() }
                        }
                    } else {
                        GiftClaimSheet(message: msg, convType: convType, convId: convId, myId: myId) {
                            Task { await reloadAfterPay() }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showRecord) {
            ChatRecordView(payload: recordPayload ?? "")
        }
        .sheet(isPresented: $showVideo) {
            NavigationStack {
                VideoPreviewSheet(url: videoURL)
            }
        }
        .sheet(isPresented: $showNotices) {
            NavigationStack {
                GroupNoticesView(groupId: convId)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(onImage: { image in
                showCamera = false
                guard let data = image.jpegData(compressionQuality: 0.85) else { return }
                Task { await sendPhotoData(data) }
            }, onCancel: {
                showCamera = false
            })
        }
        .fullScreenCover(isPresented: $showLive) {
            NavigationStack { LiveRoomView(gid: liveGid) }
        }
        .sheet(isPresented: $showGroupPreview) {
            NavigationStack { GroupPreviewView(groupId: previewGroupId) }
        }
        .fullScreenCover(isPresented: $showCall) {
            CallScreen()
        }
        .sheet(isPresented: $showGroupCall) {
            NavigationStack { GroupCallView(gid: convId, callType: callType) }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItems,
                      maxSelectionCount: 9, matching: .images)
        .photosPicker(isPresented: $showBgPicker, selection: $bgItem, matching: .images)
        .photosPicker(isPresented: $showEmojiPicker, selection: $emojiItems,
                      maxSelectionCount: 9, matching: .images)
        .sheet(isPresented: $showRedPacket) {
            RedPacketSheet(convType: convType, convId: convId) { Task { await reloadAfterPay() } }
        }
        .sheet(isPresented: $showTransfer) {
            TransferSheet(convType: convType, convId: convId) { Task { await reloadAfterPay() } }
        }
        .sheet(isPresented: $showGift) {
            GiftSheet(convType: convType, convId: convId) { Task { await reloadAfterPay() } }
        }
        .task {
            /* 先用本地缓存立刻上背景（不等网络），再用服务端结果校正 */
            chatBg = cachedBg()
            /* 先把消息拉下来渲染，其余数据并行补齐，避免打开会话卡顿 */
            await load()

            Task {
                if let r = try? await APIClient.shared.chatBg(convType: convType, convId: convId) {
                    chatBg = r.bg
                    storeBg(r.bg)
                }
            }
            Task {
                async let emojis: Void = app.loadEmojis()
                async let pin: Void = loadPin()
                _ = await (emojis, pin)
            }
            if isGroup {
                Task {
                    async let members: Void = loadMembers()
                    async let notice: Void = loadPendingNotice()
                    _ = await (members, notice)
                }
                Task {
                    async let activeReq = APIClient.shared.groupActive(gid: convId)
                    async let infoReq = APIClient.shared.groupInfo(id: convId)
                    let (a, i) = await (try? activeReq, try? infoReq)
                    await MainActor.run {
                        active = a
                        groupInfo = i
                    }
                }
            }
        }
        .onReceive(app.$incoming.compactMap { $0 }) { msg in
            guard msg.convType == convType, msg.convId == convId else { return }
            if msg.id != 0, messages.contains(where: { $0.id == msg.id }) { return }
            if let clientId = msg.clientId, !clientId.isEmpty,
               let idx = messages.firstIndex(where: { $0.clientId == clientId && $0.localId < 0 }) {
                messages[idx] = msg
            } else {
                messages.append(msg)
            }
            Task { await app.markRead(convType: convType, convId: convId, lastId: msg.id) }
        }
        .onReceive(app.$chatEvent.compactMap { $0 }) { ev in
            handle(ev)
        }
        .onChange(of: photoItems) { items in
            guard !items.isEmpty else { return }
            Task {
                var images: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                await MainActor.run {
                    photoItems = []
                    guard !images.isEmpty else { return }
                    pendingPhotos = images
                    photoCaption = ""
                    showPhotoPreview = true
                }
            }
        }
        .onChange(of: bgItem) { item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let up = try? await app.uploadImage(data) else {
                    await MainActor.run { bgItem = nil; flash("背景设置失败") }
                    return
                }
                if let r = try? await APIClient.shared.setChatBg(convType: convType, convId: convId, url: up.url) {
                    await MainActor.run {
                        chatBg = r.bg
                        storeBg(r.bg)
                        bgItem = nil
                        flash("背景已更新")
                    }
                } else {
                    await MainActor.run { bgItem = nil; flash("背景设置失败") }
                }
            }
        }
        .onChange(of: emojiItems) { items in
            guard !items.isEmpty else { return }
            Task {
                var urls: [String] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let up = try? await app.uploadImage(data) {
                        urls.append(up.url)
                    }
                }
                await MainActor.run { emojiItems = [] }
                for url in urls {
                    await app.addEmoji(url: url)
                }
                flash(urls.isEmpty ? "表情添加失败" : "表情已添加")
            }
        }
        .reportsDetailPage()
        .restoresSwipeBack()
    }

    /* ---------------- 列表 ---------------- */

    private var firstUnreadIndex: Int {
        guard unreadAnchor > 0 else { return -1 }
        return messages.firstIndex { $0.id >= unreadAnchor && $0.fromUid != myId } ?? -1
    }

    /// 「以下是新消息 · N 条」分割线（对齐安卓 UnreadDividerRow）
    private var unreadDivider: some View {
        let count = messages.filter { unreadAnchor > 0 && $0.id >= unreadAnchor && $0.fromUid != myId }.count
        return HStack(spacing: 0) {
            Rectangle().fill(AKColor.line).frame(height: 0.5)
            Text(count > 0 ? "以下是新消息 · \(count) 条" : "以下是新消息")
                .font(.system(size: 11))
                .foregroundColor(AKColor.muted)
                .fixedSize()
                .padding(.horizontal, 10)
            Rectangle().fill(AKColor.line).frame(height: 0.5)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    private func toggleSelect(_ msg: Message) {
        if selectedKeys.contains(msg.listKey) {
            selectedKeys.remove(msg.listKey)
        } else {
            selectedKeys.insert(msg.listKey)
        }
    }

    private func selectCircle(selected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(selected ? AKColor.brand : Color.clear)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle().stroke(selected ? AKColor.brand : AKColor.placeholder, lineWidth: 1)
                )
            if selected {
                Text("✓")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
        }
        .padding(.top, 12)
        .onTapGesture { }
    }

    /// 多选底栏（对齐安卓 ChatSelectBar）
    private var selectBar: some View {
        HStack(spacing: 0) {
            Text("已选 \(selectedKeys.count) 条")
                .font(.system(size: 13))
                .foregroundColor(AKColor.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                selectMode = false
                selectedKeys.removeAll()
            } label: {
                Text("取消")
                    .font(.system(size: 13.5))
                    .foregroundColor(AKColor.muted)
                    .padding(.horizontal, 10)
            }
            .buttonStyle(.plain)
            Button {
                let picked = messages.filter { selectedKeys.contains($0.listKey) }
                for m in picked { deleteLocalSilently(m) }
                selectMode = false
                selectedKeys.removeAll()
                flash("已删除 \(picked.count) 条")
            } label: {
                Text("删除")
                    .font(.system(size: 13.5))
                    .foregroundColor(selectedKeys.isEmpty ? AKColor.placeholder : AKColor.red)
                    .padding(.horizontal, 10)
            }
            .buttonStyle(.plain)
            .disabled(selectedKeys.isEmpty)
            Button {
                let picked = messages
                    .filter { selectedKeys.contains($0.listKey) }
                    .sorted { $0.createdAt < $1.createdAt }
                selectMode = false
                selectedKeys.removeAll()
                forwardMessages = picked
                forwardTitle = forwardRecordTitle
                showForward = true
            } label: {
                Text("合并转发")
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(selectedKeys.isEmpty ? AKColor.placeholder : AKColor.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(selectedKeys.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AKColor.card)
    }

    private var forwardRecordTitle: String {
        isGroup ? (title + "的聊天记录")
                : ((app.user?.nickname ?? "我") + " 与 " + title + " 的聊天记录")
    }


    private var messageList: some View {
        let hints = readHints
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if loading {
                        ProgressView().padding(.top, 12)
                    }
                    if messages.isEmpty && !loading {
                        VStack(spacing: 6) {
                            Text(errorText ?? "暂无消息")
                                .font(.system(size: 12))
                                .foregroundColor(AKColor.muted)
                            if errorText != nil {
                                Button("点击重试") { Task { await load() } }
                                    .font(.system(size: 13))
                                    .foregroundColor(AKColor.brand)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                    if hasMore && !messages.isEmpty {
                        Button {
                            Task { await loadMore() }
                        } label: {
                            Text(loadingMore ? "加载中…" : "查看更早消息")
                                .font(.system(size: 12))
                                .foregroundColor(AKColor.link)
                        }
                        .padding(.vertical, 6)
                    }
                    ForEach(Array(messages.enumerated()), id: \.element.listKey) { index, msg in
                        let prev = index > 0 ? messages[index - 1].createdAt : 0
                        if index == firstUnreadIndex {
                            unreadDivider
                        }
                        if let stamp = chatDividerLabel(previous: prev, current: msg.createdAt) {
                            Text(stamp)
                                .font(.system(size: 10.5))
                                .foregroundColor(AKColor.muted)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(AKColor.card)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .padding(.vertical, 8)
                        }
                        HStack(alignment: .top, spacing: 8) {
                            if selectMode {
                                selectCircle(selected: selectedKeys.contains(msg.listKey))
                            }
                            row(msg, readHint: hints[msg.listKey] ?? 0)
                        }
                        .id(msg.listKey)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .onChange(of: messages.count) { _ in
                if let last = messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.listKey, anchor: .bottom)
                    }
                }
            }
            .onChange(of: scrollTarget) { target in
                guard let target else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(target, anchor: .center)
                }
                scrollTarget = nil
            }
        }
    }

    private func pinBar(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "pin.fill")
                .font(.system(size: 11))
                .foregroundColor(AKColor.gold)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(AKColor.sub)
                .lineLimit(1)
            Spacer(minLength: 0)
            if canPin {
                Button {
                    Task { await clearPin() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11))
                        .foregroundColor(AKColor.hint)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(Color(hex: 0xFFF8E8))
        .overlay(Rectangle().fill(AKColor.line).frame(height: 0.5), alignment: .bottom)
        .contentShape(Rectangle())
        .onTapGesture {
            if pinMsgId > 0 { scrollTarget = "m_\(pinMsgId)" }
        }
    }

    private var canPin: Bool {
        if isGroup {
            return myRole == 1 || myRole == 2
        }
        return true
    }

    private var myRole: Int {
        members.first { $0.uid == myId }?.role ?? 0
    }

    private var groupNoticeText: String? {
        guard isGroup, let notice = groupInfo?.notice else { return nil }
        let text = notice.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// 被禁言 / 群封禁 / 全员禁言时输入区置灰（对齐安卓 MutedComposerBar）
    private var muteHint: String? {
        guard isGroup else { return nil }
        if groupInfo?.isBanned == 1 {
            let reason = (groupInfo?.banReason ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return "该群已被封禁，请联系在线客服处理" +
                (reason.isEmpty ? "" : "（封禁原因：\(reason)）")
        }
        guard myRole != 1, myRole != 2 else { return nil }
        let until = groupInfo?.myMuteUntil ?? 0
        guard until > Int64(Date().timeIntervalSince1970) else { return nil }
        return "你已被禁言，无法发送消息"
    }

    private func noticeBar(_ text: String) -> some View {
        Button {
            showNotices = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.gold)
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.sub)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("查看")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.link)
            }
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(AKColor.goldSoft)
            .overlay(Rectangle().fill(AKColor.line).frame(height: 0.5), alignment: .bottom)
        }
        .buttonStyle(.plain)
    }

    private func replyDisplayName(_ msg: Message) -> String {
        if msg.fromUid == myId { return app.user?.nickname ?? "我" }
        let name = members.first { $0.uid == msg.fromUid }?.name ?? msg.fromName ?? ""
        return name.isEmpty ? "对方" : name
    }

    /// 输入框上方引用条（对齐安卓 ChatBottomBar 的 replyTo 区域）
    private func replyBar(_ msg: Message) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(AKColor.brand)
                .frame(width: 3, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("回复 \(replyDisplayName(msg))")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.brand)
                Text(digest(msg))
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.sub)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button {
                replyTo = nil
            } label: {
                Text("×")
                    .font(.system(size: 18))
                    .foregroundColor(AKColor.muted)
                    .padding(.horizontal, 6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(AKColor.fill)
    }

    private func mutedBar(_ hint: String) -> some View {
        HStack {
            Text(hint)
                .font(.system(size: 13))
                .foregroundColor(AKColor.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(AKColor.card)
    }

    /// 私聊已读回执：只在「连续同状态段」的最后一条显示（对齐安卓 readHints）
    private var readHints: [String: Int] {
        var out: [String: Int] = [:]
        if isGroup {
            /* 群聊只有服务端下发 is_read 时才显示已读（不显示人数） */
            for m in messages where m.fromUid == myId && m.id > 0 && m.status == 1 && m.isRead == 1 {
                out[m.listKey] = 2
            }
            return out
        }
        for i in messages.indices {
            let m = messages[i]
            guard m.fromUid == myId, m.id > 0, m.status == 1 else { continue }
            let next = i + 1 < messages.count ? messages[i + 1] : nil
            let sameRun = next != nil && next!.fromUid == myId && next!.id > 0
                && next!.status == 1 && next!.isRead == m.isRead
            if !sameRun {
                out[m.listKey] = m.isRead == 1 ? 2 : 1
            }
        }
        return out
    }

    /// 时间分隔：与上一条相差 5 分钟以上或跨天（对齐安卓 buildChatRows）
    private func chatDividerLabel(previous: Int64, current: Int64) -> String? {
        guard current > 0 else { return nil }
        if previous > 0 {
            if ChatClock.sameDay(previous, current), current - previous <= 300 { return nil }
        }
        return ChatClock.label(current)
    }

    private func isStickerMessage(_ m: Message) -> Bool {
        if (m.clientId ?? "").hasPrefix("sticker_") { return true }
        let s = (m.text?.isEmpty == false ? m.text : m.content) ?? ""
        return s.contains("/emoji/") || s.contains("uploads/emoji") || s.contains("is_sticker")
    }

    /// 会话摘要：与安卓 msgDigest 同一口径，引用摘要/复制都用它
    private func digest(_ m: Message) -> String {
        func plain(_ raw: String, _ limit: Int) -> String {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty || t.hasPrefix("{") { return "[消息]" }
            return String(t.prefix(limit))
        }
        switch m.type {
        case 2, 20: return "[充值申请]"
        case 3: return "[提现申请]"
        case 5: return isStickerMessage(m) ? "[表情]" : "[图片]"
        case 6: return "[语音]"
        case 7, 21: return "[红包]"
        case 8, 22: return "[转账]"
        case 9, 23: return "[礼物]"
        case 10: return "[引用] " + plain(m.text ?? "", 18)
        case 11: return systemDigest(m)
        case 12: return "[名片]"
        case 13: return "[群名片]"
        case 14: return "[通话]"
        case 15: return "[视频]"
        case 16: return "[动态]"
        case 17: return "[聊天记录]"
        case 18: return "[文件]"
        case 19: return "[直播]"
        case 31: return "[图片]"
        default: return plain(m.text ?? m.content ?? "", 40)
        }
    }

    private func systemDigest(_ m: Message) -> String {
        let raw = (m.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("{") {
            if let o = MessageBody.jsonObject(raw) {
                for key in ["text", "content", "name"] {
                    if let t = o[key] as? String, !t.isEmpty, t != "null" { return t }
                }
            }
            return "[系统消息]"
        }
        if raw == "一条消息已被撤回" { return "对方撤回了一条消息" }
        return raw.isEmpty ? "[系统消息]" : raw
    }

    private func copyText(_ m: Message) -> String? {
        switch m.type {
        case 1:
            let t = m.text ?? m.content ?? ""
            return t.isEmpty ? nil : t
        case 10:
            let t = m.text ?? ""
            return t.isEmpty ? nil : t
        case 2, 3, 7, 8, 9, 12, 13, 14, 16, 17, 20, 21, 22, 23:
            let d = digest(m)
            return (d.isEmpty || d == "[消息]") ? nil : d
        case 11:
            return nil
        default:
            let t = (m.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty || t.hasPrefix("{") { return nil }
            return t
        }
    }

    /// 撤回权限：本人 2 分钟（私聊 3 分钟）；群主可撤任意人；管理员可撤普通成员
    private func canRecall(_ m: Message) -> Bool {
        guard m.id > 0, m.type != 11, m.recalled == 0 else { return false }
        let now = Int64(Date().timeIntervalSince1970)
        if m.fromUid == myId {
            if isGroup { return myRole == 1 || myRole == 2 || now - m.createdAt <= 120 }
            return now - m.createdAt <= 180
        }
        guard isGroup else { return false }
        if myRole == 1 { return true }
        if myRole == 2 {
            let authorRole = members.first { $0.uid == m.fromUid }?.role ?? m.fromRole
            return authorRole == 0
        }
        return false
    }

    private func jumpToQuote(_ id: Int64) {
        guard id > 0 else { return }
        if messages.contains(where: { $0.id == id }) {
            scrollTarget = "m_\(id)"
        } else {
            errorText = "原消息已不在聊天记录中"
        }
    }

    private func redPacketId(_ m: Message) -> Int64 {
        if let v = m.extraMap["rp_id"]?.intValue, v > 0 { return Int64(v) }
        if let o = MessageBody.jsonObject(m.content) {
            if let n = o["rp_id"] as? NSNumber { return n.int64Value }
            if let s = o["rp_id"] as? String, let v = Int64(s) { return v }
        }
        return m.id
    }

    /// 会话内图片组成预览列表，供分页器使用
    private func openImagePager(_ url: String) {
        var items: [PreviewMedia] = []
        var at = 0
        for m in messages {
            let sticker = isStickerMessage(m)
            guard (m.type == 5 && !sticker) || m.type == 15 else { continue }
            let raw = m.text ?? ""
            guard let u = APIClient.fullURL(VoiceService.cleanPath(raw)) else { continue }
            if raw == url || VoiceService.cleanPath(raw) == url { at = items.count }
            items.append(PreviewMedia(url: u, isVideo: m.type == 15, message: m))
        }
        if items.isEmpty, let u = APIClient.fullURL(VoiceService.cleanPath(url)) {
            items = [PreviewMedia(url: u, isVideo: false, message: nil)]
        }
        guard !items.isEmpty else { return }
        previewImage = PreviewImage(items: items, index: min(at, items.count - 1))
    }

    private func openAlbum(_ paths: [String], index: Int) {
        var items: [PreviewMedia] = []
        for raw in paths {
            guard let u = APIClient.fullURL(VoiceService.cleanPath(raw)) else { continue }
            let lower = raw.lowercased()
            let video = lower.hasSuffix(".mp4") || lower.hasSuffix(".mov")
                || lower.hasSuffix(".m4v") || lower.hasSuffix(".webm")
            items.append(PreviewMedia(url: u, isVideo: video, message: nil))
        }
        guard !items.isEmpty else { return }
        previewImage = PreviewImage(items: items, index: min(max(index, 0), items.count - 1))
    }

    /// 群聊 @ 名字映射（@全体成员 → 0）
    private var mentionMap: [String: Int64] {
        guard isGroup else { return [:] }
        var map: [String: Int64] = ["全体成员": 0]
        for m in members {
            let name = m.name ?? ""
            if !name.isEmpty { map[name] = m.uid }
        }
        return map
    }

    @ViewBuilder
    private func row(_ msg: Message, readHint: Int) -> some View {
        ChatMessageRow(
            message: msg,
            mine: msg.fromUid == myId,
            isGroup: isGroup,
            member: members.first { $0.uid == msg.fromUid },
            myAvatar: app.user?.avatar,
            myUid: myId,
            myName: app.user?.nickname ?? "我",
            peerName: title,
            readHint: readHint,
            playingVoice: voice.playingURL == VoiceService.cleanPath(msg.text ?? msg.content ?? ""),
            voicePlayed: playedVoice.contains(msg.listKey),
            mentionMap: mentionMap,
            onMention: { uid in
                if uid > 0 { profileTarget = ProfileTarget(id: uid) }
            },
            onVoiceTap: {
                playedVoice.insert(msg.listKey)
                voice.play(path: VoiceService.cleanPath(msg.text ?? msg.content ?? ""))
            },
            onRetry: {
                Task { await resend(msg) }
            },
            onAvatarTap: {
                profileTarget = ProfileTarget(id: msg.fromUid)
            },
            onAvatarLongPress: {
                guard isGroup, msg.fromUid != myId else { return }
                let name = members.first { $0.uid == msg.fromUid }?.name ?? msg.fromName ?? "成员"
                insertMention(name: name, uid: msg.fromUid)
            },
            onLongPress: {
                if selectMode { toggleSelect(msg) } else { menuTarget = msg }
            },
            onOpenLive: { gid in
                liveGid = gid
                showLive = true
            },
            onOpenGroup: { gid in
                previewGroupId = gid
                showGroupPreview = true
            },
            onOpenProfile: { uid in
                profileTarget = ProfileTarget(id: uid)
            },
            onQuoteLocate: { qid in
                jumpToQuote(qid)
            },
            onOpenRedPacket: { _ in
                payTarget = msg
            },
            onOpenPayCard: { m in
                payTarget = m
            },
            onCallBack: { type in
                if !isGroup { startCall(type) }
                else { callType = type; showGroupCall = true }
            },
            onOpenFile: { path in
                if let u = APIClient.fullURL(VoiceService.cleanPath(path)) {
                    UIApplication.shared.open(u)
                }
            },
            onOpenMoment: { uid in
                profileTarget = ProfileTarget(id: uid)
            },
            onOpenRecord: { raw in
                recordPayload = raw
                showRecord = true
            },
            onOpenAlbum: { urls, index in
                openAlbum(urls, index: index)
            }
        )
        .contentShape(Rectangle())
        .overlay {
            if selectMode {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { toggleSelect(msg) }
                    .onLongPressGesture { toggleSelect(msg) }
            }
        }
    }

    /// 长按菜单动作：顺序与安卓 ChatMenuSheet 一致
    private func handleMenu(_ key: String, msg: Message) {
        switch key {
        case "reply":
            replyTo = msg
            inputFocused = true
        case "copy":
            UIPasteboard.general.string = copyText(msg) ?? ""
            flash("已复制")
        case "forward":
            forwardMessages = [msg]
            forwardTitle = forwardRecordTitle
            showForward = true
        case "multi":
            selectedKeys = [msg.listKey]
            selectMode = true
        case "fav":
            Task {
                await APIClient.shared.addFavorite(message: msg, convName: title)
                flash("已收藏")
            }
        case "pin":
            if isGroup {
                Task { await togglePin(msg) }
            } else if pinMsgId == msg.id {
                Task { await clearPin() }
            } else {
                pinScopeTarget = msg
            }
        case "emoji":
            if let url = msg.text, !url.isEmpty {
                Task {
                    await app.addEmoji(url: url)
                    flash("已添加到我的表情")
                }
            }
        case "report":
            reportTarget = msg
        case "recall":
            confirm = .recall(msg)
        case "delete":
            confirm = .delete(msg)
        default:
            break
        }
    }

    private func insertText(_ value: String) {
        text += value
    }

    /// @ 某人：替换光标前刚输入的 @关键字，不重复拼 @@
    private func insertMention(name: String, uid: Int64) {
        var base = text
        if let at = base.lastIndex(of: "@") {
            let tail = base[base.index(after: at)...]
            if !tail.contains(where: { $0.isWhitespace }) {
                base = String(base[..<at])
            }
        }
        text = base + "@\(name) "
        if !atUids.contains(uid) { atUids.append(uid) }
        inputFocused = true
    }

    private func flash(_ message: String) {
        errorText = message
        errorToken += 1
        let token = errorToken
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                if token == errorToken { errorText = nil }
            }
        }
    }

    /* ---------------- 输入 ---------------- */

    /// 安卓式头部：返回 + 标题（徽章）+ 固定高度副标题（正在输入）+ 右侧更多
    private var chatHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22))
                        .foregroundColor(AKColor.text)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)

                VStack(spacing: 0) {
                    HStack(spacing: 3) {
                        Text(title)
                            .font(.system(size: 15.5, weight: .semibold))
                            .foregroundColor(AKColor.text)
                            .lineLimit(1)
                        if isGroup {
                            if let g = groupInfo, g.isPretty == 1, !g.displayNo.isEmpty {
                                PrettyBadge(number: g.displayNo, isGroup: true)
                            }
                        } else {
                            if let c = peerConv, c.isPretty == 1, let no = c.prettyNo, !no.isEmpty {
                                PrettyBadge(number: no)
                            }
                            if let c = peerConv, c.vipLevel > 0 {
                                VipBadge(level: c.vipLevel)
                            }
                        }
                        if convId == app.botUid {
                            BadgeView(text: "AI机器人", color: AKColor.link, background: AKColor.blueSoft)
                        }
                    }
                    ZStack {
                        if let typingName {
                            Text("\(typingName) 正在输入…")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AKColor.brand)
                                .lineLimit(1)
                        }
                    }
                    .frame(height: 18)
                }
                .frame(maxWidth: .infinity)

                Button {
                    if isGroup {
                        showGroupInfo = true
                    } else {
                        profileTarget = ProfileTarget(id: convId)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20))
                        .foregroundColor(AKColor.text)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 3)
            Rectangle().fill(AKColor.line).frame(height: 0.5)
        }
        .background(AKColor.card)
    }

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var placeholder: String {
        "发消息…"
    }

    private var inputBar: some View {
        HStack(spacing: 6) {
            Button {
                voiceMode.toggle()
                showMore = false
                showEmoji = false
                inputFocused = false
            } label: {
                Image(systemName: voiceMode ? "keyboard" : "mic")
                    .font(.system(size: 19))
                    .foregroundColor(voice.recording ? .white : AKColor.sub)
                    .frame(width: 36, height: 36)
                    .background(voice.recording ? AKColor.red : AKColor.fill)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            if voiceMode {
                Text(voice.recording ? "松开发送" : "按住 说话")
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundColor(AKColor.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(voice.recording ? AKColor.fill : AKColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .stroke(AKColor.line, lineWidth: 0.5)
                    )
                    .contentShape(Rectangle())
                    .gesture(recordGesture)
            } else {
                TextField(placeholder, text: $text, axis: .vertical)
                    .focused($inputFocused)
                    .lineLimit(1...4)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(AKColor.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .onChange(of: text) { value in
                        handleInputChange(value)
                    }
                    .onTapGesture {
                        showMore = false
                        showEmoji = false
                        voiceMode = false
                    }
            }

            Button {
                if showEmoji {
                    showEmoji = false
                    inputFocused = true
                } else {
                    showEmoji = true
                    showMore = false
                    voiceMode = false
                    inputFocused = false
                }
            } label: {
                Image(systemName: "face.smiling")
                    .font(.system(size: 21))
                    .foregroundColor(showEmoji ? AKColor.brand : AKColor.sub)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            if hasText {
                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(AKColor.brand)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(sending)
            } else {
                Button {
                    showMore.toggle()
                    showEmoji = false
                    voiceMode = false
                    inputFocused = false
                } label: {
                    Image(systemName: showMore ? "xmark" : "plus")
                        .font(.system(size: 22))
                        .foregroundColor(AKColor.sub)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(AKColor.card)
    }

    private func handleInputChange(_ value: String) {
        if isGroup, value.last == "@", !members.isEmpty {
            showAtPicker = true
        }
        guard !value.isEmpty, !(isGroup == false && convId == myId) else { return }
        let now = Date().timeIntervalSince1970
        if now - lastTypingSent > 2 {
            lastTypingSent = now
            Task { await APIClient.shared.sendTyping(convType: convType, convId: convId) }
        }
    }

    private var recordGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !voice.recording, !recordBusy {
                    recordReleased = false
                    startRecording()
                }
                voiceCancel = value.translation.height < -70
            }
            .onEnded { _ in
                recordReleased = true
                finishRecording()
            }
    }

    private func startRecording() {
        guard !recordBusy else { return }
        recordBusy = true
        Task {
            let ok = await voice.startRecording()
            await MainActor.run {
                recordBusy = false
                if !ok {
                    flash("未授权麦克风，无法录音")
                } else if recordReleased {
                    _ = voice.stopRecording()
                }
            }
        }
    }

    private func finishRecording() {
        let cancelled = voiceCancel
        voiceCancel = false
        guard voice.recording else { return }
        guard let (url, seconds) = voice.stopRecording() else { return }
        if cancelled {
            flash("已取消")
            return
        }
        Task {
            sending = true
            defer { sending = false }
            let local = makeLocal(type: 6, content: "")
            messages.append(local)
            do {
                let uploaded = try await app.uploadVoice(fileURL: url)
                let saved = try await app.sendVoice(convType: convType, convId: convId,
                                                    url: uploaded.url, seconds: seconds)
                replaceLocal(local, with: saved)
            } catch {
                failLocal(local, "语音发送失败：\(error.localizedDescription)")
            }
        }
    }

    private var recordingStrip: some View {
        HStack(spacing: 8) {
            Circle().fill(AKColor.red).frame(width: 8, height: 8)
            Text("松开发送")
                .font(.system(size: 12))
                .foregroundColor(AKColor.red)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(AKColor.redSoft)
    }

    /* ---------------- 数据 ---------------- */

    /* 聊天背景本地缓存：进会话先用缓存渲染，避免先白一下再出现背景 */
    private var bgKey: String { "ios_chat_bg_\(convType)_\(convId)" }
    private func cachedBg() -> String? {
        let v = UserDefaults.standard.string(forKey: bgKey) ?? ""
        return v.isEmpty ? nil : v
    }
    private func storeBg(_ url: String?) {
        UserDefaults.standard.set(url ?? "", forKey: bgKey)
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let list = try await app.loadHistory(convType: convType, convId: convId)
            messages = list.sorted { $0.id < $1.id }
            hasMore = list.count >= 40
            if unreadAnchor == 0, let c = peerConv, c.unread > 0 {
                let incoming = messages.filter { $0.fromUid != myId && $0.id > 0 }
                if incoming.count >= c.unread {
                    unreadAnchor = incoming[incoming.count - c.unread].id
                }
            }
            if let last = messages.last {
                await app.markRead(convType: convType, convId: convId, lastId: last.id)
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard !loadingMore, let first = messages.first, first.id > 0 else { return }
        loadingMore = true
        defer { loadingMore = false }
        do {
            let list = try await app.loadHistory(convType: convType, convId: convId, beforeId: first.id)
            if list.isEmpty {
                hasMore = false
                return
            }
            let known = Set(messages.map { $0.id })
            let older = list.filter { !known.contains($0.id) }.sorted { $0.id < $1.id }
            messages = older + messages
            if list.count < 40 { hasMore = false }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func loadMembers() async {
        if let info = try? await APIClient.shared.groupInfo(id: convId) {
            members = info.members
        }
    }

    private func loadPin() async {
        if isGroup {
            let list = (try? await APIClient.shared.groupTop(gid: convId)) ?? []
            if let last = list.last {
                pinText = last.digest
                pinMsgId = last.id
            } else {
                pinText = nil
                pinMsgId = 0
            }
        } else {
            localPinId = Int64(UserDefaults.standard.integer(forKey: localPinKey))
            if localPinId > 0 {
                pinMsgId = localPinId
                let text = UserDefaults.standard.string(forKey: localPinTextKey) ?? ""
                pinText = text.isEmpty ? "置顶消息" : text
            } else {
                let pin = try? await APIClient.shared.pinInfo(peer: convId)
                pinText = pin?.digest
                pinMsgId = pin?.msgId ?? 0
            }
        }
    }

    private var localPinKey: String { "ios_private_pin_\(convType)_\(convId)" }
    private var localPinTextKey: String { "ios_private_pin_text_\(convType)_\(convId)" }

    /// 私聊置顶范围：仅自己（本地） / 双方可见（写服务端）
    private func applyPinScope(shared: Bool) {
        guard let msg = pinScopeTarget else { return }
        pinScopeTarget = nil
        if shared {
            UserDefaults.standard.removeObject(forKey: localPinKey)
            UserDefaults.standard.removeObject(forKey: localPinTextKey)
            localPinId = 0
            Task {
                await APIClient.shared.setPinScoped(peer: convId, msgId: msg.id, shared: true)
                await loadPin()
                flash("已置顶（双方可见）")
            }
        } else {
            let text = digest(msg)
            UserDefaults.standard.set(Int(msg.id), forKey: localPinKey)
            UserDefaults.standard.set(text, forKey: localPinTextKey)
            localPinId = msg.id
            pinMsgId = msg.id
            pinText = text
            flash("已置顶（仅自己可见）")
        }
    }

    private func loadPendingNotice() async {
        guard let notice = await APIClient.shared.pendingGroupNotice(gid: convId) else { return }
        pendingNotice = notice
        showNotice = true
    }

    /* ---------------- 发送 ---------------- */

    private func makeLocal(type: Int, content: String) -> Message {
        localSeq -= 1
        return Message(local: convType, convId: convId, fromUid: myId, type: type, content: content, localId: localSeq)
    }

    private func replaceLocal(_ local: Message, with saved: Message) {
        if let idx = messages.firstIndex(where: { $0.localId == local.localId }) {
            messages[idx] = saved
        } else if !messages.contains(where: { $0.id == saved.id && saved.id != 0 }) {
            messages.append(saved)
        }
    }

    private func failLocal(_ local: Message, _ why: String) {
        if let idx = messages.firstIndex(where: { $0.localId == local.localId }) {
            messages[idx].status = 2
        }
        errorText = why
    }

    /// 支付类消息发送后重新拉一次，确保卡片立刻出现
    private func reloadAfterPay() async {
        await load()
    }

    private func startCall(_ type: Int) {
        guard !isGroup else { return }
        Task {
            await CallManager.shared.start(peerUid: convId, name: title, avatar: nil, type: type)
            showCall = true
        }
    }

    private func send() async {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !sending else { return }
        let at = atUids.map { $0 == -1 ? "all" : String($0) }.joined(separator: ",")
        let quote = replyTo
        text = ""
        atUids = []
        replyTo = nil
        errorText = nil
        sending = true
        defer { sending = false }

        if let quote, quote.id > 0 {
            let extra = quotePayload(quote)
            let local = makeLocal(type: 10, content: extra + "|#|" + content)
            messages.append(local)
            do {
                let saved = try await APIClient.shared.sendTypedMessage(
                    convType: convType, convId: convId, type: 10,
                    content: extra + "|#|" + content,
                    clientId: local.clientId ?? "ios_\(UUID().uuidString)",
                    atUids: at
                )
                replaceLocal(local, with: saved.message)
                await app.refreshConversations()
            } catch {
                failLocal(local, "发送失败：\(error.localizedDescription)")
            }
            return
        }

        let local = makeLocal(type: 1, content: content)
        messages.append(local)
        do {
            let saved = try await app.sendText(convType: convType, convId: convId, text: content, atUids: at)
            replaceLocal(local, with: saved)
        } catch {
            failLocal(local, "发送失败：\(error.localizedDescription)")
        }
    }

    private func quotePayload(_ msg: Message) -> String {
        let obj: [String: Any] = [
            "quote_id": msg.id,
            "quote_name": replyDisplayName(msg),
            "quote_content": digest(msg)
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: obj) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func resend(_ msg: Message) async {
        guard let idx = messages.firstIndex(where: { $0.localId == msg.localId }) else { return }
        messages[idx].status = 0
        errorText = nil
        do {
            let saved: Message
            if msg.type == 10, let raw = msg.content {
                let data = try await APIClient.shared.sendTypedMessage(
                    convType: convType, convId: convId, type: 10, content: raw,
                    clientId: msg.clientId ?? "ios_\(UUID().uuidString)"
                )
                saved = data.message
            } else {
                saved = try await app.sendText(convType: convType, convId: convId, text: msg.content ?? msg.text ?? "")
            }
            replaceLocal(messages[idx], with: saved)
        } catch {
            failLocal(messages[idx], "发送失败：\(error.localizedDescription)")
        }
    }

    private func sendPhotoData(_ data: Data) async {
        guard !sending else { return }
        sending = true
        defer { sending = false }
        do {
            let local = makeLocal(type: 5, content: "")
            messages.append(local)
            let uploaded = try await app.uploadImage(data)
            let saved = try await app.sendImage(convType: convType, convId: convId, url: uploaded.url)
            replaceLocal(local, with: saved)
        } catch {
            errorText = "图片发送失败：\(error.localizedDescription)"
        }
    }

    private func sendSticker(_ url: String) async {
        guard !sending else { return }
        sending = true
        defer { sending = false }
        do {
            let saved = try await app.sendSticker(convType: convType, convId: convId, url: url)
            messages.append(saved)
        } catch {
            errorText = "表情发送失败：\(error.localizedDescription)"
        }
    }

    /* ---------------- 操作 ---------------- */

    private func recall(_ msg: Message) async {
        guard msg.id > 0 else { return }
        do {
            try await app.recall(convType: convType, id: msg.id)
            if let idx = messages.firstIndex(where: { $0.id == msg.id }) {
                let label: String
                if msg.fromUid == myId {
                    label = "你撤回了一条消息"
                } else {
                    let nickname = app.user?.nickname ?? ""
                    let op = nickname.isEmpty ? "群成员" : nickname
                    let author = members.first { $0.uid == msg.fromUid }?.name ?? msg.fromName ?? "群成员"
                    label = "\(op) 撤回了 \(author) 的一条消息"
                }
                messages[idx].type = 11
                messages[idx].text = label
                messages[idx].recalled = 1
            }
        } catch {
            errorText = "撤回失败：\(error.localizedDescription)"
        }
    }

    private func sendPhotos(_ images: [UIImage], caption: String) async {
        guard !images.isEmpty, !sending else { return }
        sending = true
        defer { sending = false }
        let cap = caption.trimmingCharacters(in: .whitespacesAndNewlines)

        if images.count == 1 {
            let local = makeLocal(type: 5, content: "")
            messages.append(local)
            do {
                guard let data = images[0].jpegData(compressionQuality: 0.85) else {
                    throw APIError.server("读取图片失败")
                }
                let up = try await app.uploadImage(data)
                var extra: [String: Any] = [:]
                if up.w > 0, up.h > 0 {
                    extra["w"] = up.w
                    extra["h"] = up.h
                }
                if !cap.isEmpty { extra["caption"] = cap }
                var payload = up.url
                if !extra.isEmpty,
                   let json = try? JSONSerialization.data(withJSONObject: extra),
                   let text = String(data: json, encoding: .utf8) {
                    payload += "|#|" + text
                }
                let saved = try await APIClient.shared.sendTypedMessage(
                    convType: convType, convId: convId, type: 5, content: payload,
                    clientId: local.clientId ?? "ios_\(UUID().uuidString)"
                )
                replaceLocal(local, with: saved.message)
                await app.refreshConversations()
            } catch {
                failLocal(local, "图片发送失败：\(error.localizedDescription)")
            }
            return
        }

        var imgs: [[String: Any]] = []
        for image in images {
            guard let data = image.jpegData(compressionQuality: 0.85),
                  let up = try? await app.uploadImage(data) else { continue }
            imgs.append(["url": up.url, "w": up.w, "h": up.h])
        }
        guard !imgs.isEmpty else {
            flash("图片上传失败")
            return
        }
        let obj: [String: Any] = ["imgs": imgs, "caption": cap]
        guard let data = try? JSONSerialization.data(withJSONObject: obj),
              let payload = String(data: data, encoding: .utf8) else { return }
        let local = makeLocal(type: 31, content: payload)
        messages.append(local)
        do {
            let saved = try await APIClient.shared.sendTypedMessage(
                convType: convType, convId: convId, type: 31, content: payload,
                clientId: local.clientId ?? "ios_\(UUID().uuidString)"
            )
            replaceLocal(local, with: saved.message)
            await app.refreshConversations()
        } catch {
            failLocal(local, "图片发送失败：\(error.localizedDescription)")
        }
    }

    private func deleteLocalSilently(_ msg: Message) {
        messages.removeAll { $0.listKey == msg.listKey }
    }

    private func deleteLocal(_ msg: Message) {
        deleteLocalSilently(msg)
        flash("已删除")
    }

    private func togglePin(_ msg: Message) async {
        if isGroup {
            let top = pinMsgId != msg.id
            await APIClient.shared.setGroupTop(gid: convId, msgId: msg.id, top: top)
        } else {
            let msgId = pinMsgId == msg.id ? 0 : msg.id
            await APIClient.shared.setPin(peer: convId, msgId: msgId)
        }
        await loadPin()
    }

    private func clearPin() async {
        if isGroup {
            await APIClient.shared.setGroupTop(gid: convId, msgId: pinMsgId, top: false)
        } else {
            UserDefaults.standard.removeObject(forKey: localPinKey)
            UserDefaults.standard.removeObject(forKey: localPinTextKey)
            localPinId = 0
            await APIClient.shared.setPin(peer: convId, msgId: 0)
        }
        await loadPin()
    }

    private func appendAt(uid: Int64, name: String) {
        let display: String
        if uid == -1 {
            display = "全体成员"
        } else {
            display = members.first(where: { $0.uid == uid })?.name ?? name
        }
        insertMention(name: display.isEmpty ? "成员" : display, uid: uid)
    }

    private func handle(_ ev: ChatEvent) {
        switch ev.kind {
        case "recall":
            guard ev.convId == convId, let idx = messages.firstIndex(where: { $0.id == ev.msgId }) else { return }
            messages[idx].type = 11
            messages[idx].text = ev.text
            messages[idx].recalled = 1
        case "typing":
            guard ev.convType == convType, ev.convId == convId, ev.fromUid != myId else { return }
            typingName = ev.name.isEmpty ? "对方" : ev.name
            typingToken += 1
            let token = typingToken
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await MainActor.run {
                    if token == typingToken { typingName = nil }
                }
            }
        case "group_top":
            if isGroup && ev.convId == convId { Task { await loadPin() } }
        case "group_notice":
            if isGroup && ev.convId == convId { Task { await loadPendingNotice() } }
        default:
            break
        }
    }
}

/* ---------------- 单条消息 ---------------- */

private struct ChatMessageRow: View {
    let message: Message
    let mine: Bool
    let isGroup: Bool
    let member: GroupMember?
    let myAvatar: String?
    let myUid: Int64
    let myName: String
    var peerName: String = "对方"
    let readHint: Int
    let playingVoice: Bool
    var voicePlayed: Bool = true
    var mentionMap: [String: Int64] = [:]
    var onMention: (Int64) -> Void = { _ in }
    let onVoiceTap: () -> Void
    let onRetry: () -> Void
    let onAvatarTap: () -> Void
    var onAvatarLongPress: () -> Void = {}
    var onLongPress: () -> Void = {}
    var onOpenLive: (Int64) -> Void = { _ in }
    var onOpenGroup: (Int64) -> Void = { _ in }
    var onOpenProfile: (Int64) -> Void = { _ in }
    var onQuoteLocate: (Int64) -> Void = { _ in }
    var onOpenRedPacket: (Int64) -> Void = { _ in }
    var onOpenPayCard: (Message) -> Void = { _ in }
    var onCallBack: (Int) -> Void = { _ in }
    var onOpenFile: (String) -> Void = { _ in }
    var onOpenMoment: (Int64) -> Void = { _ in }
    var onOpenRecord: (String) -> Void = { _ in }
    var onOpenAlbum: ([String], Int) -> Void = { _, _ in }

    private var displayName: String {
        let name = member?.name ?? message.fromName ?? ""
        return name.isEmpty ? "成员" : name
    }

    private var nameColor: Color {
        if let m = member {
            return akNameColor(vipLevel: m.vipLevel, isPretty: m.isPretty, isGroup: true)
        }
        return AKColor.text
    }

    /// 气泡最大宽度：屏宽 68%（对齐安卓 maxBubble 0.68）
    private var maxBubble: CGFloat { UIScreen.main.bounds.width * 0.68 }

    private var bodyView: MessageBody {
        MessageBody(
            message: message,
            mine: mine,
            myUid: myUid,
            myName: myName,
            playingVoice: playingVoice,
            onVoiceTap: onVoiceTap,
            onOpenLive: onOpenLive,
            onOpenGroup: onOpenGroup,
            onOpenProfile: onOpenProfile,
            onQuoteLocate: onQuoteLocate,
            onOpenRedPacket: onOpenRedPacket,
            onOpenPayCard: onOpenPayCard,
            onCallBack: onCallBack,
            onOpenFile: onOpenFile,
            onOpenMoment: onOpenMoment,
            onOpenRecord: onOpenRecord,
            onOpenAlbum: onOpenAlbum,
            peerName: peerName,
            mentionMap: mentionMap,
            onMention: onMention,
            voicePlayed: voicePlayed
        )
    }

    var body: some View {
        if message.type == 11 || message.recalled == 1 {
            HStack {
                Spacer(minLength: 36)
                bodyView
                Spacer(minLength: 36)
            }
        } else {
            HStack(alignment: .top, spacing: 0) {
                if mine {
                    Spacer(minLength: 44)
                } else {
                    AvatarView(url: message.fromAvatar, name: displayName, size: 34)
                        .padding(.top, isGroup ? 17 : 0)
                        .onTapGesture { onAvatarTap() }
                        .onLongPressGesture { onAvatarLongPress() }
                    Spacer().frame(width: 7)
                }

                VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
                    if !mine && isGroup {
                        HStack(spacing: 3) {
                            Text(displayName)
                                .font(.system(size: 11))
                                .foregroundColor(nameColor)
                                .lineLimit(1)
                            if let m = member, m.isPretty == 1 {
                                PrettyBadge(number: m.prettyNo ?? "")
                            }
                            if let m = member, m.vipLevel > 0 {
                                VipBadge(level: m.vipLevel)
                            }
                            let role = member?.role ?? message.fromRole
                            if role == 1 || role == 2 {
                                RoleBadge(role: role)
                            }
                        }
                        .padding(.leading, 6)
                        .padding(.bottom, 5)
                    }

                    bodyView
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 0.35) { onLongPress() }

                    HStack(spacing: 4) {
                        if message.status == 2 {
                            Button(action: onRetry) {
                                Text("发送失败，点击重发")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(AKColor.red)
                            }
                            .buttonStyle(.plain)
                        } else if message.status == 0 {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 10, height: 10)
                        }
                        Text(ChatClock.clock(message.createdAt))
                            .font(.system(size: 9.5))
                            .foregroundColor(AKColor.placeholder)
                        if readHint == 1 {
                            Text("未读")
                                .font(.system(size: 10))
                                .foregroundColor(AKColor.hint)
                        } else if readHint == 2 {
                            Text("已读")
                                .font(.system(size: 10))
                                .foregroundColor(AKColor.link)
                        }
                    }
                }
                .frame(maxWidth: maxBubble, alignment: mine ? .trailing : .leading)

                if mine {
                    Spacer().frame(width: 7)
                    AvatarView(url: myAvatar, name: "我", size: 34)
                        .onTapGesture { onAvatarTap() }
                } else {
                    Spacer(minLength: 44)
                }
            }
        }
    }
}

/* ---------------- 长按菜单 / 拍照预览 / 录音浮层 ---------------- */

/// 长按菜单：2~3 行 4 列图标网格，条目顺序对齐安卓 ChatMenuSheet
private struct ChatMessageMenuSheet: View {
    let message: Message
    let isGroup: Bool
    let mine: Bool
    let myRole: Int
    let pinned: Bool
    let canRecall: Bool
    let canPin: Bool
    let canAddEmoji: Bool
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private struct Item: Identifiable {
        let key: String
        let label: String
        let icon: String
        var danger: Bool = false
        var id: String { key }
    }

    private var copyable: String? {
        switch message.type {
        case 1, 10:
            let t = message.text ?? message.content ?? ""
            return t.isEmpty ? nil : t
        case 2, 20: return "[充值申请]"
        case 3: return "[提现申请]"
        case 5: return "[图片]"
        case 6: return "[语音]"
        case 7, 21: return "[红包]"
        case 8, 22: return "[转账]"
        case 9, 23: return "[礼物]"
        case 12: return "[名片]"
        case 13: return "[群名片]"
        case 14: return "[通话]"
        case 15: return "[视频]"
        case 16: return "[动态]"
        case 17: return "[聊天记录]"
        case 18: return "[文件]"
        case 19: return "[直播]"
        case 31: return "[图片]"
        case 11: return nil
        default:
            let t = (message.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return (t.isEmpty || t.hasPrefix("{")) ? nil : t
        }
    }

    private var items: [Item] {
        var out: [Item] = []
        if message.type != 11 {
            out.append(Item(key: "reply", label: "回复", icon: "arrowshape.turn.up.left"))
        }
        if copyable != nil {
            out.append(Item(key: "copy", label: "复制", icon: "doc.on.doc"))
        }
        if message.type != 11 {
            out.append(Item(key: "forward", label: "转发", icon: "arrowshape.turn.up.right"))
            out.append(Item(key: "multi", label: "多选", icon: "checklist"))
        }
        if message.type != 11 {
            out.append(Item(key: "fav", label: "收藏", icon: "star"))
        }
        if canPin {
            out.append(Item(key: "pin", label: pinned ? "取消置顶" : "置顶", icon: "pin"))
        }
        if canAddEmoji {
            out.append(Item(key: "emoji", label: "添加到表情", icon: "face.smiling"))
        }
        if !mine {
            out.append(Item(key: "report", label: "举报", icon: "flag", danger: true))
        }
        if canRecall {
            out.append(Item(key: "recall", label: mine ? "撤回" : "撤回该消息",
                            icon: "arrow.uturn.backward", danger: true))
        }
        out.append(Item(key: "delete", label: "删除", icon: "trash", danger: true))
        return out
    }

    var body: some View {
        let rows = stride(from: 0, to: items.count, by: 4).map { Array(items[$0..<min($0 + 4, items.count)]) }
        VStack(spacing: 0) {
            Capsule()
                .fill(AKColor.line)
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 6)
            ForEach(rows.indices, id: \.self) { i in
                HStack(spacing: 0) {
                    ForEach(rows[i]) { item in
                        Button {
                            dismiss()
                            onPick(item.key)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 22))
                                Text(item.label)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                            }
                            .foregroundColor(item.danger ? AKColor.red : AKColor.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    if rows[i].count < 4 {
                        ForEach(0..<(4 - rows[i].count), id: \.self) { _ in
                            Spacer().frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .background(AKColor.card)
        .presentationDetents([.height(items.count > 4 ? 250 : 170)])
        .presentationDragIndicator(.hidden)
    }
}

/// 发送前预览：单图整张 / 多图 2 列编号网格 + 说明输入（对齐安卓 PhotoSendPreview）
private struct PhotoSendPreview: View {
    let images: [UIImage]
    @Binding var caption: String
    let onCancel: () -> Void
    let onSend: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("已选中 \(images.count) 张图片")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AKColor.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .foregroundColor(AKColor.sub)
                        .frame(width: 34, height: 34)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 18)
            .padding(.trailing, 8)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .background(AKColor.card)

            if images.count == 1, let image = images.first {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(10)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)],
                              spacing: 6) {
                        ForEach(images.indices, id: \.self) { i in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: images[i])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipped()
                                Text("\(i + 1)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 22, height: 22)
                                    .background(Color(hex: 0xFF6A00))
                                    .clipShape(Circle())
                                    .padding(6)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .padding(8)
                }
            }

            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 20))
                        .foregroundColor(AKColor.placeholder)
                    TextField("添加说明…", text: $caption)
                        .font(.system(size: 15))
                        .foregroundColor(AKColor.text)
                        .onChange(of: caption) { value in
                            if value.count > 500 { caption = String(value.prefix(500)) }
                        }
                }
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))

                Button {
                    onSend(caption.trimmingCharacters(in: .whitespacesAndNewlines))
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .background(AKColor.brand)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AKColor.card)
        }
        .background(AKColor.bg)
    }
}

/// 录音浮层：波形 + 正在录音… + 上滑取消 / 松开取消
private struct RecordingOverlay: View {
    let cancel: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 12) {
                TimelineView(.animation) { ctx in
                    let t = ctx.date.timeIntervalSince1970
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { i in
                            let phase: Double = t * 4 + Double(i) * 0.6
                            let ratio: Double = 0.5 + 0.5 * sin(phase)
                            let h: CGFloat = CGFloat(8.0 + 16.0 * ratio)
                            Capsule()
                                .fill(Color(hex: 0x4ADE80))
                                .frame(width: 4, height: h)
                        }
                    }
                    .frame(height: 32)
                }
                Text("正在录音…")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
                Text(cancel ? "松开取消" : "上滑取消")
                    .font(.system(size: 12))
                    .foregroundColor(cancel ? Color(hex: 0xFF4D4F) : Color(hex: 0xFF7A8A))
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .background(Color(hex: 0x181C24).opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .allowsHitTesting(false)
    }
}

/* ---------------- 辅助页面 ---------------- */

private struct AtMemberPicker: View {
    let members: [GroupMember]
    let myRole: Int
    let onPick: (Int64, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var keyword = ""

    private var filtered: [GroupMember] {
        let q = keyword.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return members }
        return members.filter { m in
            (m.name ?? "").localizedCaseInsensitiveContains(q)
                || (m.prettyNo ?? "").localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.muted)
                    TextField("搜索成员", text: $keyword)
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 10)
                .frame(height: 36)
                .background(AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(12)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        if (myRole == 1 || myRole == 2), keyword.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button {
                                onPick(-1, "全体成员")
                                dismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    Text("@")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 36, height: 36)
                                        .background(Color(hex: 0xFF9F0A))
                                        .clipShape(Circle())
                                    Text("全体成员")
                                        .font(.system(size: 14.5))
                                        .foregroundColor(AKColor.text)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                        ForEach(filtered) { member in
                            Button {
                                onPick(member.uid, member.name ?? "")
                                dismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    AvatarView(url: member.avatar, name: member.name ?? "成员", size: 36)
                                    Text(member.name ?? "成员")
                                        .font(.system(size: 14.5))
                                        .foregroundColor(akNameColor(vipLevel: member.vipLevel,
                                                                    isPretty: member.isPretty,
                                                                    isGroup: false))
                                    if member.isPretty == 1 {
                                        PrettyBadge(number: member.prettyNo ?? "")
                                    }
                                    if member.vipLevel > 0 {
                                        VipBadge(level: member.vipLevel)
                                    }
                                    if member.role == 1 || member.role == 2 {
                                        RoleBadge(role: member.role)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 340)
            }
            .background(AKColor.card)
            .navigationTitle("选择要提醒的人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(430)])
    }
}

/* ---------------- 聊天页辅助视图 ---------------- */

/// 与安卓 ChatTime.label 同一口径：今天 HH:mm / 昨天 HH:mm / M月d日 HH:mm / yyyy年M月d日 HH:mm
private enum ChatClock {
    private static let tz = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)!

    private static func make(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = tz
        f.dateFormat = pattern
        return f
    }

    private static let hm = make("HH:mm")
    private static let md = make("M月d日 HH:mm")
    private static let ymd = make("yyyy年M月d日 HH:mm")
    private static let year = make("yyyy")

    private static func dayIndex(_ ts: Int64) -> Int64 { (ts + 8 * 3600) / 86400 }

    static func sameDay(_ a: Int64, _ b: Int64) -> Bool {
        guard a > 0, b > 0 else { return false }
        return dayIndex(a) == dayIndex(b)
    }

    static func clock(_ ts: Int64) -> String {
        guard ts > 0 else { return "" }
        return hm.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }

    static func label(_ ts: Int64) -> String {
        guard ts > 0 else { return "" }
        let now = Int64(Date().timeIntervalSince1970)
        let d = Date(timeIntervalSince1970: TimeInterval(ts))
        let day = dayIndex(ts)
        let today = dayIndex(now)
        if day == today { return hm.string(from: d) }
        if day == today - 1 { return "昨天 " + hm.string(from: d) }
        if year.string(from: d) == year.string(from: Date()) { return md.string(from: d) }
        return ymd.string(from: d)
    }
}

/// 举报消息：选原因 + 补充说明（对齐安卓 ReportDialog）
private struct ReportMessageSheet: View {
    let message: Message
    let onSubmit: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var picked = -1
    @State private var note = ""

    private let reasons = ["色情低俗", "诈骗/赌博", "骚扰广告", "侵权内容"]

    private var preview: String {
        let raw = message.text ?? message.content ?? ""
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty || t.hasPrefix("{") { return "[消息]" }
        return String(t.prefix(60))
    }

    var body: some View {
        Form {
            Section("举报内容") {
                Text(preview)
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.sub)
                    .lineLimit(3)
            }
            Section("请选择举报原因") {
                ForEach(reasons.indices, id: \.self) { i in
                    Button {
                        picked = i
                    } label: {
                        HStack {
                            Text(reasons[i]).foregroundColor(AKColor.text)
                            Spacer()
                            Image(systemName: picked == i ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(picked == i ? AKColor.brand : AKColor.hint)
                        }
                    }
                }
            }
            Section("补充说明（选填）") {
                TextField("请描述具体情况…", text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .navigationTitle("举报该消息")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("提交举报") {
                    guard picked >= 0 else { return }
                    onSubmit(reasons[picked], note.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                }
                .disabled(picked < 0)
            }
        }
    }
}

/// 聊天记录卡片展开：展示转发时打包的消息列表
private struct ChatRecordSheet: View {
    let payload: String

    @Environment(\.dismiss) private var dismiss

    private var parsed: (title: String, lines: [(name: String, text: String)]) {
        guard let o = MessageBody.jsonObject(payload) else { return ("聊天记录", []) }
        let title = (o["title"] as? String) ?? "聊天记录"
        var out: [(String, String)] = []
        if let items = o["items"] as? [Any] {
            for item in items {
                guard let m = item as? [String: Any] else { continue }
                out.append(((m["u"] as? String) ?? "", (m["c"] as? String) ?? ""))
            }
        }
        return (title, out)
    }

    var body: some View {
        List {
            let data = parsed
            Section(data.title) {
                if data.lines.isEmpty {
                    Text("聊天记录").foregroundColor(AKColor.muted)
                } else {
                    ForEach(data.lines.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 3) {
                            if !data.lines[i].name.isEmpty {
                                Text(data.lines[i].name)
                                    .font(.system(size: 11))
                                    .foregroundColor(AKColor.muted)
                            }
                            Text(data.lines[i].text)
                                .font(.system(size: 14))
                                .foregroundColor(AKColor.text)
                        }
                    }
                }
            }
        }
        .navigationTitle("聊天记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
        }
    }
}

/// 视频消息全屏播放
private struct VideoPreviewSheet: View {
    let url: URL?

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                Text("视频不可用").foregroundColor(AKColor.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.black)
        .navigationTitle("视频")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
        }
        .onAppear {
            if let url { player = AVPlayer(url: url) }
        }
        .onDisappear { player?.pause() }
    }
}

/// 系统相机拍照发送
private struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onImage(image) }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}

extension APIClient {
    /// 引用消息（type=10）：content = quoteJSON + "|#|" + 正文
    func sendTypedMessage(
        convType: String,
        convId: Int64,
        type: Int,
        content: String,
        clientId: String,
        atUids: String = ""
    ) async throws -> SendData {
        var body: [String: Any] = [
            "conv_type": convType,
            "conv_id": convId,
            "type": type,
            "content": content,
            "client_msg_id": clientId
        ]
        if !atUids.isEmpty { body["at_uids"] = atUids }
        return try await post("api/v1/messages", body: body)
    }

    /// 私聊置顶：scope = all（双方可见）；仅自己可见在本地记录，不调接口
    func setPinScoped(peer: Int64, msgId: Int64, shared: Bool) async {
        await postIgnore("api/v1/pin", body: [
            "conv_type": "private",
            "conv_id": peer,
            "msg_id": msgId,
            "scope": shared ? "all" : "self"
        ])
    }
}

