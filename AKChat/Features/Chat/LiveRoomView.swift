import SwiftUI
import AVFoundation
import LiveKit
import ReplayKit
import UIKit
import Combine

/// 直播评论（含会员/靓号角标字段，Core 的 LiveComment 没有）
struct LiveCommentFull: Decodable, Identifiable {
    let id: Int64
    let uid: Int64
    let nickname: String?
    let avatar: String?
    let pretty: Int
    let prettyNo: String?
    let vipLevel: Int
    let content: String
    let createdAt: Int64
    let system: Int

    enum CodingKeys: String, CodingKey {
        case id, uid, nickname, avatar, pretty, content, system
        case prettyNo = "pretty_no"
        case vipLevel = "vip_level"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        uid = (try? c.decode(Int64.self, forKey: .uid)) ?? 0
        nickname = try? c.decode(String.self, forKey: .nickname)
        avatar = try? c.decode(String.self, forKey: .avatar)
        pretty = (try? c.decode(Int.self, forKey: .pretty)) ?? 0
        prettyNo = try? c.decode(String.self, forKey: .prettyNo)
        vipLevel = (try? c.decode(Int.self, forKey: .vipLevel)) ?? 0
        content = (try? c.decode(String.self, forKey: .content)) ?? ""
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
        system = (try? c.decode(Int.self, forKey: .system)) ?? 0
    }
}

struct LiveMicRequestItem: Decodable, Identifiable {
    let uid: Int64
    let nickname: String?
    let avatar: String?

    var id: Int64 { uid }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uid = (try? c.decode(Int64.self, forKey: .uid)) ?? 0
        nickname = try? c.decode(String.self, forKey: .nickname)
        avatar = try? c.decode(String.self, forKey: .avatar)
    }

    enum CodingKeys: String, CodingKey { case uid, nickname, avatar }
}

struct LiveMemberItem: Decodable, Identifiable {
    let uid: Int64
    let nickname: String?
    let avatar: String?
    let role: Int
    let mic: Int
    let requesting: Int
    let muted: Int
    let muteUntil: Int64

    var id: Int64 { uid }

    enum CodingKeys: String, CodingKey {
        case uid, nickname, avatar, role, mic, requesting, muted
        case muteUntil = "mute_until"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uid = (try? c.decode(Int64.self, forKey: .uid)) ?? 0
        nickname = try? c.decode(String.self, forKey: .nickname)
        avatar = try? c.decode(String.self, forKey: .avatar)
        role = (try? c.decode(Int.self, forKey: .role)) ?? 2
        mic = (try? c.decode(Int.self, forKey: .mic)) ?? 0
        requesting = (try? c.decode(Int.self, forKey: .requesting)) ?? 0
        muted = (try? c.decode(Int.self, forKey: .muted)) ?? 0
        muteUntil = (try? c.decode(Int64.self, forKey: .muteUntil)) ?? 0
    }
}

struct LiveMembersData: Decodable {
    let members: [LiveMemberItem]
    let hostId: Int64
    let canManage: Int

    enum CodingKeys: String, CodingKey {
        case members
        case hostId = "host_id"
        case canManage = "can_manage"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        members = (try? c.decode([LiveMemberItem].self, forKey: .members)) ?? []
        hostId = (try? c.decode(Int64.self, forKey: .hostId)) ?? 0
        canManage = (try? c.decode(Int.self, forKey: .canManage)) ?? 0
    }
}

struct LivePollFull: Decodable {
    let active: Int
    let status: Int
    let viewers: Int
    let screen: Int
    let comments: [LiveCommentFull]
    let maxCommentId: Int64
    let myMic: Int
    let myMuteUntil: Int64
    let myRequest: Int
    let allowMic: Int
    let micMode: Int
    let micRequests: [LiveMicRequestItem]
    let canManage: Int
    let hostId: Int64
    let kicked: Int

    enum CodingKeys: String, CodingKey {
        case active, status, viewers, screen, comments, kicked
        case maxCommentId = "max_comment_id"
        case myMic = "my_mic"
        case myMuteUntil = "my_mute_until"
        case myRequest = "my_request"
        case allowMic = "allow_mic"
        case micMode = "mic_mode"
        case micRequests = "mic_requests"
        case canManage = "can_manage"
        case hostId = "host_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        active = (try? c.decode(Int.self, forKey: .active)) ?? 0
        status = (try? c.decode(Int.self, forKey: .status)) ?? 1
        viewers = (try? c.decode(Int.self, forKey: .viewers)) ?? 0
        screen = (try? c.decode(Int.self, forKey: .screen)) ?? 0
        comments = (try? c.decode([LiveCommentFull].self, forKey: .comments)) ?? []
        maxCommentId = (try? c.decode(Int64.self, forKey: .maxCommentId)) ?? 0
        myMic = (try? c.decode(Int.self, forKey: .myMic)) ?? 0
        myMuteUntil = (try? c.decode(Int64.self, forKey: .myMuteUntil)) ?? 0
        myRequest = (try? c.decode(Int.self, forKey: .myRequest)) ?? 0
        allowMic = (try? c.decode(Int.self, forKey: .allowMic)) ?? 1
        micMode = (try? c.decode(Int.self, forKey: .micMode)) ?? 1
        micRequests = (try? c.decode([LiveMicRequestItem].self, forKey: .micRequests)) ?? []
        canManage = (try? c.decode(Int.self, forKey: .canManage)) ?? 0
        hostId = (try? c.decode(Int64.self, forKey: .hostId)) ?? 0
        kicked = (try? c.decode(Int.self, forKey: .kicked)) ?? 0
    }
}

/// 直播间弹层
private enum LiveSheet: Identifiable {
    case leave
    case members
    case member(LiveMemberItem)
    case mute(LiveMemberItem)
    case share
    case content
    case diagnostics

    var id: String {
        switch self {
        case .leave: return "leave"
        case .members: return "members"
        case .member(let m): return "member-\(m.uid)"
        case .mute(let m): return "mute-\(m.uid)"
        case .share: return "share"
        case .content: return "content"
        case .diagnostics: return "diagnostics"
        }
    }
}

/// 主播当前共享的是 App 内屏幕还是图片/视频/页面内容
private enum LiveShareMode {
    case screen
    case content
}

/// 群直播间：顶部标题/离开 → 40% 画面区（主播头像 + 在线人数）→ 评论区 → 弹幕输入 → 工具栏
/// 结构对齐安卓 GroupLiveScreen.kt + GroupLiveUi.kt（主播 5 项 / 观众 4 项）
struct LiveRoomView: View {
    let gid: Int64

    @Environment(\.dismiss) private var dismiss
    @StateObject private var room = Room()
    @StateObject private var kitObserver = LiveKitRoomObserver()

    @State private var phase = "loading"          // loading / prestart / room / blocked
    @State private var blockedMsg = ""
    @State private var liveId: Int64 = 0
    @State private var hostId: Int64 = 0
    @State private var hostName = ""
    @State private var hostAvatar: String?
    @State private var isHost = false
    @State private var liveTitle = ""
    @State private var viewers = 0
    @State private var comments: [LiveCommentFull] = []
    @State private var lastCommentId: Int64 = 0
    @State private var commentText = ""
    @State private var tip: String?
    @State private var pollTask: Task<Void, Never>?
    @State private var tipTask: Task<Void, Never>?

    @State private var groupName = ""
    @State private var startTitle = ""
    @State private var starting = false

    @State private var micOn = true
    @State private var camOn = false
    /// nil 表示未共享；.screen = App 内屏幕共享；.content = 图片/视频/页面内容共享
    @State private var shareMode: LiveShareMode?
    @State private var screenTrack: LocalVideoTrack?
    @State private var screenCapturer: BufferCapturer?
    @State private var screenPublication: LocalTrackPublication?
    @State private var connectError: String?
    @StateObject private var contentShare = LiveContentFeed()
    @StateObject private var pip = LivePiPController()
    /// 内容共享的说明文字（相册 N 张图片 / 视频 / 群聊画面 / 朋友圈画面）
    @State private var contentLabel = ""

    @State private var allowMic = 1
    @State private var micMode = 1
    @State private var myMic = 0
    @State private var myRequest = 0
    @State private var myMuteUntil: Int64 = 0
    @State private var canManage = 0
    @State private var members: [LiveMemberItem] = []
    @State private var micReqTarget: LiveMicRequestItem?
    @State private var sheet: LiveSheet?
    @State private var likeTick = 0
    @State private var screenFlag = 0
    @State private var closing = false

    /// 视频视图重建信号：回前台/重连后换一个新的渲染视图，避免停在最后一帧
    @State private var renderNonce = 0
    /// 连接进行中，避免前台事件与首次进房同时发起两次 connect
    @State private var connecting = false
    /// 已离开页面：所有异步连接回来时必须丢弃结果
    @State private var left = false
    /// 连接代号：旧的连接任务回来后不许覆盖新的错误/状态
    @State private var connectAttempt = 0
    /// App 在后台：不断开 Room，但暂停重连与轮询，回前台再恢复
    @State private var inBackground = false
    /// 主播端共享被系统在后台停掉，回前台提示可一键重新开始
    @State private var shareInterrupted = false
    /// 当前媒体房间与 identity（诊断面板直接显示，不依赖客户端内部字段）
    @State private var sfuRoom = ""
    @State private var localIdentity = ""
    /// 进入后台的时刻：回前台超过 1 秒就强制重连媒体房间
    @State private var backgroundAt: Date?
    /// 后台前是否有画面：回前台恢复失败时用来判断要不要提示中断
    @State private var hadVideoBeforeBackground = false
    /// 正在自动/手动恢复：前台事件与卡帧检测互斥
    @State private var recovering = false
    /// 自动重订阅次数用尽或重连失败：显示人工重连入口
    @State private var streamInterrupted = false
    /// 卡帧自动重订阅次数（最多 3 次）
    @State private var stallRecoveries = 0
    @State private var lastStallRecoveryAt: TimeInterval = 0
    /// 远端帧看门狗：3 秒没有新帧就重订阅
    @State private var frameWatchTask: Task<Void, Never>?

    private let bg = Color(hex: 0x0D0F14)
    private let panelBg = Color(hex: 0x14161B)
    private let white90 = Color.white.opacity(0.9)
    private let white60 = Color.white.opacity(0.6)
    private let white45 = Color.white.opacity(0.45)
    private let dangerColor = Color(hex: 0xFF5B6B)

    private var muted: Bool { myMuteUntil > Int64(Date().timeIntervalSince1970) }
    private var sharing: Bool { shareMode != nil }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            content
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await handleForeground() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            handleBackground()
        }
        .onChange(of: phase) { value in
            // 直播结束/被踢出：画中画也要一起收掉
            if value != "room" { pip.invalidate() }
        }
        .onDisappear {
            pollTask?.cancel()
            tipTask?.cancel()
            if !closing { Task { await teardown() } }
        }
        .sheet(item: $sheet) { s in
            switch s {
            case .leave:
                leaveSheet
            case .members:
                memberPanelSheet
            case .member(let m):
                memberActionSheet(m)
            case .mute(let m):
                muteSheet(m)
            case .share:
                shareSheet
            case .content:
                LiveContentPickerSheet(
                    makeGroupChat: { await makeGroupChatContent() },
                    makeMoments: { await makeMomentsContent() },
                    onReady: { selection in
                        sheet = nil
                        Task { await startContentShare(selection) }
                    },
                    onError: { message in
                        sheet = nil
                        showTip(message)
                    }
                )
            case .diagnostics:
                LiveDiagnosticsView(snapshot: { diagnosticsSnapshot() })
            }
        }
        .alert(item: $micReqTarget) { req in
            Alert(
                title: Text("上麦申请"),
                message: Text("\(req.nickname ?? "成员") 申请上麦"),
                primaryButton: .default(Text("同意")) {
                    Task { await memberAction(uid: req.uid, action: "handle_mic", approve: 1) }
                },
                secondaryButton: .cancel(Text("拒绝")) {
                    Task { await memberAction(uid: req.uid, action: "handle_mic", approve: 0) }
                }
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case "room": roomPage
        case "prestart": prestartPage
        case "blocked": blockedPage
        default: loadingView
        }
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView().tint(.white)
            Text("正在进入直播间…")
                .font(.system(size: 12))
                .foregroundColor(white60)
        }
    }

    // MARK: - 直播间

    private var roomPage: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                topBar
                stage(height: max(geo.size.height * 0.40, 180))
                if shareInterrupted && isHost {
                    shareInterruptedBar
                }
                if isHost && sharing {
                    shareHintBar
                }
                commentsPanel
                if let tip {
                    Text(tip)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: 0xFFB4B4))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 2)
                }
                inputRow
                toolBar
            }
        }
    }

    private var topBar: some View {
        ZStack {
            Text(liveTitle.isEmpty ? (groupName.isEmpty ? "群直播" : groupName) : liveTitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AKColor.text)
                .lineLimit(1)
                .padding(.horizontal, 68)
                .contentShape(Rectangle())
                // 隐藏入口：长按标题打开直播链路诊断
                .onLongPressGesture(minimumDuration: 0.8) { sheet = .diagnostics }
            HStack {
                Button {
                    sheet = .leave
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AKColor.text)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    sheet = .leave
                } label: {
                    Text("离开")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AKColor.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 48)
        .background(AKColor.card)
    }

    private func stage(height: CGFloat) -> some View {
        ZStack {
            Color.black
            // 观众端画中画的 AVSampleBufferDisplayLayer：必须在视图层级里，
            // 放在 LiveKit 画面层下方，不重复可见。
            if !isHost, pip.isSupported, displayTrack != nil {
                PiPDisplayView(displayLayer: pip.renderer.displayLayer)
                    .allowsHitTesting(false)
            }
            if let track = displayTrack {
                LiveKitVideoTile(track: track, refreshToken: kitObserver.revision,
                                 recoversFromStall: isHost,
                                 observesForeground: false)
                    .id(renderNonce)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if connectError != nil && !streamInterrupted {
                stageTip(title: "连接媒体服务器失败", detail: connectError, retry: true)
            } else if isHost {
                VStack(spacing: 6) {
                    Text(shareInterrupted ? "共享已中断" : (sharing ? "正在共享画面" : "观众暂未看到画面"))
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(.white)
                    Text(stageHintText)
                        .font(.system(size: 10.5))
                        .foregroundColor(Color.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    Button {
                        if sharing {
                            Task { await stopShare() }
                        } else {
                            sheet = .share
                        }
                    } label: {
                        Text(sharing ? "停止共享" : "开始共享")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(sharing ? Color.white.opacity(0.2) : AKColor.brand)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 24))
                        .foregroundColor(white45)
                    Text(room.connectionState == .connected
                         ? (screenFlag == 1 ? "正在接收主播的画面…" : "主播暂未共享画面")
                         : "正在进入直播间…")
                        .font(.system(size: 12))
                        .foregroundColor(white60)
                }
            }

            VStack {
                HStack(alignment: .top) {
                    VStack(spacing: 4) {
                        ZStack(alignment: .bottomTrailing) {
                            AvatarView(url: hostAvatar, name: hostName.isEmpty ? "主播" : hostName, size: 44)
                            ZStack {
                                Circle().fill(AKColor.brand).frame(width: 16, height: 16)
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.white)
                            }
                        }
                        Text(hostName.isEmpty ? "主播" : hostName)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .frame(width: 88)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                    if isHost && sharing {
                        HStack(spacing: 4) {
                            Circle().fill(dangerColor).frame(width: 6, height: 6)
                            Image(systemName: shareMode == .content ? "photo.fill" : "iphone")
                                .font(.system(size: 9))
                            Text(hostShareBadge)
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.58))
                        .clipShape(Capsule())
                    } else if !isHost && viewerScreenOn {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.on.rectangle")
                                .font(.system(size: 9))
                            Text("屏幕共享")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.58))
                        .clipShape(Capsule())
                    }
                }
                Spacer()
                HStack(spacing: 6) {
                    Spacer()
                    if !isHost, displayTrack != nil {
                        Button {
                            togglePiP()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: pip.isActive ? "pip.exit" : "pip.enter")
                                    .font(.system(size: 10, weight: .semibold))
                                Text(pip.isActive ? "退出小窗" : "小窗")
                                    .font(.system(size: 10.5, weight: .medium))
                            }
                            .foregroundColor(white90)
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    HStack(spacing: 5) {
                        Circle().fill(dangerColor).frame(width: 6, height: 6)
                        Text("\(viewers) 人在看")
                            .font(.system(size: 10.5))
                            .foregroundColor(white90)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)

            heartLayer

            // 画中画播放中：舞台不再重复播放一遍，给一个返回入口
            if !isHost, pip.isActive {
                VStack(spacing: 8) {
                    Image(systemName: "pip.fill")
                        .font(.system(size: 22))
                        .foregroundColor(white90)
                    Text("正在画中画播放")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(white90)
                    Button {
                        pip.stop()
                    } label: {
                        Text("回到直播画面")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.55))
            }

            // 画面还在但连接已失败，或自动恢复用尽：必须给人工重连入口，不能白屏死住
            if streamInterrupted || kitObserver.mediaInterrupted {
                VStack {
                    Spacer()
                    streamInterruptedBar
                        .padding(.bottom, 10)
                }
            } else if connectError != nil, displayTrack != nil {
                VStack {
                    Spacer()
                    stageTip(title: "画面已断开", detail: connectError, retry: true)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(Color.black.opacity(0.66))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(.bottom, 10)
                }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .onAppear {
            guard !isHost else { return }
            syncPiP()
            // 画中画要求 displayLayer 已在视图层级里，拿到轨道后再建控制器
            if displayTrack != nil { pip.prepare() }
        }
        .onChange(of: kitObserver.revision) { _ in
            guard !isHost else { return }
            syncPiP()
        }
        .onChange(of: displayTrack != nil) { hasVideo in
            guard !isHost, hasVideo else { return }
            pip.prepare()
            syncPiP()
        }
        .onChange(of: pip.isActive) { active in
            guard !isHost, !active else { return }
            // 收起小窗后重挂渲染器，避免回到直播画面停在最后一帧
            renderNonce &+= 1
            kitObserver.refresh()
            if !inBackground, phase == "room", !left, !closing, kitObserver.remoteVideo == nil {
                Task { await manualReconnect() }
            }
        }
    }

    /// 观众端把远端画面同步给画中画渲染器（主播不需要）
    private func syncPiP() {
        pip.sync(track: isHost ? nil : displayTrack)
    }

    /// 小窗按钮：启动结果由控制器异步回调，失败时把具体原因提示出来
    private func togglePiP() {
        if pip.isActive {
            pip.stop()
            return
        }
        pip.start { ok in
            guard !ok else { return }
            showTip(pip.lastError ?? "画中画暂不可用，请稍后再试")
        }
    }

    /// 回前台时屏幕共享已经被系统停掉：提示并提供一键重开
    private var shareInterruptedBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: 0xFFB020))
            Text("屏幕共享已被系统中断")
                .font(.system(size: 11.5))
                .foregroundColor(white90)
            Spacer(minLength: 4)
            Button {
                Task { await restartShare() }
            } label: {
                Text("重新开始共享")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AKColor.brand)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: 0x2A2110))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    /// 画面恢复失败/自动重订阅用尽：明确提示并允许用户手动重连
    private var streamInterruptedBar: some View {
        Button {
            Task { await manualReconnect() }
        } label: {
            VStack(spacing: 3) {
                Text(recovering ? "正在重连…" : "画面已中断，点击重连")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.white)
                Text("重连媒体服务器并重新订阅画面")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(recovering)
    }

    /// 主播共享中的常驻提示：屏幕共享离开 App 会断，内容共享只要 App 在前台就持续
    private var shareHintBar: some View {
        HStack(spacing: 6) {
            Image(systemName: shareMode == .content ? "photo.on.rectangle" : "iphone")
                .font(.system(size: 10))
                .foregroundColor(white45)
            Text(shareMode == .content
                 ? "内容共享中：\(contentLabel)（保持 App 打开即可）"
                 : "App 内屏幕共享，离开 App 会中断")
                .font(.system(size: 10.5))
                .foregroundColor(white60)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var stageHintText: String {
        if shareInterrupted { return "点下方「重新开始共享」恢复画面" }
        if shareMode == .content { return "正在展示：\(contentLabel)" }
        if shareMode == .screen { return "App 内屏幕共享，离开 App 会中断" }
        return "共享屏幕或展示内容，群成员即可实时观看"
    }

    private var hostShareBadge: String {
        if shareMode == .content { return "内容共享" }
        return "屏幕共享 · App 内"
    }

    private var viewerScreenOn: Bool {
        if screenFlag == 1 { return true }
        guard let track = kitObserver.remoteVideo else { return false }
        return track.source == .screenShareVideo
            || track.name == "screen"
            || track.name == Track.screenShareVideoName
    }

    private func stageTip(title: String, detail: String?, retry: Bool) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(white90)
            if let detail {
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundColor(Color(hex: 0xFFB4B4))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            if retry {
                Button {
                    Task {
                        if connecting {
                            showTip("正在连接，请稍候")
                        } else {
                            await manualReconnect()
                        }
                    }
                } label: {
                    Text("重试")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 点赞飘心：likeTick +1 冒一颗心
    private var heartLayer: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ZStack {
                    if likeTick > 0 {
                        Text("❤")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: 0xFF5A79))
                            .modifier(HeartRise(delay: 0))
                            .id(likeTick)
                    }
                }
                .padding(.trailing, 14)
                .padding(.bottom, 34)
            }
        }
    }

    private var displayTrack: VideoTrack? {
        if isHost {
            if let s = screenTrack { return s }
            return room.localParticipant.videoTracks.compactMap { $0.track as? VideoTrack }.first
        }
        // 订阅回调里记下的轨道最新；没有时再遍历远端参与者兜底
        if let remote = kitObserver.remoteVideo { return remote }
        for p in room.remoteParticipants.values {
            for pub in p.videoTracks {
                if let track = pub.track as? VideoTrack { return track }
            }
        }
        return nil
    }

    private var commentsPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("评论区")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(white90)
                Text("\(comments.count) 条")
                    .font(.system(size: 11))
                    .foregroundColor(white60)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 0.5)

            if comments.isEmpty {
                Text("还没有人发言，来说两句")
                    .font(.system(size: 12))
                    .foregroundColor(white45)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 22)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(comments) { c in
                                commentRow(c)
                                    .id(c.id)
                            }
                        }
                    }
                    .onChange(of: comments.count) { _ in
                        if let last = comments.last {
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(panelBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func commentRow(_ c: LiveCommentFull) -> some View {
        if c.system == 1 {
            Text(c.content)
                .font(.system(size: 12.5))
                .foregroundColor(Color(hex: 0xFF9A3D))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
        } else {
            HStack(alignment: .top, spacing: 8) {
                AvatarView(url: c.avatar, name: (c.nickname ?? "").isEmpty ? "成员" : (c.nickname ?? ""), size: 22)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text((c.nickname ?? "").isEmpty ? "成员" : (c.nickname ?? ""))
                            .font(.system(size: 11))
                            .foregroundColor(white60)
                            .lineLimit(1)
                        if c.pretty == 1, let no = c.prettyNo, !no.isEmpty {
                            BadgeView(text: no, color: AKColor.gold, background: AKColor.goldSoft)
                                .scaleEffect(0.78)
                        }
                        if c.vipLevel > 0 {
                            BadgeView(text: c.vipLevel == 2 ? "SVIP" : "VIP",
                                      color: c.vipLevel == 2 ? Color(hex: 0xD79A19) : AKColor.link,
                                      background: AKColor.blueSoft)
                                .scaleEffect(0.78)
                        }
                    }
                    Text(c.content)
                        .font(.system(size: 13))
                        .foregroundColor(white90)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            TextField("", text: $commentText)
                .font(.system(size: 14.5))
                .foregroundColor(muted ? Color(hex: 0x7E848D) : .white)
                .tint(AKColor.brand)
                .disabled(muted)
                .placeholder(when: commentText.isEmpty) {
                    Text(muted ? "你已被禁言" : "说点什么…")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: 0x8B9099))
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(muted ? Color.white.opacity(0.1) : Color.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .onChange(of: commentText) { value in
                    if value.count > 200 { commentText = String(value.prefix(200)) }
                }

            Button {
                Task { await sendComment() }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(muted ? Color.white.opacity(0.1) : AKColor.brand)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(muted)

            Button {
                likeTick += 1
            } label: {
                Text("❤")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: 0xFF6B81))
                    .frame(width: 36, height: 36)
                    .background(Color(hex: 0xFF4757).opacity(0.2))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var toolBar: some View {
        HStack(spacing: 0) {
            if isHost {
                toolItem(icon: micOn ? "mic.fill" : "mic.slash.fill",
                         label: micOn ? "麦克风" : "已静音",
                         active: micOn) {
                    Task { await toggleHostMic() }
                }
                toolItem(icon: camOn ? "video.fill" : "video.slash.fill",
                         label: "摄像头",
                         active: camOn) {
                    Task { await toggleCamera() }
                }
                toolItem(icon: sharing ? "stop.circle.fill" : "rectangle.on.rectangle",
                         label: sharing ? "停止共享" : "共享",
                         active: sharing,
                         dot: sharing) {
                    if sharing {
                        Task { await stopShare() }
                    } else {
                        sheet = .share
                    }
                }
                toolItem(icon: "person.2.fill", label: "成员 \(viewers)") {
                    sheet = .members
                    Task { await loadMembers() }
                }
                toolItem(icon: "stop.circle", label: "结束直播", danger: true) {
                    Task { await endLive() }
                }
            } else {
                toolItem(
                    icon: myMic == 1 || myRequest == 1 ? "mic.fill" : "mic.slash.fill",
                    label: micLabel,
                    active: myMic == 1 || myRequest == 1,
                    enabled: micEnabled
                ) {
                    Task { await toggleTalk() }
                }
                toolItem(icon: "video.slash.fill", label: "摄像头", enabled: false) {}
                toolItem(icon: "person.2.fill", label: "成员 \(viewers)") {
                    sheet = .members
                    Task { await loadMembers() }
                }
                toolItem(icon: "square.and.arrow.up", label: "分享") {
                    Task { await shareToChat() }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
    }

    private var micLabel: String {
        if myMic == 1 { return "闭麦" }
        if myRequest == 1 { return "申请中" }
        if !micEnabled { return "已禁麦" }
        return micMode == 0 ? "开麦" : "申请上麦"
    }

    private var micEnabled: Bool {
        myMic == 1 || myRequest == 1
            || (allowMic == 1 && myMuteUntil <= Int64(Date().timeIntervalSince1970))
    }

    private func toolItem(icon: String, label: String, active: Bool = false, danger: Bool = false,
                          dot: Bool = false,
                          enabled: Bool = true, action: @escaping () -> Void) -> some View {
        let tint: Color = !enabled ? white45 : (danger ? dangerColor : (active ? AKColor.brand : white90))
        return Button(action: action) {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(active ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(tint)
                        .overlay(alignment: .topTrailing) {
                            if dot {
                                Circle()
                                    .fill(dangerColor)
                                    .frame(width: 7, height: 7)
                                    .offset(x: 2, y: -1)
                            }
                        }
                }
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(tint)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - 弹层

    private var leaveSheet: some View {
        VStack(spacing: 10) {
            Text("要离开直播间吗？")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AKColor.text)
                .padding(.top, 18)
                .padding(.bottom, 6)
            sheetRow(icon: "xmark.circle", label: "离开直播间", detail: nil, danger: true) {
                sheet = nil
                Task { await leaveRoom() }
            }
            sheetRow(icon: nil, label: "取消", detail: nil) {
                sheet = nil
            }
            Color.clear.frame(height: 16)
        }
        .presentationDetents([.height(220)])
    }

    private var memberPanelSheet: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text("发言成员")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(AKColor.text)
                Text("(\(members.filter { $0.mic == 1 }.count))")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.sub)
                Spacer(minLength: 6)
                Text("\(members.filter { $0.mic == 1 }.count) 人上麦")
                    .font(.system(size: 10.5))
                    .foregroundColor(AKColor.sub)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            if canManage == 1 || isHost {
                Button {
                    Task { await toggleAllowMic() }
                } label: {
                    HStack {
                        Text("允许观众说话")
                            .font(.system(size: 12.5))
                            .foregroundColor(AKColor.text)
                        Spacer()
                        Text(allowMic == 1 ? "已开启" : "已关闭")
                            .font(.system(size: 11.5))
                            .foregroundColor(allowMic == 1 ? AKColor.brand : AKColor.sub)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if members.isEmpty {
                Text("暂无成员")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.placeholder)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 8) {
                        ForEach(members) { m in
                            Button {
                                sheet = .member(m)
                            } label: {
                                memberCell(m)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            Spacer(minLength: 0)
        }
        .background(AKColor.card.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }

    private func memberCell(_ m: LiveMemberItem) -> some View {
        let onMic = m.uid == hostId || m.mic == 1
        return VStack(spacing: 3) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(url: m.avatar, name: (m.nickname ?? "").isEmpty ? "成员" : (m.nickname ?? ""), size: 44)
                ZStack {
                    Circle()
                        .fill(onMic ? AKColor.brand : Color(hex: 0x3A3F47))
                        .frame(width: 16, height: 16)
                    Image(systemName: onMic ? "mic.fill" : "mic.slash.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.white)
                }
            }
            .overlay(alignment: .topTrailing) {
                if m.muted == 1 {
                    Circle().fill(dangerColor).frame(width: 8, height: 8)
                }
            }
            Text(m.uid == hostId ? "主播" : ((m.nickname ?? "").isEmpty ? "成员" : (m.nickname ?? "")))
                .font(.system(size: 10))
                .foregroundColor(AKColor.text)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func memberActionSheet(_ m: LiveMemberItem) -> some View {
        let isHostRow = m.uid == hostId
        let tags = [
            isHostRow ? "主播" : "观众",
            isHostRow || m.mic == 1 ? "上麦中" : "未上麦",
            m.requesting == 1 ? "申请上麦" : nil,
            m.muted == 1 ? "已禁言" : nil
        ].compactMap { $0 }.joined(separator: " · ")
        return VStack(spacing: 6) {
            HStack(spacing: 12) {
                AvatarView(url: m.avatar, name: (m.nickname ?? "").isEmpty ? "成员" : (m.nickname ?? ""), size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text((m.nickname ?? "").isEmpty ? "成员" : (m.nickname ?? ""))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AKColor.text)
                        .lineLimit(1)
                    Text(tags)
                        .font(.system(size: 11))
                        .foregroundColor(AKColor.sub)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 6)

            if (canManage == 1 || isHost) && !isHostRow {
                sheetRow(icon: "mic.slash", label: m.mic == 1 ? "关闭连麦" : "开启连麦", detail: nil) {
                    let action = m.mic == 1 ? "mute_mic" : "unmute_mic"
                    sheet = nil
                    Task { await memberAction(uid: m.uid, action: action) }
                }
                if m.muted == 1 {
                    sheetRow(icon: "speaker.wave.2", label: "解除禁言", detail: nil) {
                        sheet = nil
                        Task { await memberAction(uid: m.uid, action: "unmute_comment") }
                    }
                } else {
                    sheetRow(icon: "speaker.slash", label: "禁言", detail: "可选 10 分钟 / 1 小时 / 今天 / 永久") {
                        sheet = .mute(m)
                    }
                }
                sheetRow(icon: "xmark.circle", label: "踢出直播间", detail: nil, danger: true) {
                    sheet = nil
                    Task { await memberAction(uid: m.uid, action: "kick") }
                }
            } else {
                Text(isHostRow ? "主播不可管理" : "只有主播或群主/管理员可以管理成员")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.placeholder)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                sheetRow(icon: nil, label: "关闭", detail: nil) { sheet = nil }
            }
            Color.clear.frame(height: 14)
        }
        .presentationDetents([.height(360)])
    }

    private func muteSheet(_ m: LiveMemberItem) -> some View {
        VStack(spacing: 4) {
            Text("禁言 \((m.nickname ?? "").isEmpty ? "该成员" : (m.nickname ?? ""))")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AKColor.text)
                .padding(.top, 18)
            Text("禁言期间无法在直播间发送弹幕")
                .font(.system(size: 11.5))
                .foregroundColor(AKColor.sub)
                .padding(.bottom, 8)
            sheetRow(icon: nil, label: "10 分钟", detail: nil) {
                sheet = nil
                Task { await memberAction(uid: m.uid, action: "mute_comment", duration: 600) }
            }
            sheetRow(icon: nil, label: "1 小时", detail: nil) {
                sheet = nil
                Task { await memberAction(uid: m.uid, action: "mute_comment", duration: 3600) }
            }
            sheetRow(icon: nil, label: "今天", detail: "到今天 24:00") {
                sheet = nil
                Task { await memberAction(uid: m.uid, action: "mute_comment", duration: todayRemainSeconds()) }
            }
            sheetRow(icon: nil, label: "永久", detail: nil, danger: true) {
                sheet = nil
                Task { await memberAction(uid: m.uid, action: "mute_comment", duration: 0) }
            }
            sheetRow(icon: nil, label: "取消", detail: nil) { sheet = nil }
            Color.clear.frame(height: 12)
        }
        .presentationDetents([.height(420)])
    }

    private func sheetRow(icon: String?, label: String, detail: String?, danger: Bool = false,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 17))
                        .foregroundColor(danger ? dangerColor : AKColor.text)
                        .frame(width: 20)
                }
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(danger ? dangerColor : AKColor.text)
                Spacer(minLength: 6)
                if let detail {
                    Text(detail)
                        .font(.system(size: 10.5))
                        .foregroundColor(AKColor.sub)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var prestartPage: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
            }
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                AvatarView(url: hostAvatar, name: groupName.isEmpty ? "群聊" : groupName, size: 72)
                Text("开始直播")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.top, 12)
                Text("先给本次直播起个标题，观众在直播间顶部就能看到")
                    .font(.system(size: 11.5))
                    .foregroundColor(Color.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
                    .padding(.horizontal, 20)

                TextField("", text: $startTitle)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .tint(AKColor.brand)
                    .placeholder(when: startTitle.isEmpty) {
                        Text("直播标题（2~30 字）")
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(Color(hex: 0x1E222B))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top, 16)
                    .onChange(of: startTitle) { value in
                        if value.count > 30 { startTitle = String(value.prefix(30)) }
                    }

                HStack {
                    Text(startTitle.trimmingCharacters(in: .whitespaces).count >= 2
                         ? "标题会随本次直播保存" : "标题需 2~30 个字")
                        .font(.system(size: 10.5))
                        .foregroundColor(startTitle.trimmingCharacters(in: .whitespaces).count >= 2
                                         ? Color.white.opacity(0.55) : Color(hex: 0xFFB4B4))
                    Spacer()
                    Text("\(startTitle.count)/30")
                        .font(.system(size: 10.5))
                        .foregroundColor(Color.white.opacity(0.55))
                }
                .padding(.top, 6)

                Button {
                    Task { await startLive() }
                } label: {
                    Text(starting ? "开播中…" : "开始直播")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(startTitle.trimmingCharacters(in: .whitespaces).count >= 2
                                    ? AKColor.red : Color(hex: 0xFF5B6B).opacity(0.35))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(starting || startTitle.trimmingCharacters(in: .whitespaces).count < 2)
                .padding(.top, 18)

                Button {
                    dismiss()
                } label: {
                    Text("取消")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.65))
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)

                Text("开播后共享你的手机屏幕，群成员可实时观看。\n只有群主/管理员可以开播。")
                    .font(.system(size: 10.5))
                    .foregroundColor(Color.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 28)
            Spacer(minLength: 0)
            if let tip {
                Text(tip)
                    .font(.system(size: 11.5))
                    .foregroundColor(Color(hex: 0xFFB4B4))
                    .padding(.bottom, 20)
            }
        }
    }

    private var blockedPage: some View {
        VStack(spacing: 14) {
            Spacer()
            AvatarView(url: hostAvatar, name: groupName.isEmpty ? "群聊" : groupName, size: 72)
            Text(blockedMsg.isEmpty ? "直播已结束" : blockedMsg)
                .font(.system(size: 14))
                .foregroundColor(white90)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button {
                dismiss()
            } label: {
                Text("返回")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.14))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 数据

    private func load() async {
        // 不在这里收广播：App 被系统杀掉时扩展可能仍在推流，
        // 等知道自己是主播还是观众后再决定恢复还是收掉（见 attach）。
        phase = "loading"
        guard gid > 0 else {
            blockedMsg = "直播间参数缺失，请返回群聊后重新进入"
            phase = "blocked"
            return
        }
        do {
            let data = try await APIClient.shared.liveRoom(gid: gid)
            if let info = try? await APIClient.shared.groupInfo(id: gid) {
                groupName = info.name ?? ""
                hostAvatar = info.avatar
            }
            if let live = data.live {
                await attach(live: live)
            } else if data.liveAllowed == 0 {
                blockedMsg = liveText(data.msg, fallback: "该群未开通直播间（仅靓号群可开播）")
                phase = "blocked"
            } else if data.canStart == 1 {
                startTitle = groupName
                phase = "prestart"
            } else {
                blockedMsg = liveText(data.msg, fallback: "直播已结束")
                phase = "blocked"
            }
        } catch {
            blockedMsg = liveText(error.localizedDescription, fallback: "进入直播间失败，请稍后重试")
            phase = "blocked"
        }
    }

    /// 服务端缺参时只回“参数错误”，直播间场景下改成能指导操作的文案
    private func liveText(_ raw: String?, fallback: String) -> String {
        let t = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return fallback }
        if t == "参数错误" { return "直播间参数缺失，请返回群聊后重新进入" }
        return t
    }

    private func attach(live: LiveInfo) async {
        liveId = live.id
        hostId = live.hostId
        hostName = live.hostName
        if let av = live.hostAvatar, !av.isEmpty { hostAvatar = av }
        isHost = live.myRole == 1
        viewers = live.viewers
        screenFlag = live.screen ?? 0
        allowMic = live.allowMic
        micMode = live.micMode
        let t = live.title.trimmingCharacters(in: .whitespaces)
        liveTitle = (!t.isEmpty && t != "群直播") ? t : groupName
        comments = []
        lastCommentId = 0
        phase = "room"
        if isHost {
            // 主播重新进入：不自动开麦，避免静默开播
            micOn = false
        }
        kitObserver.attach(room)
        startPolling()
        await connectSfu()
        startFrameWatchdog()
        await loadMembers()
    }

    private func connectSfu(_ create: Bool = false, title: String = "", forceReconnect: Bool = false) async {
        guard !left, !closing else { return }
        // 后台不主动断开，但也不再发起新连接（含重连），等回前台再继续
        guard !inBackground else { return }
        if room.connectionState == .connected && !forceReconnect { return }
        // 同一时刻只允许一条连接：旧 attempt 晚回来时不能把新连接断掉
        if connecting { return }

        connectAttempt &+= 1
        let attempt = connectAttempt
        connecting = true
        defer {
            if attempt == connectAttempt { connecting = false }
        }
        connectError = nil

        if forceReconnect {
            lkLog("reconnect begin state=\(room.connectionState)")
            // 先摘掉旧的事件桥与旧轨，重连完成后重新挂，避免 UI 继续渲染已死的轨道
            kitObserver.detach()
            if room.connectionState != .disconnected {
                await room.disconnect()
            }
        }
        guard attempt == connectAttempt, !left, !closing else { return }

        var query = ["id": "\(gid)"]
        if create {
            query["create"] = "1"
            query["title"] = title
        }

        let data: LiveRoomData
        do {
            data = try await APIClient.shared.get("api/v1/group/live/room", query: query)
        } catch {
            guard attempt == connectAttempt, !left, !closing else { return }
            let raw = error.localizedDescription
            connectError = raw == "参数错误"
                ? "直播间参数缺失，请返回群聊后重新进入"
                : "进入直播间失败：\(raw)"
            return
        }
        guard attempt == connectAttempt, !left, !closing else { return }

        let serverMsg = liveText(data.msg, fallback: "")
        guard let sfu = data.sfu else {
            connectError = serverMsg.isEmpty ? "媒体服务未启用（服务端未返回 SFU 配置）" : serverMsg
            return
        }
        if let roomName = sfu.room, !roomName.isEmpty { sfuRoom = roomName }
        if (sfu.enabled ?? 1) != 1 {
            connectError = serverMsg.isEmpty ? "媒体服务未启用（SFU enabled=0）" : serverMsg
            return
        }
        let rawURL = (sfu.url ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawURL.isEmpty else {
            connectError = "媒体服务配置缺少 URL，请联系管理员"
            return
        }
        let rawToken = (sfu.token ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawToken.isEmpty else {
            connectError = "媒体服务未返回 Token，请重试"
            return
        }
        guard let u = URL(string: rawURL) else {
            connectError = "媒体服务地址无效：\(rawURL)"
            return
        }

        /* LiveKit 连接可能长时间停在 connecting：兜底提示，避免画面区永远显示「正在进入直播间」 */
        let watchdog = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard !Task.isCancelled, attempt == connectAttempt, !left, !closing else { return }
            if room.connectionState != .connected, connectError == nil {
                connectError = "连接媒体服务器超时（15 秒），请检查网络后重试"
            }
        }
        do {
            try await room.connect(url: u.absoluteString, token: rawToken)
            watchdog.cancel()
            // 连接期间用户已经离开：必须断开，不能把新连接留在后台
            guard attempt == connectAttempt, !left, !closing else {
                await room.disconnect()
                return
            }
            connectError = nil
            kitObserver.attach(room)
            kitObserver.refresh()
            localIdentity = room.localParticipant.identity?.stringValue ?? ""
            if forceReconnect {
                await restoreLocalTracksAfterReconnect()
                lkLog("reconnect ok state=\(room.connectionState) \(kitObserver.videoDiagnosticsText())")
            } else if isHost && micOn {
                try? await room.localParticipant.setMicrophone(enabled: true)
            }
        } catch {
            watchdog.cancel()
            guard attempt == connectAttempt, !left, !closing else { return }
            connectError = "连接媒体服务器失败：\(error.localizedDescription)"
        }
    }

    /// 回前台：先重建渲染视图，再根据连接状态决定是否重新进房。
    /// App 内屏幕采集会被系统停掉，内容共享只要前台就继续推帧。
    private func handleForeground() async {
        inBackground = false
        guard phase == "room", !left, !closing else { return }
        // 画中画还在播放：保留当前媒体连接，重连会打断悬浮窗
        if pip.isActive {
            backgroundAt = nil
            hadVideoBeforeBackground = false
            startFrameWatchdog()
            return
        }
        let away = backgroundAt.map { Date().timeIntervalSince($0) } ?? 0
        backgroundAt = nil
        var expectVideo = hadVideoBeforeBackground
        hadVideoBeforeBackground = false
        if isHost, shareMode == .screen, sharing {
            shareInterrupted = !RPScreenRecorder.shared().isRecording
        }
        if isHost && sharing {
            expectVideo = true
        }
        if room.connectionState == .connected {
            // 连接状态还是 connected 不代表媒体没断：切后台超过 1 秒一律重连，
            // 只有短暂失焦（控制中心/来电横幅）才只重挂渲染器。
            guard !connecting else { return }
            startFrameWatchdog()
            if away >= 1.0 {
                await recoverAfterForeground(expectVideo: expectVideo)
            } else {
                renderNonce &+= 1
                kitObserver.refresh()
            }
            return
        }
        // 首连还在进行中：等它自己完成/超时，不抢它的连接任务
        guard !connecting else { return }
        startFrameWatchdog()
        await recoverAfterForeground(expectVideo: expectVideo)
    }

    /// 回前台重连：断开旧 Room → 用服务端新 token 重进 → 恢复本地推流 → 重新订阅远端轨 → 重建渲染视图
    private func recoverAfterForeground(expectVideo: Bool) async {
        guard phase == "room", !left, !closing, !inBackground, !recovering else { return }
        recovering = true
        streamInterrupted = false
        await connectSfu(forceReconnect: true)
        let connected = connectError == nil && room.connectionState == .connected
        if connected {
            let ok: Bool
            if isHost {
                // 主播画面是本机轨道（摄像头/屏幕/内容共享），重连后由
                // restoreLocalTracksAfterReconnect 重新发布，不存在远端订阅可做。
                ok = true
            } else {
                ok = await resubscribeRemoteVideoWhenReady(expectVideo: expectVideo)
            }
            lkLog("foreground recovered=1 resub=\(ok) \(kitObserver.videoDiagnosticsText())")
            if isHost {
                streamInterrupted = false
            } else if (expectVideo || kitObserver.remoteVideo != nil) && !ok && kitObserver.remoteVideo == nil {
                streamInterrupted = true
            } else {
                streamInterrupted = false
            }
            stallRecoveries = 0
            lastStallRecoveryAt = 0
        } else {
            lkLog("foreground reconnect failed error=\(connectError ?? "-")")
            streamInterrupted = true
        }
        recovering = false
        renderNonce &+= 1
        kitObserver.refresh()
        startFrameWatchdog()
    }

    /// 人工重连：失败时不自动循环，清错误后重连一次；仍失败继续显示入口
    private func manualReconnect() async {
        guard phase == "room", !left, !closing, !connecting, !recovering else { return }
        let expectVideo = displayTrack != nil || streamInterrupted || kitObserver.mediaInterrupted
        recovering = true
        streamInterrupted = false
        stallRecoveries = 0
        lastStallRecoveryAt = 0
        lkLog("manual reconnect begin state=\(room.connectionState)")
        await connectSfu(forceReconnect: true)
        if connectError == nil && room.connectionState == .connected {
            let ok: Bool
            if isHost {
                ok = true
            } else {
                ok = await resubscribeRemoteVideoWhenReady(expectVideo: expectVideo)
            }
            if isHost {
                streamInterrupted = false
            } else {
                streamInterrupted = expectVideo && !ok && kitObserver.remoteVideo == nil
            }
            lkLog("manual reconnect ok resub=\(ok) \(kitObserver.videoDiagnosticsText())")
        } else {
            streamInterrupted = true
            lkLog("manual reconnect failed error=\(connectError ?? "-")")
        }
        recovering = false
        renderNonce &+= 1
        kitObserver.refresh()
        startFrameWatchdog()
    }

    /// 重连会断开本地发布：主播恢复麦克风/摄像头，共享中的轨道重新发布
    private func restoreLocalTracksAfterReconnect() async {
        guard room.connectionState == .connected else { return }
        if isHost {
            if micOn { try? await room.localParticipant.setMicrophone(enabled: true) }
            if camOn { try? await room.localParticipant.setCamera(enabled: true) }
            if sharing {
                guard let track = screenTrack else {
                    shareInterrupted = true
                    return
                }
                // 屏幕采集可能被系统停掉：重连后重新挂同一个 BufferCapturer
                if shareMode == .screen, let capturer = screenCapturer,
                   !RPScreenRecorder.shared().isRecording {
                    startScreenCapture(capturer)
                }
                do {
                    screenPublication = try await room.localParticipant.publish(videoTrack: track)
                    shareInterrupted = false
                } catch {
                    lkLog("republish screen failed: \(error.localizedDescription)")
                    screenPublication = nil
                    screenTrack = nil
                    screenCapturer = nil
                    contentShare.stop()
                    shareMode = nil
                    contentLabel = ""
                    shareInterrupted = true
                }
            }
        } else if myMic == 1 {
            try? await room.localParticipant.setMicrophone(enabled: true)
        }
    }

    /// 重连后远端参与者可能还没同步完：最多等 6 秒，期间反复尝试重新订阅
    private func resubscribeRemoteVideoWhenReady(expectVideo: Bool) async -> Bool {
        guard expectVideo || kitObserver.remoteVideo != nil else { return false }
        let deadline = Date().addingTimeInterval(6)
        while Date() < deadline {
            if await kitObserver.resubscribeVideo() {
                return true
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            kitObserver.refresh()
            if kitObserver.remoteVideo != nil { return true }
        }
        return kitObserver.remoteVideo != nil
    }

    /// 3 秒没有新帧：自动重订阅；最多 3 次，超过后交给人工重连按钮。
    private func handleVideoStall() {
        guard phase == "room", !left, !closing, !inBackground, !recovering else { return }
        let now = Date().timeIntervalSince1970
        guard now - lastStallRecoveryAt >= 3 else { return }
        lastStallRecoveryAt = now
        guard stallRecoveries < 3 else {
            streamInterrupted = true
            lkLog("stall exhausted \(kitObserver.videoDiagnosticsText())")
            return
        }
        stallRecoveries += 1
        let attempt = stallRecoveries
        Task { @MainActor in
            recovering = true
            lkLog("stall attempt=\(attempt) \(kitObserver.videoDiagnosticsText())")
            if isHost && sharing {
                await restartShare()
                renderNonce &+= 1
                recovering = false
                return
            }
            let ok = await resubscribeRemoteVideoWhenReady(expectVideo: true)
            recovering = false
            if ok || kitObserver.remoteVideo != nil {
                streamInterrupted = false
                renderNonce &+= 1
                kitObserver.refresh()
                lkLog("stall recovered attempt=\(attempt)")
            } else {
                streamInterrupted = true
                lkLog("stall failed attempt=\(attempt)")
            }
        }
    }

    /// 远端画面看门狗：轨道在但 3 秒无新帧，或订阅后 4 秒还没首帧，就进入自动恢复。
    private func startFrameWatchdog() {
        frameWatchTask?.cancel()
        frameWatchTask = Task { @MainActor in
            var videoSince: Date?
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
                guard phase == "room", !inBackground, !left, !closing,
                      UIApplication.shared.applicationState == .active else {
                    videoSince = nil
                    continue
                }
                guard let track = kitObserver.remoteVideo, !track.isMuted else {
                    videoSince = nil
                    stallRecoveries = 0
                    continue
                }
                if videoSince == nil { videoSince = Date() }
                if let last = kitObserver.lastScreenFrameAt {
                    let age = Date().timeIntervalSince(last)
                    if age < 1.5 { stallRecoveries = 0 }
                    if age >= 3 { handleVideoStall() }
                } else if let since = videoSince,
                          Date().timeIntervalSince(since) >= 4 {
                    handleVideoStall()
                    videoSince = Date()
                }
            }
        }
    }

    private func lkLog(_ message: String) {
        #if DEBUG
        print("[LiveKit] \(message)")
        #endif
    }

    /// 切后台：不断开 Room，只暂停重连与轮询；App 内屏幕采集会被系统停掉。
    private func handleBackground() {
        inBackground = true
        backgroundAt = Date()
        hadVideoBeforeBackground = displayTrack != nil
        frameWatchTask?.cancel()
        frameWatchTask = nil
        if isHost && sharing && shareMode == .screen {
            shareInterrupted = true
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled && phase == "room" {
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                if Task.isCancelled { break }
                guard !inBackground else { continue }
                await poll()
            }
        }
    }

    private func poll() async {
        guard !inBackground, liveId > 0, phase == "room" else { return }
        guard let st: LivePollFull = try? await APIClient.shared.get(
            "api/v1/group/live/poll",
            query: ["id": "\(gid)", "live_id": "\(liveId)", "last_comment_id": "\(lastCommentId)"]
        ) else { return }
        if st.kicked == 1 {
            blockedMsg = "你已被主播移出该直播间"
            phase = "blocked"
            pollTask?.cancel()
            pip.invalidate()
            await room.disconnect()
            return
        }
        if st.status == 0 || st.active == 0 {
            blockedMsg = "直播已结束"
            phase = "blocked"
            pollTask?.cancel()
            pip.invalidate()
            await stopSharingForEndedLive()
            await room.disconnect()
            return
        }
        viewers = st.viewers
        screenFlag = st.screen
        canManage = st.canManage
        allowMic = st.allowMic
        micMode = st.micMode
        myMuteUntil = st.myMuteUntil
        myRequest = st.myRequest
        if !isHost && st.myMic != myMic {
            myMic = st.myMic
            try? await room.localParticipant.setMicrophone(enabled: myMic == 1)
        }
        if !st.comments.isEmpty {
            comments.append(contentsOf: st.comments)
            if comments.count > 120 { comments.removeFirst(comments.count - 120) }
        }
        if st.maxCommentId > lastCommentId { lastCommentId = st.maxCommentId }
        if (canManage == 1 || isHost) && !st.micRequests.isEmpty && micReqTarget == nil {
            micReqTarget = st.micRequests.first
        }
    }

    private func loadMembers() async {
        guard liveId > 0 else { return }
        if let data: LiveMembersData = try? await APIClient.shared.get(
            "api/v1/group/live/members", query: ["id": "\(gid)", "live_id": "\(liveId)"]
        ) {
            members = data.members
            if data.hostId > 0 { hostId = data.hostId }
            canManage = data.canManage
        }
    }

    private func sendComment() async {
        let content = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, liveId > 0 else { return }
        commentText = ""
        do {
            _ = try await APIClient.shared.liveComment(gid: gid, liveId: liveId, content: content)
            await poll()
        } catch {
            showTip(error.localizedDescription)
        }
    }

    private func startLive() async {
        guard gid > 0 else { showTip("直播间参数缺失，请返回群聊后重试"); return }
        let t = startTitle.trimmingCharacters(in: .whitespaces)
        guard t.count >= 2 else { showTip("直播标题需 2~30 个字"); return }
        starting = true
        defer { starting = false }
        do {
            let data: LiveRoomData = try await APIClient.shared.get("api/v1/group/live/room", query: [
                "id": "\(gid)", "create": "1", "title": t,
            ])
            if let live = data.live {
                await attach(live: live)
            } else {
                blockedMsg = liveText(data.msg, fallback: "开播失败，请稍后重试")
                phase = "blocked"
            }
        } catch {
            showTip(liveText(error.localizedDescription, fallback: "开播失败，请稍后重试"))
        }
    }

    private func shareToChat() async {
        let payload: [String: Any] = [
            "gid": gid,
            "name": groupName,
            "avatar": hostAvatar ?? "",
            "title": liveTitle.isEmpty ? groupName : liveTitle,
            "live_id": liveId,
        ]
        guard let json = try? JSONSerialization.data(withJSONObject: payload),
              let content = String(data: json, encoding: .utf8) else { return }
        await APIClient.shared.postIgnore("api/v1/messages", body: [
            "conv_type": "group",
            "conv_id": gid,
            "type": 19,
            "content": content,
            "client_msg_id": "ios_live_\(UUID().uuidString)",
        ])
        showTip("已分享到群聊")
    }

    // MARK: - 主播控制

    private func toggleHostMic() async {
        let next = !micOn
        do {
            try await room.localParticipant.setMicrophone(enabled: next)
            micOn = next
            await APIClient.shared.postIgnore("api/v1/group/live/mic", body: [
                "id": gid, "live_id": liveId, "value": next ? 1 : 0,
            ])
        } catch {
            showTip("切换麦克风失败：\(error.localizedDescription)")
        }
    }

    private func toggleCamera() async {
        let next = !camOn
        do {
            try await room.localParticipant.setCamera(enabled: next)
            camOn = next
        } catch {
            showTip("切换摄像头失败：\(error.localizedDescription)")
        }
    }

    private func toggleTalk() async {
        guard liveId > 0, !isHost else { return }
        if myMic == 1 {
            myMic = 0
            await APIClient.shared.postIgnore("api/v1/group/live/mic", body: [
                "id": gid, "live_id": liveId, "value": 0,
            ])
            try? await room.localParticipant.setMicrophone(enabled: false)
            showTip("麦克风已关闭")
            return
        }
        if myRequest == 1 {
            myRequest = 0
            await APIClient.shared.postIgnore("api/v1/group/live/request_mic", body: [
                "id": gid, "live_id": liveId, "off": 1,
            ])
            showTip("已取消申请")
            return
        }
        do {
            _ = try await APIClient.shared.postRaw("api/v1/group/live/request_mic", body: [
                "id": gid, "live_id": liveId, "off": 0,
            ])
            myRequest = 1
            showTip("已申请上麦，等待主播同意")
        } catch {
            showTip(error.localizedDescription)
        }
    }

    private func toggleAllowMic() async {
        let next = allowMic == 1 ? 0 : 1
        allowMic = next
        await APIClient.shared.postIgnore("api/v1/group/live/allow_mic", body: [
            "id": gid, "live_id": liveId, "value": next,
        ])
        showTip(next == 1 ? "已允许观众说话" : "已禁止观众说话")
    }

    private func memberAction(uid: Int64, action: String, duration: Int = 0, approve: Int = 0) async {
        do {
            _ = try await APIClient.shared.postRaw("api/v1/group/live/member", body: [
                "id": gid,
                "live_id": liveId,
                "user_id": uid,
                "action": action,
                "duration": duration,
                "approve": approve,
            ])
            let text: String = {
                switch action {
                case "kick": return "已移出直播间"
                case "mute_mic": return "已关闭对方连麦"
                case "unmute_mic": return "已开启对方连麦"
                case "mute_comment": return "已禁言"
                case "unmute_comment": return "已解除禁言"
                case "handle_mic": return approve == 1 ? "已同意上麦" : "已拒绝上麦"
                default: return "操作成功"
                }
            }()
            showTip(text)
            await loadMembers()
        } catch {
            showTip(error.localizedDescription)
        }
    }

    // MARK: - 共享（App 内屏幕 / 内容）

    /// 主播点「共享」先选方式：整屏采集，或展示图片/视频/页面内容
    private var shareSheet: some View {
        VStack(spacing: 6) {
            Text("共享给观众")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AKColor.text)
                .padding(.top, 18)
                .padding(.bottom, 4)
            sheetRow(icon: "iphone", label: "共享屏幕",
                     detail: "App 内采集，离开 App 会中断") {
                sheet = nil
                Task { await startScreenShare() }
            }
            sheetRow(icon: "photo.on.rectangle", label: "共享内容",
                     detail: "相册图片/视频、群聊或朋友圈画面") {
                // 先收起当前面板再弹选择器：同一个 .sheet(item:) 直接换 item 时，
                // 内容不一定刷新，偶发停在旧面板上
                sheet = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    sheet = .content
                }
            }
            sheetRow(icon: nil, label: "取消", detail: nil) { sheet = nil }
            Color.clear.frame(height: 14)
        }
        .presentationDetents([.height(300)])
    }

    /// 共享当前 App 的屏幕：ReplayKit 前台采集 + BufferCapturer 推帧，麦克风仍走 LiveKit
    private func startScreenShare() async {
        guard isHost, !sharing else { return }
        let track = await LocalVideoTrack.createBufferTrack(name: "screen")
        guard let capturer = track.capturer as? BufferCapturer else {
            showTip("当前设备不支持屏幕共享")
            return
        }
        screenTrack = track
        screenCapturer = capturer
        startScreenCapture(capturer)
        do {
            screenPublication = try await room.localParticipant.publish(videoTrack: track)
            shareMode = .screen
            contentLabel = ""
            shareInterrupted = false
            await notifyScreen(1)
            showTip("屏幕共享已开始，离开 App 会中断")
        } catch {
            RPScreenRecorder.shared().stopCapture { _ in }
            screenTrack = nil
            screenCapturer = nil
            shareMode = nil
            showTip("共享失败：\(error.localizedDescription)")
        }
    }

    /// 共享内容：图片/视频/渲染好的群聊或朋友圈页面，用 BufferCapturer 持续推帧
    private func startContentShare(_ selection: LiveContentSelection) async {
        guard isHost, !sharing else { return }
        let track = await LocalVideoTrack.createBufferTrack(
            name: "screen",
            options: BufferCaptureOptions(dimensions: .h720_169, fps: 15)
        )
        guard let capturer = track.capturer as? BufferCapturer else {
            showTip("当前设备不支持内容共享")
            return
        }
        screenTrack = track
        let ready = await contentShare.start(capturer: capturer, source: selection.source)
        guard ready else {
            screenTrack = nil
            showTip("内容加载失败，请换一个试试")
            return
        }
        do {
            screenPublication = try await room.localParticipant.publish(videoTrack: track)
            shareMode = .content
            contentLabel = selection.label
            shareInterrupted = false
            await notifyScreen(1)
            showTip("内容共享已开始：\(selection.label)")
        } catch {
            contentShare.stop()
            screenTrack = nil
            shareMode = nil
            contentLabel = ""
            showTip("共享失败：\(error.localizedDescription)")
        }
    }

    private func makeGroupChatContent() async -> LiveContentSelection? {
        guard let data = try? await APIClient.shared.history(convType: "group", convId: gid, limit: 24),
              !data.list.isEmpty,
              let image = LivePageRenderer.groupChat(title: groupName.isEmpty ? "群聊" : groupName,
                                                    messages: data.list) else { return nil }
        return LiveContentSelection(source: .page(image), label: "群聊画面")
    }

    private func makeMomentsContent() async -> LiveContentSelection? {
        guard let data = try? await APIClient.shared.moments(page: 1),
              !data.list.isEmpty,
              let image = LivePageRenderer.moments(data.list) else { return nil }
        return LiveContentSelection(source: .page(image), label: "朋友圈画面")
    }

    /// 屏幕采集单独拆出：iOS 回后台会停掉 RPScreenRecorder，重新开始时用同一个 BufferCapturer 重挂
    private func startScreenCapture(_ capturer: BufferCapturer) {
        RPScreenRecorder.shared().isMicrophoneEnabled = false
        RPScreenRecorder.shared().startCapture { sample, type, _ in
            if type == .video { capturer.capture(sample) }
        } completionHandler: { err in
            Task { @MainActor in
                if let err {
                    if isHost && sharing { shareInterrupted = true }
                    showTip("屏幕采集失败：\(err.localizedDescription)")
                } else {
                    shareInterrupted = false
                }
            }
        }
    }

    /// 一键重新开始共享
    private func restartShare() async {
        guard isHost else { return }
        if shareMode == .screen {
            if let pub = screenPublication {
                try? await room.localParticipant.unpublish(publication: pub)
            }
            screenPublication = nil
            screenTrack = nil
            screenCapturer = nil
            shareMode = nil
            RPScreenRecorder.shared().stopCapture { _ in }
            // stopCapture 是异步收尾的，立刻 startCapture 会报「正在录制中」
            try? await Task.sleep(nanoseconds: 300_000_000)
            await startScreenShare()
            if sharing { shareInterrupted = false }
            return
        }
        guard shareMode == .content, let track = screenTrack else { return }
        do {
            screenPublication = try await room.localParticipant.publish(videoTrack: track)
            shareInterrupted = false
        } catch {
            showTip("恢复共享失败：\(error.localizedDescription)")
        }
    }

    private func stopShare() async {
        guard sharing else { return }
        if shareMode == .screen {
            RPScreenRecorder.shared().stopCapture { _ in }
        }
        contentShare.stop()
        if let pub = screenPublication {
            try? await room.localParticipant.unpublish(publication: pub)
        }
        screenPublication = nil
        screenTrack = nil
        screenCapturer = nil
        shareMode = nil
        contentLabel = ""
        shareInterrupted = false
        await notifyScreen(0)
        showTip("已停止共享")
    }

    /// 直播结束时本地收尾：不再回调 screen 接口（服务端已结束）
    private func stopSharingForEndedLive() async {
        if shareMode == .screen {
            RPScreenRecorder.shared().stopCapture { _ in }
        }
        contentShare.stop()
        screenPublication = nil
        screenTrack = nil
        screenCapturer = nil
        shareMode = nil
        contentLabel = ""
        shareInterrupted = false
    }

    private var connectionStateText: String {
        switch room.connectionState {
        case .connected: return "connected"
        case .connecting: return "connecting"
        case .reconnecting: return "reconnecting"
        case .disconnecting: return "disconnecting"
        case .disconnected: return "disconnected"
        default: return "unknown"
        }
    }

    private func diagnosticsSnapshot() -> LiveDiagnosticsInfo {
        LiveDiagnosticsInfo(
            shareMode: shareMode == .content ? "内容共享（\(contentLabel)）"
                : (shareMode == .screen ? "App 内屏幕共享" : "未共享"),
            sfuRoom: sfuRoom,
            localIdentity: localIdentity,
            connectionState: connectionStateText,
            screenTrackReceived: kitObserver.screenTrackReceived,
            lastFrameAge: kitObserver.lastScreenFrameAt.map { Date().timeIntervalSince($0) },
            mediaInterrupted: kitObserver.mediaInterrupted,
            pipActive: pip.isActive
        )
    }

    private func notifyScreen(_ value: Int) async {
        guard liveId > 0 else { return }
        await APIClient.shared.postIgnore("api/v1/group/live/screen", body: [
            "id": gid, "live_id": liveId, "value": value,
        ])
    }

    // MARK: - 退出

    private func endLive() async {
        guard liveId > 0, !closing else { return }
        closing = true
        pollTask?.cancel()
        await APIClient.shared.postIgnore("api/v1/group/live/end", body: ["id": gid, "live_id": liveId])
        await teardown()
        dismiss()
    }

    private func leaveRoom() async {
        guard !closing else { return }
        closing = true
        pollTask?.cancel()
        if liveId > 0 {
            await APIClient.shared.postIgnore("api/v1/group/live/leave", body: ["id": gid, "live_id": liveId])
        }
        await teardown()
        dismiss()
    }

    private func teardown() async {
        left = true
        connectAttempt &+= 1
        connecting = false
        inBackground = false
        shareInterrupted = false
        pollTask?.cancel()
        tipTask?.cancel()
        frameWatchTask?.cancel()
        frameWatchTask = nil
        backgroundAt = nil
        hadVideoBeforeBackground = false
        recovering = false
        streamInterrupted = false
        kitObserver.detach()
        pip.invalidate()
        if sharing {
            if shareMode == .screen {
                RPScreenRecorder.shared().stopCapture { _ in }
            }
            contentShare.stop()
            await notifyScreen(0)
        }
        screenPublication = nil
        screenTrack = nil
        screenCapturer = nil
        shareMode = nil
        contentLabel = ""
        await room.disconnect()
    }

    private func showTip(_ message: String) {
        tip = message
        tipTask?.cancel()
        tipTask = Task {
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            if !Task.isCancelled, tip == message { tip = nil }
        }
    }

    private func todayRemainSeconds() -> Int {
        let now = Int64(Date().timeIntervalSince1970)
        let dayStart = (now + 28800) / 86400 * 86400 - 28800
        return Int(max(min(dayStart + 86400 - now, 86400), 60))
    }
}

/// 飘心动画：从底部往上飘并淡出
private struct HeartRise: ViewModifier {
    let delay: Double
    @State private var up = false

    func body(content: Content) -> some View {
        content
            .offset(y: up ? -160 : 0)
            .opacity(up ? 0 : 1)
            .onAppear {
                withAnimation(.linear(duration: 1.4).delay(delay)) { up = true }
            }
    }
}

private extension View {
    /// TextField 暗色占位文案（SwiftUI 的 prompt 参数不支持单独着色）
    func placeholder<Content: View>(when shouldShow: Bool, @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: .leading) {
            if shouldShow { placeholder() }
            self
        }
    }
}
