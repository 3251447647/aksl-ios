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

/// 群通话（多人，LiveKit SFU）：加入 → 连媒体服务器 → 宫格 + 计时 + 底部操作
/// 结构对齐安卓 GroupCallScreen.kt
struct GroupCallView: View {
    let gid: Int64
    let callType: Int

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppState
    @StateObject private var room = Room()

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
            let uid = Int64(String(describing: p.identity)) ?? 0
            let m = members.first { $0.uid == uid }
            others.append(CallTileItem(uid: uid, name: m?.name ?? "成员",
                                       avatar: m?.avatar, participant: p, isLocal: false))
            if uid > 0 { seen.insert(uid) }
        }
        list.append(contentsOf: others)
        for m in members where !seen.contains(m.uid) {
            list.append(CallTileItem(uid: m.uid, name: m.name ?? "", avatar: m.avatar,
                                     participant: nil, isLocal: m.uid == myUid))
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
                    grid
                    if let tip {
                        Text(tip)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(.bottom, 6)
                    }
                    actions
                }
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
        .onDisappear {
            pollTask?.cancel()
            tickTask?.cancel()
            if !ended && !showInvite {
                ended = true
                Task { await APIClient.shared.groupCallLeave(gid: gid) }
                Task { await room.disconnect() }
            }
        }
    }

    // MARK: - 顶部

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(groupName.isEmpty ? (videoMode ? "群视频通话" : "群语音通话") : groupName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("\(max(tiles.count, 1)) 人 · \(clock(seconds))" + (videoMode ? " · 视频通话" : " · 语音通话"))
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.muted)
            }
            Spacer(minLength: 6)
            Button {
                Task { await leave() }
            } label: {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(AKColor.red)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    // MARK: - 宫格

    private var grid: some View {
        ScrollView {
            if videoMode {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2), spacing: 6) {
                    ForEach(tiles) { t in
                        videoTile(t)
                    }
                }
                .padding(.horizontal, 6)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 18) {
                    ForEach(tiles) { t in
                        audioTile(t)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func videoTile(_ t: CallTileItem) -> some View {
        let track = videoTrackOf(t)
        return ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tileBg)
            if let track {
                LiveKitVideoTile(track: track)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    AvatarView(url: t.avatar, name: t.name.isEmpty ? "成员" : t.name, size: 56)
                    Text(t.name.isEmpty ? "成员" : t.name)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            HStack(spacing: 4) {
                Text((t.isLocal ? "我 · " : "") + (t.name.isEmpty ? "成员" : t.name))
                    .font(.system(size: 10.5))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if t.isLocal && muted {
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
        .frame(height: 200)
    }

    private func audioTile(_ t: CallTileItem) -> some View {
        VStack(spacing: 8) {
            AvatarView(url: t.avatar, name: t.name.isEmpty ? "成员" : t.name, size: 72)
            Text(t.name.isEmpty ? "成员" : t.name)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func videoTrackOf(_ t: CallTileItem) -> VideoTrack? {
        if t.isLocal {
            guard camOn else { return nil }
            return room.localParticipant.videoTracks.compactMap { $0.track as? VideoTrack }.first
        }
        guard let p = t.participant else { return nil }
        for pub in p.videoTracks {
            if let track = pub.track as? VideoTrack { return track }
        }
        return nil
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
            }
            roundAction(
                icon: speaker ? "speaker.wave.2.fill" : "ear",
                label: speaker ? "外放" : "听筒",
                active: !speaker
            ) {
                speaker.toggle()
                setSpeaker(speaker)
            }
            Button {
                showInvite = true
            } label: {
                actionLabel(icon: "person.badge.plus", label: "邀请", active: false, danger: false)
            }
            .buttonStyle(.plain)

            roundAction(icon: "phone.down.fill", label: "离开", danger: true) {
                Task { await leave() }
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 10)
        .padding(.bottom, 18)
    }

    private func roundAction(icon: String, label: String, active: Bool = false, danger: Bool = false, action: @escaping () -> Void) -> some View {
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
                    .foregroundColor(danger || active ? .white : Color(hex: 0x12141A))
            }
            Text(label)
                .font(.system(size: 10.5))
                .foregroundColor(AKColor.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
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
        if callType == 2 && !camOn {
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
            try? await room.localParticipant.setMicrophone(enabled: true)
            if videoMode {
                try? await room.localParticipant.setCamera(enabled: true)
                camOn = true
            }
            startPolling()
            startTimer()
            await pollOnce()
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
            await room.disconnect()
            dismiss()
            return
        }
        if !st.members.isEmpty { members = st.members }
        if st.startTime > 0 { startTime = st.startTime }
        if st.serverTime > 0 {
            serverOffset = st.serverTime - Int64(Date().timeIntervalSince1970)
        }
        seconds = currentSeconds()
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
        await APIClient.shared.groupCallLeave(gid: gid)
        await room.disconnect()
        dismiss()
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
