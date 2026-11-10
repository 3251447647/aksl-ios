import SwiftUI
import LiveKit
import ReplayKit
import UIKit
import Combine
import AVFoundation

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

    var id: String {
        switch self {
        case .leave: return "leave"
        case .members: return "members"
        case .member(let m): return "member-\(m.uid)"
        case .mute(let m): return "mute-\(m.uid)"
        }
    }
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
    @State private var sharing = false
    @State private var screenTrack: LocalVideoTrack?
    @State private var screenPublication: LocalTrackPublication?
    @State private var connectError: String?

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
    /// 主播端屏幕共享被系统在后台停掉，回前台提示可一键重新开始
    @State private var shareInterrupted = false
    /// 当前走系统广播（可切后台）还是 App 内采集（切后台会停）
    @State private var usingBroadcastShare = false
    @State private var usingInAppShare = false
    /// 已弹出系统广播选择器，等待主播确认
    @State private var broadcastPending = false
    /// 服务端签发的主播屏幕共享扩展凭证（独立 identity，用于推画面+系统声音）
    @State private var broadcastSfu: BroadcastSfuInfo?
    /// 本次系统广播是否已把系统声音凭证交给扩展
    @State private var broadcastAudioRequested = false
    /// 是否为共享系统声音改过 AVAudioSession（只有主播会改，观众不能动）
    @State private var screenShareAudioSessionApplied = false

    private let bg = Color(hex: 0x0D0F14)
    private let panelBg = Color(hex: 0x14161B)
    private let white90 = Color.white.opacity(0.9)
    private let white60 = Color.white.opacity(0.6)
    private let white45 = Color.white.opacity(0.45)
    private let dangerColor = Color(hex: 0xFF5B6B)

    private var muted: Bool { myMuteUntil > Int64(Date().timeIntervalSince1970) }

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
        .onReceive(BroadcastStateCenter.shared.started) { _ in
            Task { await handleBroadcastState(true) }
        }
        .onReceive(BroadcastStateCenter.shared.stopped) { _ in
            Task { await handleBroadcastState(false) }
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
                if isHost && usingInAppShare && sharing {
                    inAppShareHint
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
            if let track = displayTrack {
                LiveKitVideoTile(track: track, refreshToken: kitObserver.revision, recoversFromStall: true)
                    .id(renderNonce)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if connectError != nil {
                stageTip(title: "连接媒体服务器失败", detail: connectError, retry: true)
            } else if isHost {
                VStack(spacing: 6) {
                    Text(broadcastPending
                         ? "等待系统确认…"
                         : (shareInterrupted ? "屏幕共享已中断" : (sharing ? "正在共享你的屏幕" : "观众暂未看到画面")))
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(.white)
                    Text(broadcastPending
                         ? "在系统弹窗里选「AK商聊屏幕共享」并点「开始直播」"
                         : (shareInterrupted
                            ? "点下方「重新开始共享」恢复画面"
                            : (sharing
                               ? (usingBroadcastShare
                                  ? (kitObserver.screenAudioActive
                                     ? "可切到其他 App，观众能看到画面并听到系统声音"
                                     : "可切到其他 App，观众能看到画面")
                                  : "App 内共享只采集本应用画面，不含系统声音")
                               : "共享屏幕或开启摄像头，群成员即可实时观看")))
                        .font(.system(size: 10.5))
                        .foregroundColor(Color.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    Button {
                        if broadcastPending {
                            showTip("请在系统弹窗中选择「开始直播」")
                        } else {
                            Task {
                                if sharing { await stopShare() } else { await startShare() }
                            }
                        }
                    } label: {
                        Text(broadcastPending ? "等待开始…" : (sharing ? "停止屏幕共享" : "开始屏幕共享"))
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
                            Image(systemName: usingBroadcastShare
                                  ? (kitObserver.screenAudioActive ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                  : "speaker.slash.fill")
                                .font(.system(size: 9))
                            Text(hostShareBadge)
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.58))
                        .clipShape(Capsule())
                    } else if !isHost && viewerScreenOn {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.on.rectangle")
                                .font(.system(size: 9))
                            Text(kitObserver.screenAudioActive ? "屏幕共享 · 含声音" : "屏幕共享")
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
                HStack {
                    Spacer()
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

            // 画面还在但连接已失败（典型是回前台重连失败）：盖一条错误，不能只停在最后一帧
            if connectError != nil, displayTrack != nil {
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

    /// 签名缺少 App Groups 时只能 App 内采集，切后台会中断
    private var inAppShareHint: some View {
        Text("App 内共享不含系统声音，离开 App 会中断")
            .font(.system(size: 10.5))
            .foregroundColor(white60)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 4)
    }

    private var hostShareBadge: String {
        guard usingBroadcastShare else { return "App 内共享 · 无系统声音" }
        if kitObserver.screenAudioActive { return "屏幕共享 · 含系统声音" }
        return broadcastAudioRequested ? "屏幕共享 · 声音连接中" : "屏幕共享 · 无系统声音"
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
                            await connectSfu(forceReconnect: true)
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
            // 系统广播：画面由扩展用独立 identity 发布，本机看到的是远端屏幕轨
            if let remote = kitObserver.remoteVideo,
               usingBroadcastShare || BroadcastBridge.isFlaggedActive {
                return remote
            }
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
                         label: broadcastPending ? "等待中" : (sharing ? "停止共享" : "共享屏幕"),
                         active: sharing,
                         dot: sharing,
                         enabled: !broadcastPending) {
                    Task {
                        if sharing { await stopShare() } else { await startShare() }
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
        // App 被杀后扩展可能还在跑：重新进直播间时先收掉残留广播
        if BroadcastBridge.isFlaggedActive {
            BroadcastControl.requestStop()
            BroadcastBridge.markStopped()
            BroadcastBridge.clearSession()
        }
        phase = "loading"
        do {
            let data = try await APIClient.shared.liveRoom(gid: gid)
            if let info = try? await APIClient.shared.groupInfo(id: gid) {
                groupName = info.name ?? ""
                hostAvatar = info.avatar
            }
            if let live = data.live {
                await attach(live: live)
            } else if data.liveAllowed == 0 {
                blockedMsg = (data.msg ?? "").isEmpty ? "该群未开通直播间（仅靓号群可开播）" : (data.msg ?? "")
                phase = "blocked"
            } else if data.canStart == 1 {
                startTitle = groupName
                phase = "prestart"
            } else {
                blockedMsg = (data.msg ?? "").isEmpty ? "直播已结束" : (data.msg ?? "")
                phase = "blocked"
            }
        } catch {
            blockedMsg = error.localizedDescription
            phase = "blocked"
        }
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
            // 屏幕由扩展用独立 identity 发布，主 App 不再自动创建广播采集轨
            BroadcastManager.shared.shouldPublishTrack = false
        }
        kitObserver.extensionAudioIdentityToMute = isHost ? "\(live.hostId)_bc" : nil
        kitObserver.attach(room)
        startPolling()
        await connectSfu()
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

        if forceReconnect, room.connectionState != .disconnected {
            await room.disconnect()
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
            connectError = "进入直播间失败：\(error.localizedDescription)"
            return
        }
        guard attempt == connectAttempt, !left, !closing else { return }

        let serverMsg = (data.msg ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let sfu = data.sfu else {
            connectError = serverMsg.isEmpty ? "媒体服务未启用（服务端未返回 SFU 配置）" : serverMsg
            return
        }
        if isHost, let broadcast = sfu.broadcast { broadcastSfu = broadcast }
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
            kitObserver.refresh()
            if isHost && micOn {
                try? await room.localParticipant.setMicrophone(enabled: true)
            }
        } catch {
            watchdog.cancel()
            guard attempt == connectAttempt, !left, !closing else { return }
            connectError = "连接媒体服务器失败：\(error.localizedDescription)"
        }
    }

    /// 回前台：先重建渲染视图，再根据连接状态决定是否重新进房。
    /// 系统广播可后台持续，只有 App 内采集会被系统停掉。
    private func handleForeground() async {
        inBackground = false
        guard phase == "room", !left, !closing else { return }
        renderNonce &+= 1
        kitObserver.refresh()
        if isHost {
            if usingBroadcastShare {
                // App Group 标记由扩展在 started/finished 时写，比主 App 可能漏收的
                // Darwin 通知更可靠；回前台时据此补启动或收尾。
                let flagged = BroadcastBridge.isFlaggedActive
                if flagged {
                    shareInterrupted = false
                    if !sharing {
                        await handleBroadcastState(true)
                    } else {
                        applyScreenShareAudioSession()
                        ScreenShareKeepAlive.shared.start()
                    }
                } else if sharing {
                    BroadcastControl.requestStop()
                    await finishBroadcastShare()
                    showTip("屏幕共享已结束")
                } else {
                    broadcastPending = false
                    usingBroadcastShare = false
                    broadcastAudioRequested = false
                    ScreenShareKeepAlive.shared.stop()
                    restoreScreenShareAudioSession()
                }
            } else if usingInAppShare {
                shareInterrupted = sharing && !RPScreenRecorder.shared().isRecording
            }
        }
        if room.connectionState == .connected { return }
        // 首连还在进行中：只重建画面，等它自己完成/超时
        guard !connecting else { return }
        await connectSfu(forceReconnect: true)
    }

    /// 切后台：不断开 Room，只暂停重连与轮询；只有 App 内采集会被系统停掉。
    private func handleBackground() {
        inBackground = true
        if isHost && sharing && usingInAppShare {
            shareInterrupted = true
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled && phase == "room" {
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                if Task.isCancelled { break }
                // 系统广播期间主播切到其他 App 也要保持心跳，否则服务端 60 秒收不到主播
                // 心跳会把直播判定为主播离线并结束。
                guard !inBackground || hostBroadcastHeartbeatNeeded else { continue }
                await poll()
            }
        }
    }

    private var hostBroadcastHeartbeatNeeded: Bool {
        isHost && (usingBroadcastShare || BroadcastBridge.isFlaggedActive)
    }

    private func poll() async {
        guard !inBackground || hostBroadcastHeartbeatNeeded,
              liveId > 0, phase == "room" else { return }
        guard let st: LivePollFull = try? await APIClient.shared.get(
            "api/v1/group/live/poll",
            query: ["id": "\(gid)", "live_id": "\(liveId)", "last_comment_id": "\(lastCommentId)"]
        ) else { return }
        if st.kicked == 1 {
            blockedMsg = "你已被主播移出该直播间"
            phase = "blocked"
            pollTask?.cancel()
            await room.disconnect()
            return
        }
        if st.status == 0 || st.active == 0 {
            blockedMsg = "直播已结束"
            phase = "blocked"
            pollTask?.cancel()
            if isHost && (usingBroadcastShare || BroadcastBridge.isFlaggedActive) {
                BroadcastControl.requestStop()
                BroadcastBridge.markStopped()
                BroadcastBridge.clearSession()
                sharing = false
                usingBroadcastShare = false
                broadcastAudioRequested = false
                ScreenShareKeepAlive.shared.stop()
                restoreScreenShareAudioSession()
            }
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
                blockedMsg = (data.msg ?? "").isEmpty ? "开播失败，请稍后重试" : (data.msg ?? "")
                phase = "blocked"
            }
        } catch {
            showTip(error.localizedDescription)
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

    /// 开始共享：签名与 IPA 支持系统广播时走 Broadcast Upload Extension（可后台），
    /// 否则退回 App 内 ReplayKit 采集（切后台会停，且不含系统声音）。
    private func startShare() async {
        guard !sharing, !broadcastPending else { return }
        if ScreenBroadcastSupport.isAvailable {
            await refreshBroadcastSfu()
            if let sfu = broadcastSfu,
               (sfu.enabled ?? 1) == 1,
               let url = sfu.url, !url.isEmpty,
               let token = sfu.token, !token.isEmpty,
               let roomName = sfu.room, !roomName.isEmpty,
               let identity = sfu.identity, !identity.isEmpty,
               BroadcastBridge.saveSession(BroadcastSessionConfig(url: url, token: token, room: roomName, identity: identity)) {
                BroadcastManager.shared.shouldPublishTrack = false
                applyScreenShareAudioSession()
                // 选择器期间就占用 audio 后台模式，避免主播在系统弹窗/其他 App 停留时被挂起
                ScreenShareKeepAlive.shared.start()
                broadcastAudioRequested = true
                usingBroadcastShare = true
                usingInAppShare = false
                broadcastPending = true
                BroadcastManager.shared.requestActivation()
                showTip("请选择「AK商聊屏幕共享」并点「开始直播」，系统声音会一并共享")
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 60_000_000_000)
                    guard !Task.isCancelled, broadcastPending else { return }
                    // 自定义 started 通知丢了也能从 App Group 标记恢复
                    if BroadcastBridge.isFlaggedActive {
                        await handleBroadcastState(true)
                        return
                    }
                    broadcastPending = false
                    usingBroadcastShare = false
                    broadcastAudioRequested = false
                    ScreenShareKeepAlive.shared.stop()
                    restoreScreenShareAudioSession()
                    showTip("未开始屏幕共享，可重试")
                }
                return
            }
            // 服务端没签发扩展凭证时不硬走扩展，否则画面也发布不出去
            broadcastAudioRequested = false
            showTip("系统声音凭证不可用，已改用 App 内共享（不含系统声音）")
        }
        usingInAppShare = true
        usingBroadcastShare = false
        await startInAppShare()
    }

    /// 重新获取扩展专用凭证：长时间直播后旧 token 可能过期，开始共享时刷新一次
    private func refreshBroadcastSfu() async {
        guard isHost, liveId > 0 else { return }
        guard let data: LiveRoomData = try? await APIClient.shared.get(
            "api/v1/group/live/room", query: ["id": "\(gid)"]
        ) else { return }
        if let fresh = data.sfu?.broadcast { broadcastSfu = fresh }
    }

    private func startInAppShare() async {
        let track = await LocalVideoTrack.createBufferTrack(name: "screen")
        guard let capturer = track.capturer as? BufferCapturer else {
            usingInAppShare = false
            showTip("当前设备不支持屏幕共享")
            return
        }
        screenTrack = track
        startScreenCapture(capturer)
        do {
            let pub = try await room.localParticipant.publish(videoTrack: track)
            screenPublication = pub
            sharing = true
            shareInterrupted = false
            await notifyScreen(1)
            showTip("App 内共享已开始（不含系统声音，切到后台会中断）")
        } catch {
            RPScreenRecorder.shared().stopCapture { _ in }
            screenTrack = nil
            usingInAppShare = false
            showTip("共享失败：\(error.localizedDescription)")
        }
    }

    /// 共享系统声音期间允许其他 App 的声音继续播放。
    /// LiveKit 默认的 playAndRecord 不带 mixWithOthers，会把正在放歌/放视频的 App 打断，
    /// ReplayKit 的 .audioApp 就什么都采不到。
    private func applyScreenShareAudioSession() {
        screenShareAudioSessionApplied = true
        let config = AudioSessionConfiguration(
            category: .playAndRecord,
            categoryOptions: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .allowAirPlay],
            mode: .videoChat
        )
        AudioManager.shared.sessionConfiguration = config
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(config.category, mode: config.mode, options: config.categoryOptions)
        try? session.setActive(true)
    }

    /// 停止共享后恢复 LiveKit 的动态音频会话配置，并去掉 mixWithOthers
    private func restoreScreenShareAudioSession() {
        guard screenShareAudioSessionApplied else { return }
        screenShareAudioSessionApplied = false
        AudioManager.shared.sessionConfiguration = nil
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(
            .playAndRecord,
            mode: .videoChat,
            options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .allowAirPlay]
        )
    }

    /// 屏幕采集单独拆出：iOS 回后台会停掉 RPScreenRecorder，重新开始时用同一个 BufferCapturer 重挂
    private func startScreenCapture(_ capturer: BufferCapturer) {
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

    /// 一键重新开始共享：只在 App 内采集时使用，旧采集器/轨道可能已经作废
    private func restartShare() async {
        guard isHost, usingInAppShare else { return }
        if sharing {
            RPScreenRecorder.shared().stopCapture { _ in }
            if let pub = screenPublication {
                try? await room.localParticipant.unpublish(publication: pub)
            }
            screenPublication = nil
            screenTrack = nil
            sharing = false
            // stopCapture 是异步收尾的，立刻 startCapture 会报「正在录制中」
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        await startInAppShare()
        if sharing { shareInterrupted = false }
    }

    private func stopShare() async {
        if usingBroadcastShare || BroadcastBridge.isFlaggedActive {
            broadcastPending = false
            BroadcastControl.requestStop()
            showTip("正在停止屏幕共享…")
            // 等扩展结束广播；即使通知丢了也要把本地轨道收掉
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await finishBroadcastShare()
            return
        }
        await stopInAppShare()
    }

    private func stopInAppShare() async {
        RPScreenRecorder.shared().stopCapture { _ in }
        if let pub = screenPublication {
            try? await room.localParticipant.unpublish(publication: pub)
        }
        screenPublication = nil
        screenTrack = nil
        sharing = false
        shareInterrupted = false
        usingInAppShare = false
        await notifyScreen(0)
        showTip("已停止共享")
    }

    /// 系统广播开始/结束（扩展通过 Darwin 通知同步过来）
    private func handleBroadcastState(_ active: Bool) async {
        guard isHost, phase == "room", !left, !closing else { return }
        if active {
            // 只有本应用扩展写过 App Group 标记才算（也能过滤残留/错配通知）
            guard BroadcastBridge.isFlaggedActive else { return }
            broadcastPending = false
            // 理论上不会同时存在，出现时先收掉 App 内采集
            if usingInAppShare {
                RPScreenRecorder.shared().stopCapture { _ in }
                if let pub = screenPublication {
                    try? await room.localParticipant.unpublish(publication: pub)
                }
                screenPublication = nil
                screenTrack = nil
            }
            usingBroadcastShare = true
            usingInAppShare = false
            sharing = true
            shareInterrupted = false
            BroadcastBridge.markStarted()
            applyScreenShareAudioSession()
            ScreenShareKeepAlive.shared.start()

            guard room.connectionState == .connected else {
                // App 在后台被挂起/回前台还没重连：不能反过来把正在跑的广播停掉，
                // 等 connectSfu 重连后远端视频轨会自己到达。
                guard usingBroadcastShare else { return }
                await notifyScreen(1)
                showTip("屏幕共享已开始，正在恢复媒体连接…")
                return
            }
            // 画面由扩展直接发布，等远端屏幕轨到达再通知观众
            for _ in 0..<40 {
                if kitObserver.remoteVideo != nil { break }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            guard !left, !closing, usingBroadcastShare else { return }
            await notifyScreen(1)
            if kitObserver.remoteVideo == nil {
                showTip("屏幕共享已开始，画面连接中…")
            } else if kitObserver.screenAudioActive {
                showTip("屏幕共享已开始（含系统声音），可切换到其他 App")
            } else {
                showTip("屏幕共享已开始（无系统声音），可切换到其他 App")
            }
            // 扩展音频可能因手动渲染失败而没有推上来：10 秒后仍没有就把“声音连接中”降级
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard !left, !closing, sharing, usingBroadcastShare,
                      !kitObserver.screenAudioActive else { return }
                broadcastAudioRequested = false
            }
            return
        }
        guard usingBroadcastShare, !BroadcastBridge.isFlaggedActive else { return }
        await finishBroadcastShare()
        showTip("屏幕共享已结束")
    }

    /// 停止系统广播后的收尾：扩展已自行断开，主 App 只清理状态与通知观众。
    private func finishBroadcastShare() async {
        let wasSharing = sharing || usingBroadcastShare
        if usingInAppShare {
            RPScreenRecorder.shared().stopCapture { _ in }
            if let pub = screenPublication {
                try? await room.localParticipant.unpublish(publication: pub)
            }
            usingInAppShare = false
        }
        screenPublication = nil
        screenTrack = nil
        sharing = false
        usingBroadcastShare = false
        broadcastPending = false
        shareInterrupted = false
        broadcastAudioRequested = false
        ScreenShareKeepAlive.shared.stop()
        restoreScreenShareAudioSession()
        BroadcastBridge.markStopped()
        BroadcastBridge.clearSession()
        if wasSharing { await notifyScreen(0) }
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
        kitObserver.detach()
        // 离开直播间时系统广播也必须停，否则扩展会一直采集
        if BroadcastBridge.isFlaggedActive || usingBroadcastShare {
            BroadcastControl.requestStop()
        }
        BroadcastBridge.markStopped()
        BroadcastBridge.clearSession()
        if sharing {
            if usingInAppShare {
                RPScreenRecorder.shared().stopCapture { _ in }
            }
            sharing = false
            await notifyScreen(0)
        }
        screenPublication = nil
        screenTrack = nil
        usingBroadcastShare = false
        usingInAppShare = false
        broadcastPending = false
        broadcastAudioRequested = false
        ScreenShareKeepAlive.shared.stop()
        restoreScreenShareAudioSession()
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
