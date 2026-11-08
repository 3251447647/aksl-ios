import SwiftUI
import PhotosUI
import Combine
import UIKit

struct ProfileTarget: Identifiable {
    let id: Int64
}

struct ChatView: View {
    @EnvironmentObject private var app: AppState

    let convType: String
    let convId: Int64
    let title: String

    @State private var messages: [Message] = []
    @State private var text = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var showEmoji = false
    @StateObject private var voice = VoiceService()
    @State private var sending = false
    @State private var loading = false
    @State private var loadingMore = false
    @State private var hasMore = false
    @State private var errorText: String?
    @State private var showGroupInfo = false
    @State private var reportTarget: Message?
    @State private var reportReason = ""
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
    @State private var previewGroupId: Int64 = 0
    @State private var showGroupPreview = false
    @State private var showCall = false

    private var myId: Int64 { app.user?.id ?? 0 }
    private var isGroup: Bool { convType == "group" }

    var body: some View {
        VStack(spacing: 0) {
            if let pinText {
                pinBar(pinText)
            }
            messageList

            if let typingName {
                HStack {
                    Text("\(typingName) 正在输入…")
                        .font(.system(size: 11))
                        .foregroundColor(AKColor.muted)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 2)
            }

            if let errorText {
                Text(errorText)
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 2)
            }

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

            if showEmoji {
                emojiPanel
            }

            inputBar
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
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    MessageSearchView(scopeType: convType, scopeId: convId, scopeTitle: title)
                } label: {
                    Image(systemName: "magnifyingglass").foregroundColor(AKColor.text)
                }
            }
            if !isGroup {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            startCall(1)
                        } label: {
                            Label("语音通话", systemImage: "phone")
                        }
                        Button {
                            startCall(2)
                        } label: {
                            Label("视频通话", systemImage: "video")
                        }
                    } label: {
                        Image(systemName: "phone").foregroundColor(AKColor.text)
                    }
                }
            }
            if isGroup {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showGroupInfo = true
                    } label: {
                        Image(systemName: "ellipsis.circle").foregroundColor(AKColor.text)
                    }
                }
            }
        }
        .sheet(isPresented: $showGroupInfo) {
            NavigationStack {
                GroupInfoView(groupId: convId)
            }
        }
        .sheet(isPresented: $showAtPicker) {
            AtMemberPicker(members: members) { uid, name in
                appendAt(uid: uid, name: name)
            }
        }
        .overlay {
            if showNotice {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea()
                        .onTapGesture { }
                    GroupNoticePopup(notice: pendingNotice) {
                        showNotice = false
                        if let n = pendingNotice {
                            Task { await APIClient.shared.ackGroupNotice(gid: convId, noticeId: n.id) }
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .fullScreenCover(item: $previewImage) { item in
            MediaPagerView(urls: item.urls, index: item.index)
        }
        .sheet(item: $profileTarget) { target in
            NavigationStack {
                UserProfileView(uid: target.id)
            }
        }
        .sheet(isPresented: $showForward) {
            ForwardPickerView(messages: forwardMessages)
        }
        .alert("举报该消息", isPresented: Binding(
            get: { reportTarget != nil },
            set: { if !$0 { reportTarget = nil } }
        )) {
            TextField("补充说明（选填）", text: $reportReason)
            Button("取消", role: .cancel) { reportTarget = nil }
            Button("提交举报", role: .destructive) {
                if let msg = reportTarget {
                    Task {
                        await APIClient.shared.reportMessage(
                            convType: convType,
                            msgId: msg.id,
                            reason: "用户举报",
                            content: reportReason
                        )
                        errorText = "举报已提交"
                    }
                }
                reportTarget = nil
            }
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
        .task {
            /* 先用本地缓存立刻上背景（不等网络），再用服务端结果校正 */
            chatBg = cachedBg()
            if let r = try? await APIClient.shared.chatBg(convType: convType, convId: convId) {
                chatBg = r.bg
                storeBg(r.bg)
            }
            await load()
            await app.loadEmojis()
            await loadPin()
            if isGroup {
                await loadMembers()
                await loadPendingNotice()
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
    }

    /* ---------------- 列表 ---------------- */

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if loading {
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
                    ForEach(Array(messages.enumerated()), id: \.element.listKey) { index, msg in
                        let prev = index > 0 ? messages[index - 1].createdAt : 0
                        if let stamp = TimeText.divider(previous: prev, current: msg.createdAt) {
                            Text(stamp)
                                .font(.system(size: 11))
                                .foregroundColor(AKColor.hint)
                                .padding(.vertical, 4)
                        }
                        row(msg)
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
            return (members.first { $0.uid == myId }?.role ?? 0) == 1 || (members.first { $0.uid == myId }?.role ?? 0) == 2
        }
        return true
    }

    @ViewBuilder
    private func row(_ msg: Message) -> some View {
        ChatMessageRow(
            message: msg,
            mine: msg.fromUid == myId,
            isGroup: isGroup,
            member: members.first { $0.uid == msg.fromUid },
            myAvatar: app.user?.avatar,
            playingVoice: voice.playingURL == VoiceService.cleanPath(msg.text ?? msg.content ?? ""),
            onVoiceTap: {
                voice.play(path: VoiceService.cleanPath(msg.text ?? msg.content ?? ""))
            },
            onRetry: {
                Task { await resend(msg) }
            },
            onAvatarTap: {
                if msg.fromUid != myId { profileTarget = ProfileTarget(id: msg.fromUid) }
            },
            onOpenLive: { gid in
                liveGid = gid
                showLive = true
            },
            onOpenGroup: { gid in
                previewGroupId = gid
                showGroupPreview = true
            }
        )
        .contentShape(Rectangle())
        .contextMenu {
            if msg.type == 5, let url = msg.text, !url.isEmpty {
                Button {
                    if let u = APIClient.fullURL(VoiceService.cleanPath(url)) {
                        var list: [URL] = []
                        var at = 0
                        for m in messages where m.type == 5 {
                            if let t = m.text, let mu = APIClient.fullURL(VoiceService.cleanPath(t)) {
                                if t == url { at = list.count }
                                list.append(mu)
                            }
                        }
                        if list.isEmpty { list = [u] }
                        previewImage = PreviewImage(urls: list, index: at)
                    }
                } label: {
                    Label("查看大图", systemImage: "photo")
                }
            }
            if msg.type == 1, let t = msg.text, !t.isEmpty {
                Button {
                    UIPasteboard.general.string = t
                    errorText = "已复制"
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                }
            }
            Button {
                Task { await APIClient.shared.addFavorite(message: msg, convName: title) }
                errorText = "已收藏"
            } label: {
                Label("收藏", systemImage: "star")
            }
            if msg.id > 0 && msg.type != 11 {
                Button {
                    forwardMessages = [msg]
                    showForward = true
                } label: {
                    Label("转发", systemImage: "arrowshape.turn.up.right")
                }
            }
            if msg.id > 0 && msg.type != 11 && canPin {
                Button {
                    Task { await togglePin(msg) }
                } label: {
                    Label(pinMsgId == msg.id ? "取消置顶" : "置顶", systemImage: "pin")
                }
            }
            if msg.type == 5, let url = msg.text, !url.isEmpty {
                Button {
                    Task { await app.addEmoji(url: url) }
                } label: {
                    Label("添加到表情", systemImage: "face.smiling")
                }
            }
            if msg.fromUid == myId, msg.id > 0, msg.recalled == 0, msg.type != 11 {
                Button(role: .destructive) {
                    Task { await recall(msg) }
                } label: {
                    Label("撤回", systemImage: "arrow.uturn.backward")
                }
            }
            if msg.fromUid != myId, msg.type != 11 {
                Button(role: .destructive) {
                    reportReason = ""
                    reportTarget = msg
                } label: {
                    Label("举报", systemImage: "exclamationmark.bubble")
                }
            }
        }
    }

    /* ---------------- 输入 ---------------- */

    private var inputBar: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 22))
                    .foregroundColor(AKColor.sub)
            }
            Button {
                showEmoji.toggle()
            } label: {
                Image(systemName: showEmoji ? "keyboard" : "face.smiling")
                    .font(.system(size: 22))
                    .foregroundColor(showEmoji ? AKColor.brand : AKColor.sub)
            }
            TextField(isGroup ? "发消息，@ 可提醒成员" : "发消息…", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .onChange(of: text) { value in
                    if isGroup && !value.isEmpty {
                        Task { await APIClient.shared.sendTyping(convType: convType, convId: convId) }
                    }
                }

            if isGroup {
                Button {
                    showAtPicker = true
                } label: {
                    Text("@")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AKColor.sub)
                }
            }

            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    Task { await toggleRecord() }
                } label: {
                    Image(systemName: voice.recording ? "stop.circle.fill" : "mic.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(voice.recording ? AKColor.red : AKColor.brand)
                        .clipShape(Circle())
                }
            }
            Button {
                Task { await send() }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AKColor.placeholder : AKColor.brand)
                    .clipShape(Circle())
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AKColor.card)
        .onChange(of: photoItem) { item in
            guard let item else { return }
            Task { await sendPhoto(item) }
        }
    }

    private var emojiPanel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if app.emojis.isEmpty {
                    Text("还没有收藏表情，长按图片可添加")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.muted)
                        .padding(.vertical, 18)
                } else {
                    ForEach(app.emojis) { emoji in
                        Button {
                            Task { await sendSticker(emoji.url) }
                        } label: {
                            AsyncImage(url: APIClient.fullURL(emoji.url)) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFit()
                                } else {
                                    Color.clear
                                }
                            }
                            .frame(width: 62, height: 62)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(height: 86)
        .background(AKColor.card)
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
            let pin = try? await APIClient.shared.pinInfo(peer: convId)
            pinText = pin?.digest
            pinMsgId = pin?.msgId ?? 0
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
        text = ""
        atUids = []
        errorText = nil
        let local = makeLocal(type: 1, content: content)
        messages.append(local)
        sending = true
        defer { sending = false }
        do {
            let saved = try await app.sendText(convType: convType, convId: convId, text: content, atUids: at)
            replaceLocal(local, with: saved)
        } catch {
            failLocal(local, "发送失败：\(error.localizedDescription)")
        }
    }

    private func resend(_ msg: Message) async {
        guard let idx = messages.firstIndex(where: { $0.localId == msg.localId }) else { return }
        messages[idx].status = 0
        errorText = nil
        do {
            let saved = try await app.sendText(convType: convType, convId: convId, text: msg.content ?? msg.text ?? "")
            replaceLocal(messages[idx], with: saved)
        } catch {
            failLocal(messages[idx], "发送失败：\(error.localizedDescription)")
        }
    }

    private func sendPhoto(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard !sending else { return }
        sending = true
        defer { sending = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
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

    private func toggleRecord() async {
        if voice.recording {
            guard let (url, seconds) = voice.stopRecording() else { return }
            sending = true
            defer { sending = false }
            do {
                let local = makeLocal(type: 6, content: "")
                messages.append(local)
                let uploaded = try await app.uploadVoice(fileURL: url)
                let saved = try await app.sendVoice(convType: convType, convId: convId, url: uploaded.url, seconds: seconds)
                replaceLocal(local, with: saved)
            } catch {
                errorText = "语音发送失败：\(error.localizedDescription)"
            }
        } else {
            let ok = await voice.startRecording()
            if !ok { errorText = "未授权麦克风，无法录音" }
        }
    }

    /* ---------------- 操作 ---------------- */

    private func recall(_ msg: Message) async {
        guard msg.id > 0 else { return }
        do {
            try await app.recall(convType: convType, id: msg.id)
            if let idx = messages.firstIndex(where: { $0.id == msg.id }) {
                messages[idx].type = 11
                messages[idx].text = "你撤回了一条消息"
                messages[idx].recalled = 1
            }
        } catch {
            errorText = "撤回失败：\(error.localizedDescription)"
        }
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
            await APIClient.shared.setPin(peer: convId, msgId: 0)
        }
        await loadPin()
    }

    private func appendAt(uid: Int64, name: String) {
        if uid == -1 {
            text += "@全体成员 "
            atUids.append(-1)
            return
        }
        if let member = members.first(where: { $0.uid == uid }) {
            let display = member.name ?? name
            text += "@\(display) "
            if !atUids.contains(uid) { atUids.append(uid) }
        }
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
    let playingVoice: Bool
    let onVoiceTap: () -> Void
    let onRetry: () -> Void
    let onAvatarTap: () -> Void
    var onOpenLive: (Int64) -> Void = { _ in }
    var onOpenGroup: (Int64) -> Void = { _ in }

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

    var body: some View {
        if message.type == 11 || message.recalled == 1 {
            HStack {
                Spacer(minLength: 36)
                MessageBody(message: message, mine: false)
                Spacer(minLength: 36)
            }
        } else {
            HStack(alignment: .top, spacing: 8) {
                if mine { Spacer(minLength: 44) }
                if !mine {
                    AvatarView(url: message.fromAvatar, name: displayName, size: 34)
                        .onTapGesture { onAvatarTap() }
                }
                VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
                    if !mine && isGroup {
                        HStack(spacing: 3) {
                            Text(displayName)
                                .font(.system(size: 11))
                                .foregroundColor(nameColor)
                                .lineLimit(1)
                            if let role = member?.role, role == 1 || role == 2 {
                                RoleBadge(role: role)
                            }
                            if let m = member, m.vipLevel > 0 {
                                VipBadge(level: m.vipLevel)
                            }
                            if let m = member, m.isPretty == 1 {
                                PrettyBadge(number: m.prettyNo ?? "")
                            }
                            if message.atMe == 1 || message.atAll == 1 {
                                Text("@我")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(AKColor.red)
                                    .padding(.horizontal, 3)
                                    .background(AKColor.redSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
                    }
                    MessageBody(
                        message: message,
                        mine: mine,
                        playingVoice: playingVoice,
                        onVoiceTap: onVoiceTap,
                        onOpenLive: onOpenLive,
                        onOpenGroup: onOpenGroup
                    )
                    if mine && message.isRead == 1 && message.type != 11 {
                        Text("已读")
                            .font(.system(size: 10))
                            .foregroundColor(AKColor.hint)
                    }
                    if mine && message.status == 2 {
                        Button(action: onRetry) {
                            HStack(spacing: 3) {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text("发送失败，点击重试")
                            }
                            .font(.system(size: 10))
                            .foregroundColor(AKColor.red)
                        }
                    }
                }
                if !mine { Spacer(minLength: 44) }
                if mine {
                    AvatarView(url: myAvatar, name: "我", size: 34)
                }            }
        }
    }
}

/* ---------------- 辅助页面 ---------------- */

private struct AtMemberPicker: View {
    let members: [GroupMember]
    let onPick: (Int64, String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button {
                    onPick(-1, "全体成员")
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "megaphone.fill")
                            .foregroundColor(AKColor.gold)
                        Text("全体成员").foregroundColor(AKColor.text)
                    }
                }
                ForEach(members) { member in
                    Button {
                        onPick(member.uid, member.name ?? "")
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            AvatarView(url: member.avatar, name: member.name ?? "成员", size: 32)
                            Text(member.name ?? "成员").foregroundColor(AKColor.text)
                            if member.role == 1 {
                                Text("群主").font(.system(size: 9)).foregroundColor(AKColor.red)
                            } else if member.role == 2 {
                                Text("管理员").font(.system(size: 9)).foregroundColor(AKColor.link)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("提醒谁")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

private struct GroupNoticePopup: View {
    let notice: GroupNotice?
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "megaphone.fill").foregroundColor(AKColor.gold)
                Text("群公告").font(.system(size: 16, weight: .semibold)).foregroundColor(AKColor.text)
                Spacer()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(notice?.content ?? "")
                        .font(.system(size: 14))
                        .foregroundColor(AKColor.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let imgs = notice?.imageList, !imgs.isEmpty {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                            ForEach(imgs, id: \.self) { path in
                                AsyncImage(url: APIClient.fullURL(path)) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        AKColor.fill
                                    }
                                }
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
            Button(action: onClose) {
                Text("我已知晓")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AKColor.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
        .padding(18)
        .frame(maxWidth: 340)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 24)
    }
}

