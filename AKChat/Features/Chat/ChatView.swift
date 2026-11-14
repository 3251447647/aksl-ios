import SwiftUI
import PhotosUI
import Combine
import UIKit
import AVKit
import AVFoundation
import UniformTypeIdentifiers

struct ProfileTarget: Identifiable {
    let id: Int64
    var gid: Int64 = 0
}

/// 定位请求：seq 变化保证同一条消息连点也能重新触发 ScrollViewReader 的滚动
private struct ChatScrollLocate: Equatable {
    let key: String
    let seq: Int
}

/// 群名片/群资料跳转：gid 随路由一起传递，不再先写状态再翻 isPresented
struct GroupRoute: Identifiable, Hashable {
    let id: Int64
}

/// 消息列表几何探针：只记录视口高度与最后一行底部，不触发视图刷新
private final class ChatScrollProbe {
    var listHeight: CGFloat = 0
    var bottomEdge: CGFloat = 0
}

private struct ChatListHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ChatBottomEdgeKey: PreferenceKey {
    static var defaultValue: CGFloat? { nil }
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        if let next = nextValue() { value = next }
    }
}

/// 已落到临时文件的待发视频：发送失败后重试直接重传，不用再选一次相册
private struct PendingVideo {
    let fileURL: URL
    var duration: Int
    var cover: String
    var width: Double
    var height: Double
    /// 本地抽出的首帧：pending 气泡立刻能显示，不等封面上传
    var coverImage: UIImage?
}

/// 输入框文字单独持有：@Published 只被输入子视图订阅，打字不会带着整个 ChatView 与消息列表重算
private final class ChatComposerState: ObservableObject {
    @Published var text = ""
}

/// 直播间入口：gid 与呈现动作放在同一个值里，避免 isPresented + 独立 @State 在呈现瞬间取到旧值
private struct LiveRoute: Identifiable {
    let gid: Int64
    var id: Int64 { gid }
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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.tabIsActive) private var tabIsActive

    let convType: String
    let convId: Int64
    let title: String

    @State private var messages: [Message] = []
    @StateObject private var composer = ChatComposerState()
    @State private var showEmoji = false
    @StateObject private var voice = VoiceService()
    @State private var sending = false
    @State private var loading = false
    /// 首批历史已经成功回来（0 条也算）：之前不能渲染「暂无消息」，否则进会话先闪一下空态
    @State private var didLoad = false
    @State private var loadingMore = false
    @State private var hasMore = false
    /// 上滑翻页的游标：这一串历史已经翻到的服务端最小 id
    @State private var historyCursor: Int64 = 0
    /// 已经翻到这一串历史的开头（服务端 has_more=0）：之后不再请求更早的消息
    @State private var reachedHistoryStart = false
    @State private var errorText: String?
    @State private var showGroupInfo = false
    @State private var reportTarget: Message?
    @State private var confirm: ChatConfirm?
    /// 菜单弹层收起后再弹二次确认：在 sheet 消失动画期间直接改 confirm，alert 会被系统丢掉
    @State private var pendingConfirm: ChatConfirm?
    @State private var replyTo: Message?
    @State private var payTarget: Message?
    /// 卡片状态轮询：别人领取红包/转账/礼物后服务端会更新原消息或推送领取事件，
    /// WS 漏帧时靠它兜底；3 秒一次，只在会话可见且还有未完成卡片时执行。
    @State private var cardPollTask: Task<Void, Never>?
    /// 开页时发起的并行拉取；页面退场时统一取消，避免关掉会话后请求还在跑
    @State private var pageTasks: [Task<Void, Never>] = []
    @StateObject private var derivedCache = ChatDerivedCache()
    @State private var cardRefreshing = false
    @State private var lastCardRefresh: TimeInterval = 0
    @State private var recordPayload: String?
    @State private var showRecord = false
    @State private var videoURL: URL?
    @State private var showVideo = false
    @State private var showNotices = false
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
    /// 已经弹过的公告指纹（id|正文）：同一条只弹一次，公告被编辑后重新弹
    @State private var noticePopupFingerprint = ""
    @State private var scrollTarget: ChatScrollLocate?
    /// 定位请求序号：同一条消息连点也要能重新触发 onChange
    @State private var locateSeq = 0
    @State private var localSeq: Int64 = -1
    @State private var profileTarget: ProfileTarget?
    @State private var showForward = false
    @State private var forwardMessages: [Message] = []
    @State private var chatBg: String?
    @State private var liveRoute: LiveRoute?
    @State private var active: GroupActiveData?
    @State private var groupInfo: GroupInfo?
    /// /group 里 Core 模型没映射的字段（成员信息可见性）：仅用于拦截进他人主页
    @State private var groupExtras: GroupInfoExtras?
    @State private var showGroupCall = false
    @State private var showMore = false
    @State private var showPhotoPicker = false
    @State private var showVideoPicker = false
    @State private var videoItem: PhotosPickerItem?
    /// 视频上传百分比（键为消息 listKey），气泡上显示「视频 N%」
    @State private var uploadProgress: [String: Double] = [:]
    @State private var pendingVideos: [String: PendingVideo] = [:]
    /// 首次加载完成信号：进会话无条件贴底一次
    @State private var initialScrollTick = 0
    /// 首次贴底完成：此前的消息变化不触发带动画的跟随，避免进会话先飘一下
    @State private var initialScrollDone = false
    @State private var showRedPacket = false
    @State private var showTransfer = false
    @State private var showGift = false
    @State private var callType = 1
    @State private var groupRoute: GroupRoute?
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
    @State private var showEmojiPicker = false
    @State private var emojiItems: [PhotosPickerItem] = []
    @State private var forwardTitle = "聊天记录"
    @State private var errorToken = 0
    @State private var unreadAnchor: Int64 = 0
    @State private var pinScopeTarget: Message?
    @State private var localPinId: Int64 = 0
    /// 引用跳转后的短暂高亮（对齐安卓 highlightId）
    @State private var highlightId: Int64 = 0
    /// 自己撤回过的消息原文：只有撤回者知道原文，用于「重新编辑」
    @State private var recallOriginals: [Int64: String] = [:]
    /// 列表是否贴底：只有贴底时才跟随键盘/面板/新消息滚动，上滑看历史不抢视口
    @State private var atBottom = true
    @State private var scrollProbe = ChatScrollProbe()

    private var myId: Int64 { app.user?.id ?? 0 }
    private var isGroup: Bool { convType == "group" }

    /// 会随别人操作变化、需要刷新的卡片类型：充值/提现/红包/转账/礼物
    private let cardMessageTypes: Set<Int> = [2, 3, 7, 8, 9, 20, 21, 22, 23]

    /// 私聊对方在会话列表里的信息（靓号/VIP 徽章用）。缓存一份，避免每次 body 都 first(where:)
    @State private var peerConv: Conversation?

    private func syncPeerConv() {
        peerConv = app.conversations.first { $0.convType == convType && $0.convId == convId }
    }

    /// 群内进行中的通话/直播横条（对齐安卓 GroupActiveBar）
    @ViewBuilder
    private var activeBar: some View {
        if let live = active?.live, live.liveId > 0 {
            Button {
                liveRoute = LiveRoute(gid: convId)
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
            if isGroup, let notice = noticeBarText {
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
                                composer.text = q
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
                        onVideo: { showMore = false; showVideoPicker = true },
                        onRedPacket: { showMore = false; showRedPacket = true },
                        onTransfer: { showMore = false; showTransfer = true },
                        onGift: { showMore = false; showGift = true },
                        onVideoCall: { showMore = false; startCall(2) },
                        onGroupCall: { type in
                            showMore = false
                            callType = type
                            showGroupCall = true
                        },
                        onGroupLive: {
                            showMore = false
                            liveRoute = LiveRoute(gid: convId)
                        }
                    )
                }
            }
        }
        .background(
            ZStack {
                if let chatBg {
                    AKImage(url: chatBg,
                            size: UIScreen.main.bounds.size,
                            contentMode: .fill,
                            placeholder: AKColor.bg)
                        .clipped()
                    AKColor.bg.opacity(0.42)
                } else {
                    AKColor.bg
                }
            }
            .ignoresSafeArea()
        )
        /* 承载会话页的 window / 导航容器底色也刷成页面底色：push 转场期间不会露白 */
        .appPageBackdrop()
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
        .navigationDestination(isPresented: $showGroupInfo) {
            GroupInfoView(groupId: convId)
                .restoresSwipeBack()
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
                            confirmGroupNotice(pendingNotice)
                        },
                        groupName: groupInfo?.name ?? title,
                        groupAvatar: groupInfo?.avatar,
                        onOpenProfile: {
                            showNotice = false
                            showGroupInfo = true
                        }
                    )
                }
                .transition(.opacity)
            }
        }
        .fullScreenCover(item: $previewImage, onDismiss: { flushPendingConfirm() }) { item in
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
                onRecall: { msg in pendingConfirm = .recall(msg) },
                onDelete: { msg in pendingConfirm = .delete(msg) },
                canRecall: { msg in canRecall(msg) }
            )
        }
        .navigationDestination(isPresented: Binding(
            get: { profileTarget != nil },
            set: { if !$0 { profileTarget = nil } }
        )) {
            if let target = profileTarget {
                UserProfileView(uid: target.id, gid: target.gid)
                    .restoresSwipeBack()
            }
        }
        .sheet(isPresented: $showForward, onDismiss: { Task { await load() } }) {
            ForwardPickerView(messages: forwardMessages, title: forwardTitle) { ctype, cid, sent in
                appendForwarded(convType: ctype, convId: cid, message: sent)
            }
        }
        .sheet(item: $menuTarget, onDismiss: {
            /* 菜单是 sheet，撤回/删除的 alert 必须等 sheet 真正收起后再弹 */
            flushPendingConfirm()
        }) { msg in
            ChatMessageMenuSheet(
                message: msg,
                isGroup: isGroup,
                mine: msg.fromUid == myId,
                myRole: myRole,
                pinned: pinMsgId == msg.id,
                canRecall: canRecall(msg),
                canPin: canPin && msg.id > 0 && msg.type != 11,
                canAddEmoji: msg.type == 5 && msg.fromUid != myId && isStickerMessage(msg),
                canReedit: msg.fromUid == myId && recallOriginals[msg.id] != nil,
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
        .navigationDestination(isPresented: Binding(
            get: { payTarget != nil },
            set: { if !$0 { payTarget = nil } }
        )) {
            if let msg = payTarget {
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
                    } else if msg.type == 2 || msg.type == 3 || msg.type == 20 {
                        RechargeDetailSheet(message: msg, myId: myId) {
                            Task { await reloadAfterPay() }
                        }
                    } else {
                        GiftClaimSheet(message: msg, convType: convType, convId: convId, myId: myId) {
                            Task { await reloadAfterPay() }
                        }
                    }
                }
                .onAppear {
                    if let id = payTarget?.id, id > 0 {
                        Task { @MainActor in await refreshCard(id: id) }
                    }
                }
                .reportsDetailPage()
                .restoresSwipeBack()
            }
        }
        .navigationDestination(isPresented: $showRecord) {
            ChatRecordView(payload: recordPayload ?? "")
                .reportsDetailPage()
                .restoresSwipeBack()
        }
        .sheet(isPresented: $showVideo) {
            NavigationStack {
                VideoPreviewSheet(url: videoURL)
            }
        }
        .navigationDestination(isPresented: $showNotices) {
            GroupNoticesView(groupId: convId) {
                clearPendingNotice()
            }
            .restoresSwipeBack()
        }
        .fullScreenCover(item: $liveRoute) { route in
            NavigationStack { LiveRoomView(gid: route.gid) }
        }
        .navigationDestination(isPresented: Binding(
            get: { groupRoute != nil },
            set: { if !$0 { groupRoute = nil } }
        )) {
            if let route = groupRoute {
                GroupPreviewView(groupId: route.id)
                    .restoresSwipeBack()
            }
        }
        .fullScreenCover(isPresented: $showCall) {
            CallScreen()
        }
        .sheet(isPresented: $showGroupCall) {
            NavigationStack { GroupCallView(gid: convId, callType: callType) }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItems,
                      maxSelectionCount: 9, matching: .images)
        .photosPicker(isPresented: $showVideoPicker, selection: $videoItem, matching: .videos)
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
        .onAppear {
            activatePage()
        }
        .onDisappear {
            pausePage()
            pageTasks.forEach { $0.cancel() }
            pageTasks.removeAll()
        }
        .onChange(of: tabIsActive) { active in
            if active {
                activatePage()
                Task { await pollNewMessages() }
            } else { pausePage() }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                startCardPolling()
                Task { await pollNewMessages() }
            } else {
                cardPollTask?.cancel()
                cardPollTask = nil
            }
        }
        .onChange(of: messages) { _ in
            guard let target = payTarget, target.id > 0,
                  let latest = messages.first(where: { $0.id == target.id }) else { return }
            if latest != target { payTarget = latest }
        }
        /* 从群公告列表 / 群资料返回：重新问一次服务端还有没有待确认公告，确认过的横幅立即消失 */
        .onChange(of: showNotices) { open in
            if !open { Task { await loadPendingNotice(showPopup: false) } }
        }
        .onChange(of: showGroupInfo) { open in
            if !open { Task { await loadPendingNotice(showPopup: false) } }
        }
        /* 前台兜底轮询：WS 漏帧或断线重连期间，每 5 秒补拉当前会话 afterId 之后的消息。 */
        .task(id: "poll-\(convType)-\(convId)") {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { break }
                let active = await MainActor.run { UIApplication.shared.applicationState == .active }
                guard active else { continue }
                await pollNewMessages()
            }
        }
        .task {
            /* 先用本地缓存立刻上背景（不等网络），再用服务端结果校正 */
            chatBg = cachedBg()
            syncPeerConv()
            /* 先把消息拉下来渲染，其余数据并行补齐，避免打开会话卡顿 */
            await load()
            guard !Task.isCancelled else { return }
            /* 首次加载完成：通知列表无条件贴底一次，之后才按「已在底部」跟随 */
            initialScrollTick += 1

            pageTasks.forEach { $0.cancel() }
            pageTasks = [
                Task {
                    if let r = try? await APIClient.shared.chatBg(convType: convType, convId: convId) {
                        chatBg = r.bg
                        storeBg(r.bg)
                    }
                },
                Task {
                    async let emojis: Void = app.loadEmojis()
                    async let pin: Void = loadPin()
                    _ = await (emojis, pin)
                }
            ]
            if isGroup {
                pageTasks.append(Task {
                    async let members: Void = loadMembers()
                    async let notice: Void = loadPendingNotice()
                    _ = await (members, notice)
                })
                pageTasks.append(Task {
                    async let activeReq = APIClient.shared.groupActive(gid: convId)
                    async let infoReq = APIClient.shared.groupInfo(id: convId)
                    let a = try? await activeReq
                    let i = try? await infoReq
                    let e: GroupInfoExtras? = try? await APIClient.shared.get(
                        "api/v1/group", query: ["id": "\(convId)"]
                    )
                    await MainActor.run {
                        active = a
                        groupInfo = i
                        groupExtras = e
                    }
                })
            }
        }
        .onReceive(app.inbox) { msg in
            guard msg.convType == convType, msg.convId == convId else { return }
            if msg.id != 0, let idx = messages.firstIndex(where: { $0.id == msg.id }) {
                /* 服务端在领取/收款后会推送同 id 的更新卡片；以前这里直接 return，
                   导致红包/转账/礼物的 status 一直停在未领取。 */
                var latest = msg
                latest.localId = messages[idx].localId
                latest.isRead = max(latest.isRead, messages[idx].isRead)
                if latest.fromName == nil { latest.fromName = messages[idx].fromName }
                if latest.fromAvatar == nil { latest.fromAvatar = messages[idx].fromAvatar }
                if messages[idx] != latest {
                    messages[idx] = latest
                    if let target = payTarget, target.id == msg.id { payTarget = latest }
                }
                return
            }
            if let clientId = msg.clientId, !clientId.isEmpty,
               let idx = messages.firstIndex(where: { $0.clientId == clientId && $0.localId < 0 }) {
                messages[idx] = msg
            } else {
                messages.append(msg)
            }
            if msg.type == 11 {
                let sysText = msg.text ?? msg.content ?? ""
                if sysText.contains("已领取红包") || sysText.contains("已收款")
                    || sysText.contains("已领取礼物") || sysText.contains("领取了红包")
                    || sysText.contains("领取了转账") || sysText.contains("领取了礼物") {
                    Task { @MainActor in await refreshCardStates(force: true) }
                }
            }
            Task { await app.markRead(convType: convType, convId: convId, lastId: msg.id) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .akWsReconnected).receive(on: RunLoop.main)) { _ in
            /* WS 重连：立刻补拉断线期间漏掉的群/私聊消息 */
            Task { await pollNewMessages() }
        }
        .onReceive(app.events) { ev in
            handle(ev)
        }
        .onChange(of: app.conversations) { _ in syncPeerConv() }
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
        .onChange(of: videoItem) { item in
            guard let item else { return }
            videoItem = nil
            Task { await sendVideo(item) }
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

    private var unreadMessageCount: Int {
        guard unreadAnchor > 0 else { return 0 }
        var n = 0
        for m in messages where m.id >= unreadAnchor && m.fromUid != myId { n += 1 }
        return n
    }

    /// 「以下是新消息 · N 条」分割线（对齐安卓 UnreadDividerRow）
    private func unreadDivider(count: Int) -> some View {
        HStack(spacing: 0) {
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

    /// 转发成功后把服务端返回的消息直接补进当前会话：服务端推送会排除发送者自己
    private func appendForwarded(convType: String, convId: Int64, message: Message?) {
        guard convType == self.convType, convId == self.convId, let message else { return }
        if message.id != 0, messages.contains(where: { $0.id == message.id }) { return }
        if let client = message.clientId, !client.isEmpty,
           messages.contains(where: { $0.clientId == client }) { return }
        messages.append(message)
        if message.id > 0 {
            Task { await app.markRead(convType: self.convType, convId: self.convId, lastId: message.id) }
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
                let picked = messages.filter { selectedKeys.contains($0.listKey) && $0.id > 0 }
                selectMode = false
                selectedKeys.removeAll()
                guard !picked.isEmpty else { return }
                Task {
                    for m in picked {
                        await APIClient.shared.addFavorite(message: m, convName: title)
                    }
                    flash("已收藏 \(picked.count) 条")
                }
            } label: {
                Text("收藏")
                    .font(.system(size: 13.5))
                    .foregroundColor(selectedKeys.isEmpty ? AKColor.placeholder : AKColor.text)
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


    /// 最后一行仍在视口内（留 24pt 容差）→ 视为贴底
    private func refreshAtBottom() {
        guard scrollProbe.listHeight > 0 else { return }
        let now = scrollProbe.bottomEdge <= scrollProbe.listHeight + 24
        if now != atBottom { atBottom = now }
    }

    /// 贴底：键盘、表情/加号面板、新消息都走这里；用户上滑看历史时不动
    private func stickToBottom(_ proxy: ScrollViewProxy, delay: Double = 0) {
        guard atBottom, let last = messages.last else { return }
        let scroll = {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.listKey, anchor: .bottom)
            }
        }
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: scroll)
        } else {
            scroll()
        }
    }

    /// 进会话首帧的骨架：与真实消息行同尺寸、同底色，数据到达后原位替换，
    /// 避免先渲染一帧空白/「暂无消息」再跳成列表
    private var messageSkeleton: some View {
        VStack(spacing: 14) {
            ForEach(0..<9, id: \.self) { i in
                let mine = i % 3 == 2
                HStack(alignment: .top, spacing: 8) {
                    if mine { Spacer(minLength: 48) }
                    if !mine {
                        Circle().fill(AKColor.fill).frame(width: 36, height: 36)
                    }
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AKColor.fill)
                        .frame(width: 120 + CGFloat((i * 37) % 90),
                               height: 30 + CGFloat(i % 3) * 8)
                    if !mine { Spacer(minLength: 48) }
                    if mine {
                        Circle().fill(AKColor.fill).frame(width: 36, height: 36)
                    }
                }
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var messageList: some View {
        /* 派生数据只在消息/成员真的变了时重算：AppState 其它字段的发布
           （别的会话来消息、未读变化）也会重算 body，不该重跑这一整遍 */
        let derived = derivedCache.value(
            for: ChatDerivedCache.Key(isGroup: isGroup,
                                      myId: myId,
                                      membersHidden: isMembersHidden,
                                      unreadAnchor: unreadAnchor,
                                      messages: messages,
                                      members: members),
            build: buildDerived
        )
        let hints = derived.readHints
        let memberLookup = derived.membersByUid
        let mentions = derived.mentions
        let mentionStamp = derived.mentionStamp
        let dividers = derived.dividers
        let firstUnread = derived.firstUnread
        let unreadCount = derived.unreadCount
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if messages.isEmpty {
                        /* 首帧不能先渲染「暂无消息」：用与气泡同尺寸同底色的骨架占位，
                           首批历史回来原位替换；真的没消息（didLoad）才显示空态 */
                        if didLoad && !loading {
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
                        } else {
                            messageSkeleton
                        }
                    } else if loading {
                        /* 已有消息时的重拉（转发后刷新等）：只在顶部加小菊花，不动列表 */
                        ProgressView().padding(.top, 12)
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
                    ForEach(derived.indexed, id: \.message.listKey) { item in
                        let index = item.index
                        let msg = item.message
                        if index == firstUnread {
                            unreadDivider(count: unreadCount)
                        }
                        if let stamp = dividers[msg.listKey] {
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
                            row(msg, member: memberLookup[msg.fromUid], mentionMap: mentions,
                                mentionStamp: mentionStamp, readHint: hints[msg.listKey] ?? 0,
                                uploadProgress: uploadProgress[msg.listKey],
                                pendingVideoCover: pendingVideos[msg.listKey]?.coverImage)
                        }
                        .background(msg.id > 0 && msg.id == highlightId
                                    ? Color(hex: 0xFFE082).opacity(0.2) : Color.clear)
                        .background {
                            /* 最后一行底部位置：offset 变化时刷新，用来判断用户是否还在底部 */
                            if index == messages.count - 1 {
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: ChatBottomEdgeKey.self,
                                        value: geo.frame(in: .named("chat_scroll")).maxY
                                    )
                                }
                            }
                        }
                        .id(msg.listKey)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .coordinateSpace(name: "chat_scroll")
            .background(GeometryReader { geo in
                Color.clear.preference(key: ChatListHeightKey.self, value: geo.size.height)
            })
            .onPreferenceChange(ChatListHeightKey.self) { height in
                guard height > 0 else { return }
                /* 视口高度只量不判：键盘/面板开关会让高度变化，但用户阅读位置没变 */
                let firstMeasure = scrollProbe.listHeight == 0
                scrollProbe.listHeight = height
                if firstMeasure { refreshAtBottom() }
            }
            .onPreferenceChange(ChatBottomEdgeKey.self) { edge in
                guard let edge else { return }
                scrollProbe.bottomEdge = edge
                refreshAtBottom()
            }
            /* 只在底部出现新消息时贴底：上拉加载历史与引用跳转不会把视口甩到底 */
            .onChange(of: messages.last?.listKey) { key in
                guard initialScrollDone, key != nil, scrollTarget == nil, atBottom,
                      let last = messages.last else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(last.listKey, anchor: .bottom)
                }
            }
            /* 键盘弹起/收起：输入区高度一变就贴底，用户上滑看历史时不回弹 */
            .onReceive(NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
                stickToBottom(proxy, delay: max(duration, 0.05))
            }
            .onChange(of: showEmoji) { _ in stickToBottom(proxy, delay: 0.08) }
            .onChange(of: showMore) { _ in stickToBottom(proxy, delay: 0.08) }
            /* 首次加载完成：无条件贴底（无动画），之后才走“已在底部才跟随”的逻辑。
               LazyVStack 首帧可能还没量完，补两次无动画定位 */
            .onChange(of: initialScrollTick) { tick in
                guard tick > 0 else { return }
                atBottom = true
                if let last = messages.last { proxy.scrollTo(last.listKey, anchor: .bottom) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    if let last = messages.last { proxy.scrollTo(last.listKey, anchor: .bottom) }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if let last = messages.last { proxy.scrollTo(last.listKey, anchor: .bottom) }
                    atBottom = true
                    initialScrollDone = true
                }
            }
            .onChange(of: scrollTarget) { target in
                guard let target else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(target.key, anchor: .center)
                }
            }
        }
        .overlay {
            /* 加号面板只留透明热区关闭，不加任何暗色遮罩 */
            if showMore {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { showMore = false }
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
            if pinMsgId > 0 { jumpToMessage(pinMsgId) }
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

    /// 平台管理员：不受群内「禁止查看成员信息」限制，可撤回任意成员的消息
    private var isPlatformAdmin: Bool {
        (groupInfo?.isPlatformAdmin ?? 0) == 1 || app.user?.isPlatformAdmin == 1
    }

    /// 顶部公告条：只承载「待我确认」的公告（服务端 /group/notice/pending 返回的那一条）。
    /// 安卓聊天页没有常驻公告条，公告只在未确认时弹层提示；iOS 用这条横幅表示同一件事，
    /// 确认后 pendingNotice 置空、横幅立即消失。置顶公告本身仍留在群公告列表里显示。
    private var noticeBarText: String? {
        /* 与安卓一致：只有「需要确认且我还没确认」的公告才提示，置顶标记与已读无关 */
        guard isGroup, let notice = pendingNotice, notice.needAck == 1, notice.myAck != 1 else { return nil }
        let text = (notice.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "群公告待确认" }
        return text.split(whereSeparator: { $0.isNewline }).first.map { String($0) }
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

    /// 回复时要 @ 的显示名：群昵称 → 发送者昵称 → 成员（空名不写进输入框）
    private func replyMentionName(_ msg: Message) -> String {
        if let name = members.first(where: { $0.uid == msg.fromUid })?.name,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        let from = msg.fromName ?? ""
        return from.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "成员" : from
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

    /// 一次算好每条消息的时间分隔标签，避免每行 body 重算时反复格式化时间
    private var dividerLabels: [String: String] {
        var out: [String: String] = [:]
        var previous: Int64 = 0
        for m in messages {
            if let label = chatDividerLabel(previous: previous, current: m.createdAt) {
                out[m.listKey] = label
            }
            previous = m.createdAt
        }
        return out
    }

    /// 群成员按 uid 建索引：消息行里不再逐条 first(where:)
    private var memberMap: [Int64: GroupMember] {
        guard isGroup, !members.isEmpty else { return [:] }
        var map: [Int64: GroupMember] = [:]
        map.reserveCapacity(members.count)
        for m in members { map[m.uid] = m }
        return map
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
        case 10:
            if ForwardRules.isLocationPayload(m.content, m.text) { return "[位置]" }
            return "[引用] " + plain(m.text ?? "", 18)
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
        /* 服务端下发的时间戳缺失时不拦，最终时限仍由服务端校验 */
        let now = ServerClock.nowSec
        if m.fromUid == myId {
            if m.createdAt <= 0 { return true }
            if isGroup { return myRole == 1 || myRole == 2 || now - m.createdAt <= 120 }
            return now - m.createdAt <= 180
        }
        guard isGroup else { return false }
        if isPlatformAdmin { return true }
        if myRole == 1 { return true }
        if myRole == 2 {
            let authorRole = members.first { $0.uid == m.fromUid }?.role ?? m.fromRole
            return authorRole == 0
        }
        return false
    }

    /// 引用块点击：与置顶条共用同一套定位
    private func jumpToQuote(_ id: Int64) {
        jumpToMessage(id)
    }

    /// 置顶条 / 引用块共用：目标不在本地列表时先按 anchor 拉取它前后各 20 条，
    /// 合并进列表后再分帧滚动。第一次 scrollTo 往往目标行还没布局，所以要多帧校正。
    private func jumpToMessage(_ id: Int64) {
        guard id > 0 else { return }
        highlightId = id
        /* 主动跳到某条历史消息：不再跟随键盘/新消息贴底 */
        if atBottom { atBottom = false }
        if messages.contains(where: { $0.id == id }) {
            scheduleLocate(id)
            clearHighlightLater(id)
            return
        }
        Task {
            var found = false
            if let data = try? await APIClient.shared.history(
                convType: convType, convId: convId, anchorId: id
            ) {
                await MainActor.run { mergeHistory(data.list) }
                found = messages.contains(where: { $0.id == id })
            }
            if !found { found = await loadUntilFound(id, maxPages: 8) }
            await MainActor.run {
                if found {
                    scheduleLocate(id)
                    clearHighlightLater(id)
                } else {
                    flash("原消息已不在聊天记录中")
                }
            }
        }
    }

    /// anchor 拉回来的是目标前后一段消息：按 id 去重合并，未发出的本地消息保持在末尾
    private func mergeHistory(_ list: [Message]) {
        guard !list.isEmpty else { return }
        let known = Set(messages.map { $0.id })
        let fresh = list.filter { $0.id > 0 && !known.contains($0.id) }
        guard !fresh.isEmpty else { return }
        let local = messages.filter { $0.id <= 0 }
        messages = (messages.filter { $0.id > 0 } + fresh).sorted { $0.id < $1.id } + local
    }

    /// 服务端没返回目标时的兜底：继续向前翻页，直到找到或翻完
    private func loadUntilFound(_ id: Int64, maxPages: Int) async -> Bool {
        var pages = 0
        while pages < maxPages, !messages.contains(where: { $0.id == id }) {
            let before = messages.count
            await loadMore()
            if messages.count == before { break }
            pages += 1
        }
        return messages.contains(where: { $0.id == id })
    }

    /// 分帧多次滚动：第 1 次让 LazyVStack 把目标纳入布局，后几次校正到视口中央
    private func scheduleLocate(_ id: Int64) {
        let key = "m_\(id)"
        locateSeq += 1
        let base = locateSeq * 10
        for (i, delay) in [0.0, 0.06, 0.16, 0.32, 0.6].enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard highlightId == id else { return }
                scrollTarget = ChatScrollLocate(key: key, seq: base + i)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            if let t = scrollTarget, t.seq >= base, t.seq <= base + 4 { scrollTarget = nil }
        }
    }

    /// 高亮保持 2.4s（对齐安卓 highlightId）；期间又点了别的消息就不清
    private func clearHighlightLater(_ id: Int64) {
        Task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            await MainActor.run {
                if highlightId == id { highlightId = 0 }
            }
        }
    }

    /// 进用户主页：群主关闭了成员信息查看时，除自己外一律拦下（对齐安卓 onAvatarClick）
    private func openProfile(_ uid: Int64) {
        guard uid > 0 else { return }
        if isGroup, uid != myId, isMembersHidden {
            flash("群主已关闭成员信息查看")
            return
        }
        profileTarget = ProfileTarget(id: uid, gid: isGroup ? convId : 0)
    }

    private func redPacketId(_ m: Message) -> Int64 {
        if let v = m.extraMap["rp_id"]?.intValue, v > 0 { return Int64(v) }
        if let o = MessageBody.jsonObject(m.content) {
            if let n = o["rp_id"] as? NSNumber { return n.int64Value }
            if let s = o["rp_id"] as? String, let v = Int64(s) { return v }
        }
        return m.id
    }

    /// 会话内图片/视频组成预览列表（对齐安卓 openImage）：命中当前张就整会话左右滑，
    /// 找不到（表情包、相册图等）退回单张查看
    private func openMediaPager(_ raw: String, isVideo: Bool) {
        let target = VoiceService.cleanPath(raw)
        guard !target.isEmpty, let targetURL = APIClient.fullURL(target) else {
            flash(isVideo ? "视频地址无效" : "图片地址无效")
            return
        }
        var items: [PreviewMedia] = []
        var at = -1
        for m in messages {
            guard (m.type == 5 && !isStickerMessage(m)) || m.type == 15 else { continue }
            let path = VoiceService.cleanPath(m.text ?? m.content ?? "")
            guard !path.isEmpty, let u = APIClient.fullURL(path) else { continue }
            if at < 0, path == target { at = items.count }
            items.append(PreviewMedia(url: u, isVideo: m.type == 15, message: m))
        }
        guard at >= 0 else {
            previewImage = PreviewImage(
                items: [PreviewMedia(url: targetURL, isVideo: isVideo, message: nil)], index: 0
            )
            return
        }
        previewImage = PreviewImage(items: items, index: at)
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

    /// @ 名字映射（群成员或私聊对方；@全体成员 → 0）
    private var mentionMap: [String: Int64] {
        /* 私聊没有群成员表：@ 对方昵称也要蓝色可点，点击进对方资料 */
        if !isGroup {
            let name = title.trimmingCharacters(in: .whitespaces)
            return name.isEmpty || convId <= 0 ? [:] : [name: convId]
        }
        /* 群主关闭成员信息：@ 名字仍蓝色显示，但统一成不可点的 -1（对齐安卓） */
        if isMembersHidden { return ["*": -1] }
        var map: [String: Int64] = ["全体成员": 0]
        for m in members {
            let name = m.name ?? ""
            if !name.isEmpty { map[name] = m.uid }
        }
        return map
    }

    private var isMembersHidden: Bool {
        guard isGroup, !isPlatformAdmin, let e = groupExtras else { return false }
        return e.membersHidden == 1 || (e.hideMembers == 1 && myRole == 0)
    }

    @ViewBuilder
    private func row(_ msg: Message, member: GroupMember?, mentionMap: [String: Int64],
                     mentionStamp: Int, readHint: Int, uploadProgress: Double? = nil,
                     pendingVideoCover: UIImage? = nil) -> some View {
        ChatMessageRow(
            message: msg,
            mine: msg.fromUid == myId,
            isGroup: isGroup,
            member: member,
            myAvatar: app.user?.avatar,
            myUid: myId,
            myName: app.user?.nickname ?? "我",
            peerName: title,
            readHint: readHint,
            uploadProgress: uploadProgress,
            pendingVideoCover: pendingVideoCover,
            playingVoice: voice.playingURL == VoiceService.cleanPath(msg.text ?? msg.content ?? ""),
            voicePlayed: playedVoice.contains(msg.listKey),
            mentionMap: mentionMap,
            mentionStamp: mentionStamp,
            onMention: { uid in
                openProfile(uid)
            },
            onVoiceTap: {
                playedVoice.insert(msg.listKey)
                voice.play(path: VoiceService.cleanPath(msg.text ?? msg.content ?? ""))
            },
            onRetry: {
                Task { await resend(msg) }
            },
            onAvatarTap: {
                openProfile(msg.fromUid)
            },
            onAvatarLongPress: {
                guard isGroup, msg.fromUid != myId else { return }
                let memberName = member?.name ?? ""
                let name = memberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? (msg.fromName ?? "") : memberName
                insertMention(name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              ? "成员" : name, uid: msg.fromUid)
            },
            onLongPress: {
                if selectMode { toggleSelect(msg) } else { menuTarget = msg }
            },
            onOpenLive: { gid in
                /* 直播卡片未带群 ID 时退回当前会话，避免 /group/live/room?id=0 报参数错误 */
                let target = gid > 0 ? gid : convId
                guard target > 0 else { return }
                liveRoute = LiveRoute(gid: target)
            },
            onOpenGroup: { gid in
                guard gid > 0 else { return }
                groupRoute = GroupRoute(id: gid)
            },
            onOpenProfile: { uid in
                openProfile(uid)
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
                    AppLinkRouter.open(u)
                }
            },
            onOpenMoment: { uid in
                profileTarget = ProfileTarget(id: uid, gid: isGroup ? convId : 0)
            },
            onOpenRecord: { raw in
                recordPayload = raw
                showRecord = true
            },
            onOpenAlbum: { urls, index in
                openAlbum(urls, index: index)
            },
            onOpenMedia: { raw, isVideo in
                openMediaPager(raw, isVideo: isVideo)
            },
            reeditText: recallOriginals[msg.id],
            onReedit: { original in
                composer.text = original
                inputFocused = true
            }
        )
        .equatable()
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
            /* 群里回复谁就带上 @谁：at_uids 驱动对方首页 [有人@我]；私聊与自己的消息不插 @ */
            if isGroup, msg.fromUid != myId {
                insertMention(name: replyMentionName(msg), uid: msg.fromUid, skipIfPresent: true)
            }
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
        case "save":
            saveMedia(msg)
        case "reedit":
            if let original = recallOriginals[msg.id] {
                composer.text = original
                inputFocused = true
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
            pendingConfirm = .recall(msg)
        case "delete":
            pendingConfirm = .delete(msg)
        default:
            break
        }
    }

    /// 菜单/预览层完全收起后再弹二次确认，否则 alert 会被正在收起的面板挡住
    private func flushPendingConfirm() {
        guard let next = pendingConfirm else { return }
        pendingConfirm = nil
        confirm = next
    }

    /// 长按菜单「保存」：图片/视频下载后写入系统相册
    private func saveMedia(_ msg: Message) {
        let raw = msg.text ?? msg.content ?? ""
        guard let url = APIClient.fullURL(VoiceService.cleanPath(raw)) else {
            flash("保存失败")
            return
        }
        let isVideo = msg.type == 15
        Task {
            let ok = await AKMediaSaver.save(url: url, isVideo: isVideo)
            await MainActor.run { flash(ok ? "已保存到相册" : "保存失败") }
        }
    }

    private func insertText(_ value: String) {
        composer.text += value
    }

    /// @ 某人：替换末尾刚输入的 @关键字，不重复拼 @@
    private func insertMention(name: String, uid: Int64, skipIfPresent: Bool = false) {
        let mention = "@\(name) "
        if !atUids.contains(uid) { atUids.append(uid) }
        /* 连点「回复」同一条时末尾已经是同一个 @，不再追加 */
        if skipIfPresent, composer.text.hasSuffix(mention) { return }
        var base = composer.text
        if let at = base.lastIndex(of: "@") {
            let tail = base[base.index(after: at)...]
            if !tail.contains(where: { $0.isWhitespace }) {
                base = String(base[..<at])
            }
        }
        composer.text = base + mention
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
                ChatTextInput(
                    composer: composer,
                    placeholder: placeholder,
                    inputFocused: $inputFocused,
                    onChanged: handleInputChange,
                    onTap: {
                        showMore = false
                        showEmoji = false
                        voiceMode = false
                    }
                )
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

            ChatComposerToggle(
                composer: composer,
                showMore: $showMore,
                showEmoji: $showEmoji,
                voiceMode: $voiceMode,
                inputFocused: $inputFocused,
                onSend: { Task { await send() } }
            )
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
                let saved = try await APIClient.shared.sendVoice(
                    convType: convType, convId: convId, url: uploaded.url, seconds: seconds,
                    clientId: local.clientId ?? "ios_\(UUID().uuidString)"
                )
                replaceLocal(local, with: saved.message)
                Task { await app.refreshConversations() }
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

    /** 只补拉 afterId 之后的新消息；按 id 合并，WS 已收到的不会重复。 */
    @MainActor
    private func pollNewMessages() async {
        guard !loading, !loadingMore else { return }
        guard let afterId = messages.last(where: { $0.id > 0 })?.id else { return }
        guard let data = try? await APIClient.shared.historyAfter(
            convType: convType, convId: convId, afterId: afterId
        ), !data.list.isEmpty else { return }
        let list = data.list

        var changed = false
        for msg in list where msg.id > 0 {
            if let idx = messages.firstIndex(where: { $0.id == msg.id }) {
                var latest = msg
                latest.localId = messages[idx].localId
                latest.isRead = max(latest.isRead, messages[idx].isRead)
                if latest.fromName == nil { latest.fromName = messages[idx].fromName }
                if latest.fromAvatar == nil { latest.fromAvatar = messages[idx].fromAvatar }
                if messages[idx] != latest {
                    messages[idx] = latest
                    changed = true
                }
                if let target = payTarget, target.id == msg.id { payTarget = latest }
            } else if let clientId = msg.clientId, !clientId.isEmpty,
                      let pending = messages.firstIndex(where: { $0.clientId == clientId && $0.localId < 0 }) {
                /* 本机发送中的临时行：用服务端消息替换，避免轮询后出现两条 */
                messages[pending] = msg
                changed = true
            } else {
                messages.append(msg)
                changed = true
            }
        }
        guard changed else { return }
        /* 本地待发消息 id<=0：必须留在列表末尾，否则会被排到最前面，
           既显示错位，也会让上滑翻页的游标取到 0 而永远加载不出更早的消息 */
        messages.sort { a, b in
            if a.id <= 0 || b.id <= 0 { return a.id > b.id }
            return a.id < b.id
        }
        if let maxId = list.map({ $0.id }).max() {
            await app.markRead(convType: convType, convId: convId, lastId: maxId)
        }
    }

    private func load() async {
        loading = true
        defer {
            loading = false
            didLoad = true
        }
        do {
            let page = try await app.loadHistoryPage(convType: convType, convId: convId)
            mergeHistoryPage(page)
            if unreadAnchor == 0, let c = peerConv, c.unread > 0 {
                let incoming = messages.filter { $0.fromUid != myId && $0.id > 0 }
                if incoming.count >= c.unread {
                    unreadAnchor = incoming[incoming.count - c.unread].id
                }
            }
            if let last = messages.last(where: { $0.id > 0 }) {
                await app.markRead(convType: convType, convId: convId, lastId: last.id)
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    /// 把服务端一页历史并进列表：比这一页更早的已加载消息原样保留。
    /// 旧实现直接用这一页覆盖 messages，重进会话 / 转发面板关闭 / 发卡片后的 reloadAfterPay
    /// 都会把上滑翻出来的历史静默丢掉、游标退回最新一页。
    /// 到底与否只看服务端 has_more，不用「条数 < limit」猜。
    private func mergeHistoryPage(_ page: HistoryData) {
        let fresh = page.list.filter { $0.id > 0 }.sorted { $0.id < $1.id }
        let pageMin = fresh.first?.id ?? 0
        let pending = messages.filter { $0.id <= 0 }
        let kept = pageMin > 0 ? messages.filter { $0.id > 0 && $0.id < pageMin }
                               : messages.filter { $0.id > 0 }
        var seen = Set<Int64>()
        var merged: [Message] = []
        for m in kept + fresh where seen.insert(m.id).inserted { merged.append(m) }
        messages = merged + pending
        /* 游标只往前挪：重拉第一页不能把已经翻到的位置退回去 */
        if pageMin > 0 { historyCursor = historyCursor == 0 ? pageMin : min(historyCursor, pageMin) }
        if page.hasMore == 0 { reachedHistoryStart = true }
        hasMore = !reachedHistoryStart
    }

    private func loadMore() async {
        guard !loadingMore, hasMore else { return }
        /* 游标是「翻页走到哪」而不是「列表第一条」：本地待发消息（id<=0）和
           定位置顶时插进来的旧消息都不该参与，否则一）游标取到 0 直接无法翻页，
           二）被旧块拉到很远的位置、中间那段历史永远补不回来 */
        let cursor = historyCursor > 0
            ? historyCursor
            : (messages.first(where: { $0.id > 0 })?.id ?? 0)
        guard cursor > 0 else { return }
        loadingMore = true
        defer { loadingMore = false }
        do {
            let page = try await app.loadHistoryPage(
                convType: convType, convId: convId, beforeId: cursor
            )
            let list = page.list.filter { $0.id > 0 }
            if list.isEmpty {
                reachedHistoryStart = true
                hasMore = false
                return
            }
            let known = Set(messages.map { $0.id })
            let older = list.filter { !known.contains($0.id) }.sorted { $0.id < $1.id }
            if !older.isEmpty { messages = older + messages }
            /* 用服务端这一页的最小 id 续翻；游标没前进说明服务端没按 before_id 切，直接收敛防死循环 */
            let pageMin = list.map(\.id).min() ?? 0
            if pageMin > 0 { historyCursor = pageMin }
            if page.hasMore == 0 || pageMin <= 0 || pageMin >= cursor {
                reachedHistoryStart = true
                hasMore = false
            }
        } catch {
            /* 失败不当成到底：保留 hasMore，用户再点还能重试 */
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

    /// 拉「待我确认」的公告：服务端返回 nil 说明没有待确认（已确认 / 没有 popup+need_ack 公告），
    /// 这时必须把本地横幅清掉，否则确认完回来还挂着旧公告。
    private func loadPendingNotice(showPopup: Bool = true) async {
        guard isGroup else { return }
        guard let notice = await APIClient.shared.pendingGroupNotice(gid: convId), notice.id > 0 else {
            pendingNotice = nil
            showNotice = false
            return
        }
        /* 以服务端为准：pending 返回的就是「我还没确认」的公告，
           不再用本地指纹隐藏，避免服务端要求确认而客户端永不弹。 */
        pendingNotice = notice
        let fp = noticeFingerprint(notice)
        if showPopup && noticePopupFingerprint != fp {
            noticePopupFingerprint = fp
            showNotice = true
        }
    }

    private func noticeFingerprint(_ notice: GroupNotice) -> String {
        "\(notice.id)|\(notice.content ?? "")"
    }

    /// 进群弹窗「我已知晓」：先收起横幅/弹层，再以服务端 pending 是否清空判断成功。
    /// 失败时 loadPendingNotice 会把横幅重新挂回来，用户点横幅可以重试。
    private func confirmGroupNotice(_ notice: GroupNotice?) {
        guard let notice else { return }
        pendingNotice = nil
        showNotice = false
        Task {
            await APIClient.shared.ackGroupNotice(id: notice.id)
            await loadPendingNotice(showPopup: false)
            if pendingNotice?.id == notice.id {
                flash("公告确认失败，请重试")
            }
        }
    }

    /// 公告列表里确认成功：立刻收起顶部公告条，再问一次服务端是否还有别的待确认公告
    private func clearPendingNotice() {
        pendingNotice = nil
        showNotice = false
        Task { await loadPendingNotice(showPopup: false) }
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
        showCall = true
        Task {
            await CallManager.shared.start(peerUid: convId, name: title, avatar: nil, type: type)
        }
    }

    private func send() async {
        let content = composer.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        let at = atUids.map { $0 == -1 ? "all" : String($0) }.joined(separator: ",")
        let quote = replyTo
        /* 输入框立刻清空、本机气泡立刻落位：网络与会话列表刷新都不挡输入 */
        composer.text = ""
        atUids = []
        replyTo = nil
        errorText = nil

        let type: Int
        let body: String
        if let quote, quote.id > 0 {
            type = 10
            body = quotePayload(quote) + "|#|" + content
        } else {
            type = 1
            body = content
        }
        var local = makeLocal(type: type, content: body)
        local.atUids = at.isEmpty ? nil : at
        messages.append(local)
        Task { await transmit(local, atUids: at) }
    }

    /// 发送只等接口本身：成功后换成服务端消息，会话列表刷新丢到后台，失败才标红
    private func transmit(_ local: Message, atUids: String = "") async {
        do {
            let saved = try await APIClient.shared.sendTypedMessage(
                convType: convType, convId: convId, type: local.type,
                content: local.content ?? local.text ?? "",
                clientId: local.clientId ?? "ios_\(UUID().uuidString)",
                atUids: atUids
            )
            replaceLocal(local, with: saved.message)
            Task { await app.refreshConversations() }
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
        if msg.type == 15 {
            guard pendingVideos[msg.listKey] != nil else {
                failLocal(msg, "视频文件已失效，请重新选择发送")
                return
            }
            await uploadVideo(msg)
            return
        }
        await transmit(messages[idx], atUids: msg.atUids ?? "")
    }

    /* ---------------- 视频 ---------------- */

    /// 相册选视频：先落临时文件 + 本机气泡，传完再换成服务端消息
    private func sendVideo(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty else {
            flash("视频读取失败")
            return
        }
        guard data.count <= 60 * 1024 * 1024 else {
            flash("视频不能超过 60MB")
            return
        }
        let ext = videoExtension(item)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("akchat_video_\(UUID().uuidString).\(ext)")
        do {
            try data.write(to: fileURL)
        } catch {
            flash("视频读取失败")
            return
        }

        let local = makeLocal(type: 15, content: "")
        messages.append(local)
        pendingVideos[local.listKey] = PendingVideo(
            fileURL: fileURL, duration: 0, cover: "",
            width: 0, height: 0, coverImage: nil
        )
        uploadProgress[local.listKey] = 0

        /* 首帧在本地抽，抽完直接给待发气泡用：不等封面上传，也不阻塞气泡出现 */
        let meta = await videoMeta(fileURL)
        pendingVideos[local.listKey]?.duration = meta.duration
        pendingVideos[local.listKey]?.width = meta.width
        pendingVideos[local.listKey]?.height = meta.height
        if let data = meta.cover, let image = UIImage(data: data) {
            pendingVideos[local.listKey]?.coverImage = image
        }

        /* 首帧封面先传（kind=chat 落 uploads/chat；服务端的 cover 是朋友圈封面，不能复用）：
           两端气泡直接显示封面，不为每个视频起播放器 */
        if let cover = meta.cover,
           let up = try? await APIClient.shared.upload(
               data: cover,
               filename: "cover_\(Int(Date().timeIntervalSince1970)).jpg",
               kind: "chat"
           ) {
            pendingVideos[local.listKey]?.cover = up.url
        }
        await uploadVideo(local)
    }

    /// 上传 + 发送视频（type=15）；失败后点「重发」会从临时文件重传
    private func uploadVideo(_ local: Message) async {
        guard let video = pendingVideos[local.listKey] else { return }
        uploadProgress[local.listKey] = 0
        do {
            let uploaded = try await APIClient.shared.uploadVideo(
                fileURL: video.fileURL,
                filename: video.fileURL.lastPathComponent
            ) { pct in
                Task { @MainActor in
                    let shown = uploadProgress[local.listKey] ?? 0
                    if pct - shown >= 0.01 || pct >= 1 {
                        uploadProgress[local.listKey] = pct
                    }
                }
            }
            var extra: [String: Any] = ["duration": video.duration]
            if !video.cover.isEmpty { extra["cover"] = video.cover }
            if video.width > 0, video.height > 0 {
                extra["w"] = Int(video.width)
                extra["h"] = Int(video.height)
            }
            let json = (try? JSONSerialization.data(withJSONObject: extra))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            let saved = try await APIClient.shared.sendTypedMessage(
                convType: convType, convId: convId, type: 15,
                content: uploaded.url + "|#|" + json,
                clientId: local.clientId ?? "ios_\(UUID().uuidString)"
            )
            finishPendingVideo(local)
            replaceLocal(local, with: saved.message)
            Task { await app.refreshConversations() }
        } catch {
            uploadProgress[local.listKey] = nil
            failLocal(local, "视频发送失败：\(error.localizedDescription)")
        }
    }

    private func finishPendingVideo(_ local: Message) {
        uploadProgress[local.listKey] = nil
        guard let video = pendingVideos.removeValue(forKey: local.listKey) else { return }
        try? FileManager.default.removeItem(at: video.fileURL)
    }

    private func videoExtension(_ item: PhotosPickerItem) -> String {
        for type in item.supportedContentTypes {
            if let ext = type.preferredFilenameExtension { return ext }
        }
        return "mov"
    }

    /// 时长 / 首帧封面 / 宽高：解不出来只影响封面，不挡发送
    private func videoMeta(_ url: URL) async -> (duration: Int, cover: Data?, width: Double, height: Double) {
        let asset = AVURLAsset(url: url)
        let length = try? await asset.load(.duration)
        let seconds = length?.seconds ?? 0
        var width: Double = 0
        var height: Double = 0
        if let track = (try? await asset.loadTracks(withMediaType: .video))?.first,
           let size = try? await track.load(.naturalSize) {
            /* 竖拍视频 naturalSize 是横的，按 preferredTransform 转一次才是显示尺寸 */
            if let transform = try? await track.load(.preferredTransform) {
                let oriented = size.applying(transform)
                width = abs(Double(oriented.width))
                height = abs(Double(oriented.height))
            } else {
                width = Double(size.width)
                height = Double(size.height)
            }
        }
        var cover: Data?
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)
        let time = CMTime(seconds: min(1, max(0, seconds / 2)), preferredTimescale: 600)
        if let frame = try? await generator.image(at: time) {
            cover = UIImage(cgImage: frame.image).jpegData(compressionQuality: 0.8)
        }
        return (Int(seconds.rounded()), cover, width, height)
    }

    private func sendSticker(_ url: String) async {
        let clientId = "sticker_" + UUID().uuidString
        var local = makeLocal(type: 5, content: url)
        local.clientId = clientId
        messages.append(local)
        do {
            let saved = try await APIClient.shared.sendImage(
                convType: convType, convId: convId, url: url, clientId: clientId
            )
            replaceLocal(local, with: saved.message)
            Task { await app.refreshConversations() }
        } catch {
            failLocal(local, "表情发送失败：\(error.localizedDescription)")
        }
    }

    /* ---------------- 操作 ---------------- */

    private func recall(_ msg: Message) async {
        guard msg.id > 0 else { return }
        do {
            try await app.recall(convType: convType, id: msg.id)
            /* 只有撤回者知道原文：记下来供「重新编辑」 */
            if msg.fromUid == myId, let raw = msg.text, !raw.isEmpty, !raw.hasPrefix("{") {
                recallOriginals[msg.id] = raw
            }
            if let idx = messages.firstIndex(where: { $0.id == msg.id }) {
                let label: String
                if msg.fromUid == myId {
                    label = "你撤回了一条消息"
                } else {
                    let nickname = app.user?.nickname ?? ""
                    label = "\(nickname.isEmpty ? "群成员" : nickname) 撤回了一条消息"
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
                Task { await app.refreshConversations() }
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
            Task { await app.refreshConversations() }
        } catch {
            failLocal(local, "图片发送失败：\(error.localizedDescription)")
        }
    }

    private func deleteLocalSilently(_ msg: Message) {
        messages.removeAll { $0.listKey == msg.listKey }
        finishPendingVideo(msg)
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
            if isGroup && ev.convId == convId {
                /* 发布/编辑公告（编辑会重置确认状态）：重拉待确认公告；
                   正在看公告列表/群资料时不弹层，避免盖住当前页面 */
                Task { await loadPendingNotice(showPopup: !showNotices && !showGroupInfo) }
            }
        case "redpacket_grab", "redpacket_receive", "transfer_receive", "gift_claim", "card_update":
            /* 服务端事件里只有 group_id/msg_id，AppState 已映射进 ChatEvent。
               能定位到本地这张卡片就按消息 id 精确重拉，否则退回整会话卡片状态刷新。 */
            guard ev.convId == 0 || ev.convId == convId else { return }
            let target = ev.msgId
            let hasTarget = target > 0 && messages.contains { $0.id == target }
            Task { @MainActor in
                if hasTarget {
                    await refreshCard(id: target)
                } else {
                    await refreshCardStates(force: true)
                }
            }
        default:
            break
        }
    }

    /// 还有未完成的卡片：红包未领完、转账/礼物/充值未处理
    private var hasPendingCards: Bool {
        messages.contains { isPendingCard($0) }
    }

    private func isPendingCard(_ m: Message) -> Bool {
        guard m.id > 0, cardMessageTypes.contains(m.type) else { return false }
        if m.type == 7 || m.type == 21 {
            if isGroup { return cardStatusInt(m, "finished") == 0 }
            return cardStatusInt(m, "status") == 0
        }
        return cardStatusInt(m, "status") == 0
    }

    private func cardStatusInt(_ m: Message, _ key: String) -> Int {
        if let v = m.extraMap[key]?.intValue { return v }
        if let o = MessageBody.jsonObject(m.content) ?? MessageBody.jsonObject(m.text) {
            if let n = o[key] as? NSNumber { return n.intValue }
            if let s = o[key] as? String {
                return Int(s.trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }
        return 0
    }

    private func startCardPolling() {
        guard cardPollTask == nil, scenePhase == .active, tabIsActive else { return }
        cardPollTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if Task.isCancelled { break }
                guard scenePhase == .active, hasPendingCards else { continue }
                await refreshCardStates(force: false)
            }
        }
    }

    /// 页面在屏上：接管本会话的通知抑制与卡片轮询
    private func activatePage() {
        guard tabIsActive else { return }
        LocalNotifier.shared.activeKey = LocalNotifier.shared.key(convType, convId)
        syncPeerConv()
        startCardPolling()
    }

    /// 页面离屏（返回 / 切到别的 tab）：不再轮询，也不该继续拦截本会话的通知
    private func pausePage() {
        LocalNotifier.shared.activeKey = nil
        cardPollTask?.cancel()
        cardPollTask = nil
    }

    private func buildDerived() -> ChatDerivedCache.Value {
        var value = ChatDerivedCache.Value()
        value.readHints = readHints
        value.membersByUid = memberMap
        value.mentions = mentionMap
        value.mentionStamp = value.mentions.hashValue
        value.dividers = dividerLabels
        value.firstUnread = firstUnreadIndex
        value.unreadCount = unreadMessageCount
        value.indexed = messages.enumerated().map {
            ChatDerivedCache.IndexedMessage(index: $0.offset, message: $0.element)
        }
        return value
    }

    @MainActor
    private func refreshCardStates(force: Bool = false) async {
        guard !loading, !cardRefreshing else { return }
        let now = Date().timeIntervalSince1970
        if now - lastCardRefresh < (force ? 1.0 : 2.5) { return }
        guard force || hasPendingCards else { return }
        cardRefreshing = true
        lastCardRefresh = now
        defer { cardRefreshing = false }
        /* 未完成的卡片按消息 id 精确拉：群刷屏时卡片掉出最近 40 条也不会漏刷 */
        let pendingIds = messages.filter { isPendingCard($0) }.map(\.id)
        if pendingIds.count <= 6 {
            for id in pendingIds {
                await refreshCard(id: id)
            }
            return
        }
        guard let data = try? await APIClient.shared.history(
            convType: convType, convId: convId, limit: 40
        ) else { return }
        mergeCardMessages(data.list)
    }

    /// 打开红包/转账/礼物详情时按消息 id 单独拉一次，避免旧卡片不在最近 40 条里
    @MainActor
    private func refreshCard(id: Int64) async {
        guard id > 0 else { return }
        guard let data = try? await APIClient.shared.history(
            convType: convType, convId: convId, beforeId: id + 1, limit: 10
        ) else { return }
        mergeCardMessages(data.list)
    }

    private func mergeCardMessages(_ fresh: [Message]) {
        guard !fresh.isEmpty else { return }
        var byId: [Int64: Message] = [:]
        for m in fresh where m.id > 0 { byId[m.id] = m }
        guard !byId.isEmpty else { return }

        var changed = false
        for i in messages.indices {
            let old = messages[i]
            guard old.id > 0, let m = byId[old.id] else { continue }
            guard cardMessageTypes.contains(old.type) || cardMessageTypes.contains(m.type) else { continue }
            if old == m { continue }
            var next = m
            next.localId = old.localId
            next.isRead = max(next.isRead, old.isRead)
            if next.fromName == nil { next.fromName = old.fromName }
            if next.fromAvatar == nil { next.fromAvatar = old.fromAvatar }
            messages[i] = next
            changed = true
        }
        if changed, let target = payTarget, target.id > 0,
           let latest = messages.first(where: { $0.id == target.id }) {
            payTarget = latest
        }
    }
}

/* ---------------- 单条消息 ---------------- */

/// 消息派生数据（已读提示 / 时间分隔 / 成员索引 / @ 名单）缓存。
/// body 会被 AppState 任意字段的发布触发重算，只有消息或成员真的变了才重跑这遍 O(n) 汇总。
/// 本身不发布任何状态，所以不会反向触发 SwiftUI 刷新。
private final class ChatDerivedCache: ObservableObject {
    struct Key: Equatable {
        var isGroup: Bool
        var myId: Int64
        var membersHidden: Bool
        var unreadAnchor: Int64
        var messages: [Message]
        var members: [GroupMember]
    }

    struct Value {
        var readHints: [String: Int] = [:]
        var membersByUid: [Int64: GroupMember] = [:]
        var mentions: [String: Int64] = [:]
        var mentionStamp = 0
        var dividers: [String: String] = [:]
        var firstUnread = -1
        var unreadCount = 0
        /// 预展开的「下标 + 消息」：ForEach 每次重算 body 都要 enumerate 一遍全量消息，
        /// 消息不变时跟着派生缓存一起复用，不再每帧新建一个元组数组
        var indexed: [IndexedMessage] = []
    }

    struct IndexedMessage {
        let index: Int
        let message: Message
    }

    private var key: Key?
    private var cached = Value()

    func value(for key: Key, build: () -> Value) -> Value {
        if let current = self.key, current == key { return cached }
        let started = AKPerf.start()
        let fresh = build()
        AKPerf.log("chat.derived", since: started, "\(key.messages.count) 条消息")
        self.key = key
        cached = fresh
        return fresh
    }
}

/// 输入框：文字状态只在本视图读取，打字不会让 ChatView 与消息列表重算
private struct ChatTextInput: View {
    @ObservedObject var composer: ChatComposerState
    let placeholder: String
    @FocusState.Binding var inputFocused: Bool
    var onChanged: (String) -> Void
    var onTap: () -> Void

    var body: some View {
        TextField(placeholder, text: $composer.text, axis: .vertical)
            .focused($inputFocused)
            .lineLimit(1...4)
            .font(.system(size: 14))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(AKColor.fill)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .onChange(of: composer.text) { value in
                onChanged(value)
            }
            .onTapGesture {
                onTap()
            }
    }
}

/// 输入栏右侧的发送/加号切换：只订阅输入文字，不带动父视图
private struct ChatComposerToggle: View {
    @ObservedObject var composer: ChatComposerState
    @Binding var showMore: Bool
    @Binding var showEmoji: Bool
    @Binding var voiceMode: Bool
    @FocusState.Binding var inputFocused: Bool
    var onSend: () -> Void

    private var hasText: Bool {
        !composer.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        if hasText {
            Button {
                onSend()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(AKColor.brand)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("发送")
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
}

private struct ChatMessageRow: View, Equatable {
    let message: Message
    let mine: Bool
    let isGroup: Bool
    let member: GroupMember?
    let myAvatar: String?
    let myUid: Int64
    let myName: String
    var peerName: String = "对方"
    let readHint: Int
    /// 视频上传百分比（仅本机待发视频有值）
    var uploadProgress: Double? = nil
    /// 待发视频的本地首帧（发送中显示，上传完成后换成服务端封面）
    var pendingVideoCover: UIImage? = nil
    let playingVoice: Bool
    var voicePlayed: Bool = true
    var mentionMap: [String: Int64] = [:]
    /// @ 名单的指纹：成员变化时行会重建，但比较本身不做 O(成员数) 的字典逐项对比
    var mentionStamp: Int = 0
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
    var onOpenMedia: (String, Bool) -> Void = { _, _ in }
    /// 自己撤回的文字消息原文：有值时在系统条下显示「重新编辑」
    var reeditText: String? = nil
    var onReedit: (String) -> Void = { _ in }

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
            onOpenMedia: onOpenMedia,
            peerName: peerName,
            mentionMap: mentionMap,
            mentionStamp: mentionStamp,
            onMention: onMention,
            voicePlayed: voicePlayed,
            uploadProgress: uploadProgress,
            pendingVideoCover: pendingVideoCover
        )
    }

    var body: some View {
        if message.type == 11 || message.recalled == 1 {
            HStack {
                Spacer(minLength: 36)
                VStack(spacing: 3) {
                    bodyView
                    if let original = reeditText, mine {
                        Button {
                            onReedit(original)
                        } label: {
                            Text("重新编辑")
                                .font(.system(size: 11.5))
                                .foregroundColor(AKColor.link)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
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
                        // 气泡里的 Text 链接与卡片点击手势会把普通 onLongPressGesture 吃掉，
                        // 用 simultaneousGesture 让长按与子手势同时识别，文字/图片/卡片都能弹菜单。
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.35)
                                .onEnded { _ in onLongPress() }
                        )

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

    /// LazyVStack 行复用：数据没变就跳过 body 重算（回调闭包不参与比较）
    static func == (lhs: ChatMessageRow, rhs: ChatMessageRow) -> Bool {
        lhs.message == rhs.message
            && lhs.mine == rhs.mine
            && lhs.isGroup == rhs.isGroup
            && lhs.member == rhs.member
            && lhs.myAvatar == rhs.myAvatar
            && lhs.myUid == rhs.myUid
            && lhs.myName == rhs.myName
            && lhs.peerName == rhs.peerName
            && lhs.readHint == rhs.readHint
            && lhs.uploadProgress == rhs.uploadProgress
            && lhs.pendingVideoCover === rhs.pendingVideoCover
            && lhs.playingVoice == rhs.playingVoice
            && lhs.voicePlayed == rhs.voicePlayed
            && lhs.mentionStamp == rhs.mentionStamp
            && lhs.reeditText == rhs.reeditText
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
    /// 自己撤回的文字消息才能「重新编辑」
    let canReedit: Bool
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
        if copyable != nil {
            out.append(Item(key: "copy", label: "复制", icon: "doc.on.doc"))
        }
        if message.type != 11 {
            if ForwardRules.canForward(message.type) {
                out.append(Item(key: "forward", label: "转发", icon: "arrowshape.turn.up.right"))
            }
            out.append(Item(key: "multi", label: "多选", icon: "checklist"))
        }
        if canPin {
            out.append(Item(key: "pin", label: pinned ? "取消置顶" : "置顶", icon: "pin"))
        }
        if message.type != 11 {
            out.append(Item(key: "reply", label: "回复", icon: "arrowshape.turn.up.left"))
            out.append(Item(key: "fav", label: "收藏", icon: "star"))
        }
        if message.type == 5 || message.type == 15 {
            out.append(Item(key: "save", label: "保存", icon: "square.and.arrow.down"))
        }
        if canAddEmoji {
            out.append(Item(key: "emoji", label: "添加到表情", icon: "face.smiling"))
        }
        if canReedit {
            out.append(Item(key: "reedit", label: "重新编辑", icon: "square.and.pencil"))
        }
        if canRecall {
            out.append(Item(key: "recall", label: mine ? "撤回" : "撤回该消息",
                            icon: "arrow.uturn.backward", danger: true))
        }
        if !mine && message.type != 11 {
            out.append(Item(key: "report", label: "举报", icon: "flag", danger: true))
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
        .presentationDetents([.height(items.count > 8 ? 330 : (items.count > 4 ? 250 : 170))])
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

/// 举报：选原因 + 补充说明（对齐安卓 ReportDialog）；消息与动态共用
struct ReportSheet: View {
    let title: String
    var preview: String? = nil
    let onSubmit: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var picked = -1
    @State private var note = ""

    private let reasons = ["色情低俗", "诈骗/赌博", "骚扰广告", "侵权内容"]

    var body: some View {
        Form {
            if let preview, !preview.isEmpty {
                Section("举报内容") {
                    Text(preview)
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.sub)
                        .lineLimit(3)
                }
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
        .navigationTitle(title)
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

/// 举报消息：复用 ReportSheet
private struct ReportMessageSheet: View {
    let message: Message
    let onSubmit: (String, String) -> Void

    private var preview: String {
        let raw = message.text ?? message.content ?? ""
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty || t.hasPrefix("{") { return "[消息]" }
        return String(t.prefix(60))
    }

    var body: some View {
        ReportSheet(title: "举报该消息", preview: preview, onSubmit: onSubmit)
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

/// 带进度的上传：URLSession 的 async 上传接口不回报进度，只能用任务代理
private final class ProgressUploader: NSObject, URLSessionTaskDelegate {
    private var onProgress: ((Double) -> Void)?

    func upload(request: URLRequest, body: Data,
                onProgress: @escaping (Double) -> Void) async throws -> (Data, URLResponse) {
        self.onProgress = onProgress
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(Data, URLResponse), Error>) in
            let task = session.uploadTask(with: request, from: body) { data, resp, error in
                if let error {
                    cont.resume(throwing: APIError.network(error.localizedDescription))
                } else if let data, let resp {
                    cont.resume(returning: (data, resp))
                } else {
                    cont.resume(throwing: APIError.network("视频上传失败"))
                }
            }
            task.resume()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        let pct = min(max(Double(totalBytesSent) / Double(totalBytesExpectedToSend), 0), 1)
        onProgress?(pct)
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

    /// 视频上传要真实百分比：Core 的 upload 是一次性请求拿不到进度，这里用带代理的上传任务
    func uploadVideo(fileURL: URL, filename: String,
                     onProgress: @escaping (Double) -> Void) async throws -> UploadData {
        let data = try Data(contentsOf: fileURL)
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        func append(_ s: String) { body.append(Data(s.utf8)) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"kind\"\r\n\r\nvideo\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: application/octet-stream\r\n\r\n")
        body.append(data)
        append("\r\n--\(boundary)--\r\n")

        var req = URLRequest(url: APIClient.base.appendingPathComponent("api/v1/upload"))
        req.httpMethod = "POST"
        req.timeoutInterval = 180
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = SessionStore.shared.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let uploader = ProgressUploader()
        let (respData, resp) = try await uploader.upload(request: req, body: body, onProgress: onProgress)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 { throw APIError.auth }
        guard let decoded = try? JSONDecoder().decode(APIResp<UploadData>.self, from: respData),
              decoded.code == 0, let payload = decoded.data else {
            throw APIError.server("视频上传失败")
        }
        return payload
    }
}

