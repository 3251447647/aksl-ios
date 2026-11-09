import SwiftUI
import LiveKit
import ReplayKit
import UIKit

/// 群直播间：顶部返回 + 标题（在线人数）/ 画面区 / 评论区 / 弹幕输入条 / 主播控制条
/// 结构与交互对齐安卓 GroupLiveScreen.kt + GroupLiveUi.kt
struct LiveRoomView: View {
    let gid: Int64

    @Environment(\.dismiss) private var dismiss
    @StateObject private var room = Room()

    @State private var phase = "loading"          // loading / prestart / room / blocked
    @State private var blockedMsg = ""
    @State private var liveId: Int64 = 0
    @State private var hostId: Int64 = 0
    @State private var hostName = ""
    @State private var hostAvatar: String?
    @State private var isHost = false
    @State private var liveTitle = ""
    @State private var viewers = 0
    @State private var comments: [LiveComment] = []
    @State private var lastCommentId: Int64 = 0
    @State private var commentText = ""
    @State private var tip: String?
    @State private var pollTask: Task<Void, Never>?

    @State private var groupName = ""
    @State private var startTitle = ""
    @State private var starting = false

    @State private var micOn = true
    @State private var camOn = false
    @State private var sharing = false
    @State private var screenTrack: LocalVideoTrack?
    @State private var screenPublication: LocalTrackPublication?
    @State private var connectError: String?

    @State private var confirmLeave = false
    @State private var confirmEnd = false
    @State private var closing = false

    private let bg = Color(hex: 0x0D0F14)
    private let panelBg = Color(hex: 0x14161B)
    private let white90 = Color.white.opacity(0.9)
    private let white60 = Color.white.opacity(0.6)
    private let white45 = Color.white.opacity(0.45)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            content
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .onDisappear {
            pollTask?.cancel()
            if !closing { Task { await teardown() } }
        }
        .confirmationDialog("离开直播间", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("离开直播间", role: .destructive) { Task { await leaveRoom() } }
            Button("取消", role: .cancel) {}
        } message: {
            Text(isHost ? "主播离开不会结束直播，可在群资料里重新进入" : "离开后可在群资料里重新进入直播间")
        }
        .confirmationDialog("结束直播", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("结束直播", role: .destructive) { Task { await endLive() } }
            Button("取消", role: .cancel) {}
        } message: {
            Text("结束后所有观众都会退出直播间，且不可恢复")
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
                stage(height: geo.size.height * 0.40)
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
                if isHost { hostBar }
            }
        }
    }

    private var topBar: some View {
        ZStack {
            VStack(spacing: 1) {
                Text(liveTitle.isEmpty ? (groupName.isEmpty ? "群直播" : groupName) : liveTitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AKColor.text)
                    .lineLimit(1)
                Text("\(viewers) 人在线")
                    .font(.system(size: 10.5))
                    .foregroundColor(AKColor.hint)
            }
            .padding(.horizontal, 68)

            HStack {
                Button {
                    confirmLeave = true
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
                    confirmLeave = true
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
                LiveStageTrackView(track: track)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 24))
                        .foregroundColor(white45)
                    Text(stageHint)
                        .font(.system(size: 12))
                        .foregroundColor(white60)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
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
                }
                Spacer()
                HStack {
                    Spacer()
                    HStack(spacing: 5) {
                        Circle().fill(Color(hex: 0xFF5B6B)).frame(width: 6, height: 6)
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
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }

    private var stageHint: String {
        if let connectError { return "连接媒体服务器失败：\(connectError)" }
        if isHost { return "点下方「共享」开始分享屏幕，观众即可看到画面" }
        return "主播暂未共享画面"
    }

    private var displayTrack: VideoTrack? {
        if isHost {
            if camOn, let local = room.localParticipant.videoTracks.compactMap({ $0.track as? VideoTrack }).first {
                return local
            }
            if let s = screenTrack { return s }
            return room.localParticipant.videoTracks.compactMap({ $0.track as? VideoTrack }).first
        }
        for participant in room.remoteParticipants.values {
            for pub in participant.videoTracks {
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
    private func commentRow(_ c: LiveComment) -> some View {
        if c.system == 1 {
            Text(c.content)
                .font(.system(size: 12.5))
                .foregroundColor(Color(hex: 0xFF9A3D))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
        } else {
            HStack(alignment: .top, spacing: 8) {
                AvatarView(url: c.avatar, name: c.nickname ?? "成员", size: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text((c.nickname ?? "").isEmpty ? "成员" : (c.nickname ?? "成员"))
                        .font(.system(size: 11))
                        .foregroundColor(white60)
                        .lineLimit(1)
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
                .foregroundColor(.white)
                .tint(AKColor.brand)
                .placeholder(when: commentText.isEmpty) {
                    Text("说点什么…")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: 0x8B9099))
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(Color.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button {
                Task { await sendComment() }
            } label: {
                Image(systemName: "send.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(AKColor.brand)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var hostBar: some View {
        HStack(spacing: 0) {
            toolItem(icon: micOn ? "mic.fill" : "mic.slash.fill",
                     label: micOn ? "麦克风" : "已静音",
                     active: micOn) {
                Task { await toggleMic() }
            }
            toolItem(icon: camOn ? "video.fill" : "video.slash.fill",
                     label: "摄像头",
                     active: camOn) {
                Task { await toggleCamera() }
            }
            toolItem(icon: sharing ? "stop.circle.fill" : "rectangle.on.rectangle",
                     label: sharing ? "停止共享" : "共享",
                     active: sharing) {
                Task { await toggleShare() }
            }
            toolItem(icon: "stop.circle", label: "结束直播", danger: true) {
                confirmEnd = true
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
    }

    private func toolItem(icon: String, label: String, active: Bool = false, danger: Bool = false, action: @escaping () -> Void) -> some View {
        let tint: Color = danger ? Color(hex: 0xFF5B6B) : (active ? AKColor.brand : white90)
        return Button(action: action) {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(active ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 17))
                        .foregroundColor(tint)
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
    }

    // MARK: - 开播前

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

    // MARK: - 已结束 / 不可进入

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
        phase = "loading"
        do {
            let data = try await APIClient.shared.liveRoom(gid: gid)
            if let info = try? await APIClient.shared.groupInfo(id: gid) {
                groupName = info.name ?? ""
                hostAvatar = info.avatar
            }
            if let live = data.live {
                await attach(live: live, sfu: data.sfu)
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

    private func attach(live: LiveInfo, sfu: SfuInfo?) async {
        liveId = live.id
        hostId = live.hostId
        hostName = live.hostName
        if let av = live.hostAvatar, !av.isEmpty { hostAvatar = av }
        isHost = live.myRole == 1
        viewers = live.viewers
        let t = live.title.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty && t != "群直播" { liveTitle = t } else { liveTitle = groupName }
        comments = []
        lastCommentId = 0
        phase = "room"
        startPolling()
        await connectSfu(sfu)
    }

    private func connectSfu(_ sfu: SfuInfo?) async {
        guard let sfu, sfu.enabled == 1, let url = sfu.url, let token = sfu.token,
              !url.isEmpty, !token.isEmpty, let u = URL(string: url) else {
            connectError = "媒体服务未启用"
            return
        }
        do {
            try await room.connect(url: u.absoluteString, token: token)
            connectError = nil
            if isHost {
                try? await room.localParticipant.setMicrophone(enabled: true)
                micOn = true
            }
        } catch {
            connectError = error.localizedDescription
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                if Task.isCancelled { break }
                await poll()
            }
        }
    }

    private func poll() async {
        guard liveId > 0, phase == "room" else { return }
        guard let data = try? await APIClient.shared.livePoll(gid: gid, liveId: liveId, lastCommentId: lastCommentId) else { return }
        if let v = data.viewers { viewers = v }
        if let list = data.comments, !list.isEmpty {
            comments.append(contentsOf: list)
            if comments.count > 120 { comments.removeFirst(comments.count - 120) }
        }
        if let maxId = data.maxCommentId, maxId > lastCommentId { lastCommentId = maxId }
        if data.active == 0 {
            blockedMsg = "直播已结束"
            phase = "blocked"
            await teardown()
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
            tip = error.localizedDescription
        }
    }

    private func startLive() async {
        let t = startTitle.trimmingCharacters(in: .whitespaces)
        guard t.count >= 2 else { tip = "直播标题需 2~30 个字"; return }
        starting = true
        defer { starting = false }
        do {
            let data = try await APIClient.shared.startLive(gid: gid, title: t)
            if let live = data.live {
                await attach(live: live, sfu: data.sfu)
            } else {
                blockedMsg = (data.msg ?? "").isEmpty ? "开播失败，请稍后重试" : (data.msg ?? "")
                phase = "blocked"
            }
        } catch {
            tip = error.localizedDescription
        }
    }

    // MARK: - 主播控制

    private func toggleMic() async {
        let next = !micOn
        do {
            try await room.localParticipant.setMicrophone(enabled: next)
            micOn = next
            tip = next ? nil : "麦克风已静音"
        } catch {
            tip = "切换麦克风失败：\(error.localizedDescription)"
        }
    }

    private func toggleCamera() async {
        let next = !camOn
        do {
            try await room.localParticipant.setCamera(enabled: next)
            camOn = next
        } catch {
            tip = "切换摄像头失败：\(error.localizedDescription)"
        }
    }

    private func toggleShare() async {
        if sharing {
            await stopShare()
        } else {
            await startShare()
        }
    }

    private func startShare() async {
        guard !sharing else { return }
        let track = await LocalVideoTrack.createBufferTrack(name: "screen")
        guard let capturer = track.capturer as? BufferCapturer else {
            tip = "当前设备不支持屏幕共享"
            return
        }
        screenTrack = track
        RPScreenRecorder.shared().startCapture { sample, type, _ in
            if type == .video { capturer.capture(sample) }
        } completionHandler: { err in
            if let err {
                Task { @MainActor in
                    self.tip = "屏幕采集失败：\(err.localizedDescription)"
                }
            }
        }
        do {
            let pub = try await room.localParticipant.publish(videoTrack: track)
            screenPublication = pub
            sharing = true
            await notifyScreen(1)
        } catch {
            RPScreenRecorder.shared().stopCapture { _ in }
            screenTrack = nil
            tip = "共享失败：\(error.localizedDescription)"
        }
    }

    private func stopShare() async {
        RPScreenRecorder.shared().stopCapture { _ in }
        if let pub = screenPublication {
            try? await room.localParticipant.unpublish(publication: pub)
        }
        screenPublication = nil
        screenTrack = nil
        sharing = false
        await notifyScreen(0)
    }

    private func notifyScreen(_ value: Int) async {
        guard liveId > 0 else { return }
        await APIClient.shared.postIgnore("api/v1/group/live/screen", body: [
            "id": gid, "live_id": liveId, "value": value
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
        pollTask?.cancel()
        if sharing {
            RPScreenRecorder.shared().stopCapture { _ in }
            sharing = false
            await notifyScreen(0)
        }
        screenPublication = nil
        screenTrack = nil
        await room.disconnect()
    }
}

/// LiveKit 视频渲染（画面区）
private struct LiveStageTrackView: UIViewRepresentable {
    let track: VideoTrack

    func makeUIView(context: Context) -> LiveKit.VideoView {
        let v = LiveKit.VideoView()
        v.track = track
        return v
    }

    func updateUIView(_ uiView: LiveKit.VideoView, context: Context) {
        uiView.track = track
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
