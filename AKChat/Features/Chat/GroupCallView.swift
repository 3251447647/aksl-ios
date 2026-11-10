import SwiftUI
import LiveKit
import AVFoundation

/// 群通话成员（/group/call/poll 的 members）
struct GroupCallMemberLite: Decodable, Identifiable {
    let uid: Int64
    let name: String?
    let avatar: String?

    var id: Int64 { uid }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uid = (try? c.decode(Int64.self, forKey: .uid)) ?? 0
        name = try? c.decode(String.self, forKey: .name)
        avatar = try? c.decode(String.self, forKey: .avatar)
    }

    enum CodingKeys: String, CodingKey { case uid, name, avatar }
}

/// /group/call/poll 返回（Core 里没有这个模型，页面内解码）
struct GroupCallStateLite: Decodable {
    let active: Int
    let callId: Int64
    let callType: Int
    let startTime: Int64
    let serverTime: Int64
    let members: [GroupCallMemberLite]

    enum CodingKeys: String, CodingKey {
        case active, members
        case callId = "call_id"
        case callType = "call_type"
        case startTime = "start_time"
        case serverTime = "server_time"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        active = (try? c.decode(Int.self, forKey: .active)) ?? 0
        callId = (try? c.decode(Int64.self, forKey: .callId)) ?? 0
        callType = (try? c.decode(Int.self, forKey: .callType)) ?? 2
        startTime = (try? c.decode(Int64.self, forKey: .startTime)) ?? 0
        serverTime = (try? c.decode(Int64.self, forKey: .serverTime)) ?? 0
        members = (try? c.decode([GroupCallMemberLite].self, forKey: .members)) ?? []
    }
}

/// 房间事件桥：把说话人变化与成员/轨道变化转成 SwiftUI 可观察信号。
/// 说话人高亮、静音标记和小窗选轨都靠它刷新。
final class GroupCallObserver: NSObject, ObservableObject, RoomDelegate {
    @Published private(set) var revision = 0
    /// 正在说话的成员 identity（服务端 token 的 identity 就是 uid 字符串）
    @Published private(set) var speakingIds: Set<String> = []

    private weak var room: Room?

    func attach(_ room: Room) {
        detach()
        self.room = room
        room.add(delegate: self)
        syncSpeakers()
    }

    func detach() {
        room?.remove(delegate: self)
        room = nil
        DispatchQueue.main.async {
            self.speakingIds = []
            self.revision &+= 1
        }
    }

    private func syncSpeakers() {
        let ids = Set((room?.activeSpeakers ?? []).compactMap { $0.identity?.stringValue })
        DispatchQueue.main.async { self.speakingIds = ids }
    }

    private func bump() {
        DispatchQueue.main.async { self.revision &+= 1 }
    }

    func room(_ room: Room, didUpdateSpeakingParticipants participants: [Participant]) {
        let ids = Set(participants.compactMap { $0.identity?.stringValue })
        DispatchQueue.main.async {
            self.speakingIds = ids
            self.revision &+= 1
        }
    }

    func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        bump()
    }

    func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        syncSpeakers()
        bump()
    }

    func room(_ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) {
        bump()
    }

    func room(_ room: Room, participant: RemoteParticipant, didUnsubscribeTrack publication: RemoteTrackPublication) {
        bump()
    }

    func room(_ room: Room, participant: Participant, didUpdateState state: ParticipantState) {
        bump()
    }

    func room(_ room: Room, didUpdateConnectionState connectionState: ConnectionState,
              from oldConnectionState: ConnectionState) {
        bump()
    }
}

/// 群通话（多人，LiveKit SFU）：加入 → 连媒体服务器 → 宫格 + 计时 + 底部操作
/// 结构对齐安卓 GroupCallScreen.kt；小窗对齐直播的 LivePiP。
struct GroupCallView: View {
    let gid: Int64
    let callType: Int

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppState
    @StateObject private var room = Room()
    @StateObject private var peer = GroupCallObserver()
    @StateObject private var pip = LivePiPController()

    @State private var groupName = ""
    @State private var videoMode = false
    @State private var muted = false
    @State private var camOn = false
    @State private var speaker = true
    @State private var callId: Int64 = 0
    @State private var startTime: Int64 = 0
    @State private var serverOffset: Int64 = 0
    @State private var members: [GroupCallMemberLite] = []
    @State private var connected = false
    @State private var joining = true
    @State private var tip: String?
    @State private var ended = false
    @State private var seconds = 0
    @State private var pollTask: Task<Void, Never>?
    @State private var tickTask: Task<Void, Never>?
    @State private var showInvite = false
    /// 画中画正在渲染的远端画面；成员/说话人变化时重新选轨
    @State private var pipTrack: VideoTrack?

    private let bg = Color(hex: 0x12141A)
    private let tileBg = Color(hex: 0x1F232C)

    private var myUid: Int64 { app.user?.id ?? 0 }
    private var myName: String { app.user?.nickname ?? "我" }
    private var myAvatar: String? { app.user?.avatar }

    private var tiles: [CallTileItem] {
        guard connected else {
            return members.map {
                CallTileItem(uid: $0.uid, name: $0.name ?? "", avatar: $0.avatar,
                             participant: nil, isLocal: $0.uid == myUid)
            }
        }
        var list: [CallTileItem] = [
            CallTileItem(uid: myUid, name: myName, avatar: myAvatar, participant: nil, isLocal: true)
        ]
        var seen: Set<Int64> = [myUid]
        var others: [CallTileItem] = []
        for p in room.remoteParticipants.values {
            let uid = Int64(p.identity?.stringValue ?? "") ?? 0
            let m = members.first { $0.uid == uid }
            others.append(CallTileItem(uid: uid, name: m?.name ?? p.name ?? "成员",
                                       avatar: m?.avatar, participant: p, isLocal: false))
            if uid > 0 { seen.insert(uid) }
        }
        list.append(contentsOf: others.sorted { $0.uid < $1.uid })
        // 已进通话但媒体还没连上的人，先用成员表占位，避免人数跳变
        for m in members where !seen.contains(m.uid) {
            list.append(CallTileItem(uid: m.uid, name: m.name ?? "", avatar: m.avatar,
                                     participant: nil, isLocal: m.uid == myUid))
        }
        return list
    }

    private var displayTiles: [CallTileItem] {
        let list = tiles
        if list.isEmpty {
            return [CallTileItem(uid: myUid, name: myName, avatar: myAvatar,
                                 participant: nil, isLocal: true)]
        }
        return list
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                if joining && !connected {
                    Spacer()
                    ProgressView().tint(.white)
                    Text(tip ?? "正在接入通话…")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.muted)
                        .padding(.top, 10)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                    Spacer()
                } else {
                    gridArea
                }
                // 接入中也保留底部操作，加入失败时还能挂断退出
                actions
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            videoMode = callType == 2
            await loadGroupName()
            await requestPermissionsThenJoin()
        }
        .sheet(isPresented: $showInvite) {
            NavigationStack {
                InviteMembersView(groupId: gid)
            }
        }
        .onChange(of: connected) { _ in
            refreshPiPTrack()
        }
        .onChange(of: videoMode) { _ in
            refreshPiPTrack()
        }
        .onChange(of: peer.revision) { _ in
            refreshPiPTrack()
        }
        .onDisappear {
            pollTask?.cancel()
            tickTask?.cancel()
            guard !showInvite else { return }
            pip.invalidate()
            peer.detach()
            if !ended {
                ended = true
                Task { await APIClient.shared.groupCallLeave(gid: gid) }
                Task { await room.disconnect() }
            }
        }
    }

    // MARK: - 顶部（群名 / 人数 / 计时 / 小窗）

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(groupName.isEmpty ? (videoMode ? "群视频通话" : "群语音通话") : groupName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("\(max(displayTiles.count, 1)) 人 · \(clock(seconds))"
                     + (videoMode ? " · 视频通话" : " · 语音通话"))
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.muted)
            }
            Spacer(minLength: 6)
            if pip.isSupported && videoMode {
                Button {
                    togglePiP()
                } label: {
                    Image(systemName: pip.isActive ? "pip.exit" : "pip.enter")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(bg)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.92))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    // MARK: - 宫格

    private var gridArea: some View {
        ZStack(alignment: .bottom) {
            if videoMode {
                videoGrid
            } else {
                audioGrid
            }
            if let tip {
                Text(tip)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var videoGrid: some View {
        let list = displayTiles
        let cols = list.count <= 2 ? 1 : (list.count <= 4 ? 2 : 3)
        let rows = chunk(list, cols)
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(row) { t in
                        videoTile(t)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(3)
                    }
                    ForEach(Array(0..<(cols - row.count)), id: \.self) { _ in
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(3)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private var audioGrid: some View {
        let rows = chunk(displayTiles, 3)
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(row) { t in
                        audioTile(t)
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(Array(0..<(3 - row.count)), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 14)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    private func videoTile(_ t: CallTileItem) -> some View {
        let track = videoTrackOf(t)
        let speaking = isSpeaking(t)
        let micMuted = isMicMuted(t)
        return ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tileBg)
            if let track {
                // 画中画的渲染层必须挂在视图层级里；放在 LiveKit 画面下方不重复可见
                if pip.isSupported, let pipTrack, pipTrack === track {
                    PiPDisplayView(displayLayer: pip.renderer.displayLayer)
                        .onAppear { pip.prepare() }
                }
                LiveKitVideoTile(track: track)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    AvatarView(url: t.avatar, name: displayName(t), size: 56)
                    Text(displayName(t))
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            namePill(t, micMuted: micMuted)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AKColor.brand, lineWidth: speaking ? 2 : 0)
        )
    }

    private func audioTile(_ t: CallTileItem) -> some View {
        let speaking = isSpeaking(t)
        let micMuted = isMicMuted(t)
        return VStack(spacing: 8) {
            ZStack {
                if speaking {
                    Circle()
                        .fill(AKColor.brand.opacity(0.2))
                        .frame(width: 84, height: 84)
                }
                AvatarView(url: t.avatar, name: displayName(t), size: 72)
                    .clipShape(Circle())
                    .scaleEffect(speaking ? 1.08 : 1)
                    .animation(.easeOut(duration: 0.18), value: speaking)
                if micMuted {
                    ZStack {
                        Circle()
                            .fill(Color(hex: 0x3A3F4B))
                            .frame(width: 20, height: 20)
                        Image(systemName: "mic.slash.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: 0xFF8A8A))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(6)
                }
            }
            .frame(width: 84, height: 84)
            Text(displayName(t))
                .font(.system(size: 12))
                .foregroundColor(speaking ? AKColor.brand : .white)
                .lineLimit(1)
                .multilineTextAlignment(.center)
        }
    }

    private func namePill(_ t: CallTileItem, micMuted: Bool) -> some View {
        HStack(spacing: 4) {
            Text((t.isLocal ? "我 · " : "") + displayName(t))
                .font(.system(size: 10.5))
                .foregroundColor(.white)
                .lineLimit(1)
            if micMuted {
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: 0xFF8A8A))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(8)
    }

    private func displayName(_ t: CallTileItem) -> String {
        t.name.isEmpty ? "成员" : t.name
    }

    private func isSpeaking(_ t: CallTileItem) -> Bool {
        t.uid > 0 && peer.speakingIds.contains("\(t.uid)")
    }

    private func videoTrackOf(_ t: CallTileItem) -> VideoTrack? {
        if t.isLocal {
            guard camOn else { return nil }
            for pub in room.localParticipant.videoTracks where pub.source == .camera {
                if let track = pub.track as? VideoTrack { return track }
            }
            return nil
        }
        guard let p = t.participant else { return nil }
        for pub in p.videoTracks where pub.source == .camera {
            guard !pub.isMuted, let track = pub.track as? VideoTrack else { continue }
            return track
        }
        return nil
    }

    private func isMicMuted(_ t: CallTileItem) -> Bool {
        if t.isLocal { return muted }
        guard let p = t.participant else { return false }
        guard let pub = p.audioTracks.first(where: { $0.source == .microphone }) else { return true }
        return pub.isMuted
    }

    // MARK: - 画中画

    private func togglePiP() {
        if pip.isActive {
            pip.stop()
            return
        }
        refreshPiPTrack()
        guard pipTrack != nil else {
            tip = "还没有成员开启摄像头，暂时无法小窗"
            return
        }
        pip.start { ok in
            if !ok { tip = pip.lastError ?? "画中画暂不可用，请稍后再试" }
        }
    }

    /// 选一轨远端画面送进画中画：优先说话人，其次其他成员；当前轨还有效就不换，避免小窗反复重挂
    private func refreshPiPTrack() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.refreshPiPTrack() }
            return
        }
        guard connected, videoMode else {
            if pipTrack != nil { applyPiPTrack(nil) }
            return
        }
        let candidates = pipCandidates()
        if let current = pipTrack, candidates.contains(where: { $0 === current }) {
            return
        }
        applyPiPTrack(candidates.first)
    }

    private func applyPiPTrack(_ track: VideoTrack?) {
        pipTrack = track
        pip.sync(track: track)
    }

    private func pipCandidates() -> [VideoTrack] {
        var speaking: [VideoTrack] = []
        var others: [VideoTrack] = []
        let remotes = room.remoteParticipants.values.sorted {
            ($0.identity?.stringValue ?? "") < ($1.identity?.stringValue ?? "")
        }
        for p in remotes {
            guard let pub = p.videoTracks.first(where: { $0.source == .camera }), !pub.isMuted,
                  let track = pub.track as? VideoTrack else { continue }
            if peer.speakingIds.contains(p.identity?.stringValue ?? "") {
                speaking.append(track)
            } else {
                others.append(track)
            }
        }
        return speaking + others
    }

    // MARK: - 底部操作

    private var actions: some View {
        HStack(spacing: 0) {
            roundAction(
                icon: muted ? "mic.slash.fill" : "mic.fill",
                label: muted ? "已静音" : "静音",
                active: muted
            ) {
                muted.toggle()
                Task { try? await room.localParticipant.setMicrophone(enabled: !muted) }
            }
            if videoMode {
                roundAction(
                    icon: camOn ? "video.fill" : "video.slash.fill",
                    label: camOn ? "关摄像头" : "开摄像头",
                    active: !camOn
                ) {
                    camOn.toggle()
                    Task { try? await room.localParticipant.setCamera(enabled: camOn) }
                }
                roundAction(icon: "arrow.triangle.2.circlepath.camera", label: "翻转") {
                    flipCamera()
                }
            }
            roundAction(
                icon: speaker ? "speaker.wave.2.fill" : "ear",
                label: speaker ? "外放" : "听筒",
                active: !speaker
            ) {
                speaker.toggle()
                setSpeaker(speaker)
            }
            roundAction(icon: "person.badge.plus", label: "邀请") {
                showInvite = true
            }
            roundAction(icon: "phone.down.fill", label: "离开", danger: true) {
                Task { await leave() }
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 10)
        .padding(.bottom, 18)
    }

    private func roundAction(icon: String, label: String, active: Bool = false,
                             danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            actionLabel(icon: icon, label: label, active: active, danger: danger)
        }
        .buttonStyle(.plain)
    }

    private func actionLabel(icon: String, label: String, active: Bool, danger: Bool) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(danger ? AKColor.red : (active ? Color(hex: 0x2A2F3A) : Color.white.opacity(0.92)))
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(.system(size: 19))
                    .foregroundColor(danger || active ? .white : bg)
            }
            Text(label)
                .font(.system(size: 10.5))
                .foregroundColor(AKColor.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func flipCamera() {
        for pub in room.localParticipant.videoTracks where pub.source == .camera {
            guard let track = pub.track as? LocalVideoTrack,
                  let capturer = track.capturer as? CameraCapturer else { continue }
            Task { _ = try? await capturer.switchCameraPosition() }
            return
        }
        tip = "摄像头未开启，无法翻转"
    }

    // MARK: - 数据

    private func loadGroupName() async {
        if let info = try? await APIClient.shared.groupInfo(id: gid) {
            groupName = info.name ?? ""
        }
    }

    private func requestPermissionsThenJoin() async {
        let micOk = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioSession.sharedInstance().requestRecordPermission { ok in cont.resume(returning: ok) }
        }
        guard micOk else {
            joining = false
            tip = "缺少麦克风权限，无法通话"
            return
        }
        if callType == 2 {
            let camOk = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                AVCaptureDevice.requestAccess(for: .video) { ok in cont.resume(returning: ok) }
            }
            if !camOk {
                joining = false
                tip = "缺少相机权限，请到系统设置里开启"
                return
            }
        }
        await join()
    }

    private func join() async {
        do {
            let resp = try await APIClient.shared.groupCallJoin(gid: gid, callType: callType)
            callId = resp.callId ?? 0
            videoMode = (resp.callType ?? callType) == 2
            guard let sfu = resp.sfu, sfu.enabled == 1, let url = sfu.url, let token = sfu.token,
                  !url.isEmpty, !token.isEmpty, let u = URL(string: url) else {
                joining = false
                tip = "媒体服务暂不可用，请稍后重试"
                return
            }
            setSpeaker(true)
            try await room.connect(url: u.absoluteString, token: token)
            connected = true
            joining = false
            peer.attach(room)
            // 与安卓一致：进通话默认只开麦，摄像头由用户手动打开
            try? await room.localParticipant.setMicrophone(enabled: true)
            startPolling()
            startTimer()
            await pollOnce()
            refreshPiPTrack()
        } catch {
            joining = false
            tip = "加入通话失败：\(error.localizedDescription)"
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled && !ended {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if Task.isCancelled { break }
                await pollOnce()
            }
        }
    }

    private func startTimer() {
        tickTask?.cancel()
        tickTask = Task {
            while !Task.isCancelled && !ended {
                seconds = currentSeconds()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func pollOnce() async {
        guard callId > 0, !ended else { return }
        let state: GroupCallStateLite? = try? await APIClient.shared.get(
            "api/v1/group/call/poll", query: ["id": "\(gid)", "call_id": "\(callId)"]
        )
        guard let st = state else { return }
        if st.active != 1 {
            ended = true
            pollTask?.cancel()
            tickTask?.cancel()
            pip.invalidate()
            peer.detach()
            await room.disconnect()
            dismiss()
            return
        }
        if !st.members.isEmpty, st.members.map({ $0.uid }) != members.map({ $0.uid }) {
            members = st.members
        }
        if st.startTime > 0 { startTime = st.startTime }
        if st.serverTime > 0 {
            serverOffset = st.serverTime - Int64(Date().timeIntervalSince1970)
        }
        seconds = currentSeconds()
        // 兜底：远端关摄像头/退订不一定有事件，每轮轮询重新挑一次小窗画面
        refreshPiPTrack()
    }

    private func currentSeconds() -> Int {
        guard startTime > 0 else { return 0 }
        let now = Int64(Date().timeIntervalSince1970) + serverOffset
        return max(Int(now - startTime), 0)
    }

    private func clock(_ sec: Int) -> String {
        String(format: "%02d:%02d", sec / 60, sec % 60)
    }

    private func setSpeaker(_ on: Bool) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try? session.overrideOutputAudioPort(on ? .speaker : .none)
        try? session.setActive(true)
    }

    private func leave() async {
        guard !ended else { return }
        ended = true
        pollTask?.cancel()
        tickTask?.cancel()
        // 退房先收掉画中画，避免悬浮窗停在最后一帧
        pip.invalidate()
        peer.detach()
        await APIClient.shared.groupCallLeave(gid: gid)
        await room.disconnect()
        dismiss()
    }

    private func chunk(_ list: [CallTileItem], _ size: Int) -> [[CallTileItem]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: list.count, by: size).map {
            Array(list[$0..<min($0 + size, list.count)])
        }
    }
}

private struct CallTileItem: Identifiable {
    let uid: Int64
    let name: String
    let avatar: String?
    let participant: RemoteParticipant?
    let isLocal: Bool

    var id: String { "\(uid)-\(isLocal)" }
}
