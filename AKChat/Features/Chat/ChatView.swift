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

    private var myId: Int64 { app.user?.id ?? 0 }
    private var isGroup: Bool { convType == "group" }

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

            if let replyTo {
                replyBar(replyTo)
            }

            if let muteHint {
                mutedBar(muteHint)
            } else {
                inputBar
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
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
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
            AtMemberPicker(members: members, myRole: myRole) { uid, name in
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
            NavigationStack {
                ChatRecordSheet(payload: recordPayload ?? "")
            }
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
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
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
                active = try? await APIClient.shared.groupActive(gid: convId)
                groupInfo = try? await APIClient.shared.groupInfo(id: convId)
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
        let hints = readHints
        return ScrollViewReader { proxy in
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
                        row(msg, readHint: hints[msg.listKey] ?? 0)
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

    /// 被禁言时输入区置灰（对齐安卓 MutedComposerBar）
    private var muteHint: String? {
        guard isGroup, myRole != 1, myRole != 2 else { return nil }
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
        var list: [URL] = []
        var at = 0
        for m in messages where m.type == 5 && !isStickerMessage(m) {
            if let t = m.text, let u = APIClient.fullURL(VoiceService.cleanPath(t)) {
                if t == url { at = list.count }
                list.append(u)
            }
        }
        if list.isEmpty, let u = APIClient.fullURL(VoiceService.cleanPath(url)) {
            list = [u]
        }
        guard !list.isEmpty else { return }
        previewImage = PreviewImage(urls: list, index: min(at, list.count - 1))
    }

    private func openAlbum(_ paths: [String], index: Int) {
        let lower = paths.first?.lowercased() ?? ""
        if lower.hasSuffix(".mp4") || lower.hasSuffix(".mov") || lower.hasSuffix(".m4v") || lower.hasSuffix(".webm") {
            if let u = APIClient.fullURL(VoiceService.cleanPath(paths[min(index, paths.count - 1)])) {
                videoURL = u
                showVideo = true
            }
            return
        }
        let urls = paths.compactMap { APIClient.fullURL(VoiceService.cleanPath($0)) }
        guard !urls.isEmpty else { return }
        previewImage = PreviewImage(urls: urls, index: min(max(index, 0), urls.count - 1))
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
            readHint: readHint,
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
        .contextMenu {
            menuItems(msg)
        }
    }

    /// 长按菜单：顺序对齐安卓 ChatMenuSheet
    @ViewBuilder
    private func menuItems(_ msg: Message) -> some View {
        if msg.type == 5, !isStickerMessage(msg), let url = msg.text, !url.isEmpty {
            Button {
                openImagePager(url)
            } label: {
                Label("查看大图", systemImage: "photo")
            }
        }
        if msg.type != 11, msg.recalled == 0 {
            Button {
                replyTo = msg
                inputFocused = true
            } label: {
                Label("回复", systemImage: "arrowshape.turn.up.left")
            }
        }
        if let copy = copyText(msg) {
            Button {
                UIPasteboard.general.string = copy
                errorText = "已复制"
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }
        }
        if msg.id > 0, msg.type != 11, msg.recalled == 0 {
            Button {
                forwardMessages = [msg]
                showForward = true
            } label: {
                Label("转发", systemImage: "arrowshape.turn.up.right")
            }
        }
        if msg.type != 11, msg.recalled == 0 {
            Button {
                Task { await APIClient.shared.addFavorite(message: msg, convName: title) }
                errorText = "已收藏"
            } label: {
                Label("收藏", systemImage: "star")
            }
        }
        if canPin, msg.id > 0, msg.type != 11, msg.recalled == 0 {
            Button {
                Task { await togglePin(msg) }
            } label: {
                Label(pinMsgId == msg.id ? "取消置顶" : "置顶", systemImage: "pin")
            }
        }
        if msg.type == 5, msg.fromUid != myId, let url = msg.text, !url.isEmpty {
            Button {
                Task { await app.addEmoji(url: url) }
            } label: {
                Label("添加到表情", systemImage: "face.smiling")
            }
        }
        if msg.fromUid != myId, msg.type != 11 {
            Button(role: .destructive) {
                reportTarget = msg
            } label: {
                Label("举报", systemImage: "exclamationmark.bubble")
            }
        }
        if canRecall(msg) {
            Button(role: .destructive) {
                confirm = .recall(msg)
            } label: {
                Label(msg.fromUid == myId ? "撤回" : "撤回该消息", systemImage: "arrow.uturn.backward")
            }
        }
        Button(role: .destructive) {
            confirm = .delete(msg)
        } label: {
            Label("删除", systemImage: "trash")
        }
    }

    /* ---------------- 输入 ---------------- */

    /// 安卓式头部：返回箭头 + 标题（群靓徽章）+ 搜索/通话
    private var chatHeader: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AKColor.text)
                    .frame(width: 32, height: 32)
            }
            Spacer(minLength: 0)
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AKColor.text)
                    .lineLimit(1)
                if isGroup, let g = groupInfo, g.isPretty == 1, !g.displayNo.isEmpty {
                    PrettyBadge(number: g.displayNo, isGroup: true)
                }
            }
            Spacer(minLength: 0)
            NavigationLink {
                MessageSearchView(scopeType: convType, scopeId: convId, scopeTitle: title)
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17))
                    .foregroundColor(AKColor.text)
                    .frame(width: 32, height: 32)
            }
            if isGroup {
                Button {
                    showGroupInfo = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AKColor.text)
                        .frame(width: 32, height: 32)
                }
            } else {
                Menu {
                    Button("语音通话") { startCall(1) }
                    Button("视频通话") { startCall(2) }
                } label: {
                    Image(systemName: "phone")
                        .font(.system(size: 17))
                        .foregroundColor(AKColor.text)
                        .frame(width: 32, height: 32)
                }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 46)
        .background(AKColor.card)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AKColor.line).frame(height: 0.5)
        }
    }

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var placeholder: String {
        isGroup ? "发消息，@ 可提醒成员" : "发消息…"
    }

    private var inputBar: some View {
        HStack(spacing: 6) {
            Button {
                Task { await toggleRecord() }
            } label: {
                Image(systemName: voice.recording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 18))
                    .foregroundColor(voice.recording ? .white : AKColor.sub)
                    .frame(width: 36, height: 36)
                    .background(voice.recording ? AKColor.red : AKColor.fill)
                    .clipShape(Circle())
            }

            TextField(placeholder, text: $text, axis: .vertical)
                .focused($inputFocused)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .onChange(of: text) { value in
                    handleInputChange(value)
                }

            if isGroup {
                Button {
                    showAtPicker = true
                } label: {
                    Text("@")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AKColor.sub)
                        .frame(width: 32, height: 32)
                }
            }

            Button {
                showEmoji.toggle()
            } label: {
                Image(systemName: showEmoji ? "keyboard" : "face.smiling")
                    .font(.system(size: 21))
                    .foregroundColor(showEmoji ? AKColor.brand : AKColor.sub)
                    .frame(width: 36, height: 36)
            }

            if hasText {
                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(AKColor.brand)
                        .clipShape(Circle())
                }
                .disabled(sending)
            } else {
                Button {
                    showMore = true
                } label: {
                    Image(systemName: showMore ? "xmark" : "plus")
                        .font(.system(size: 22))
                        .foregroundColor(AKColor.sub)
                        .frame(width: 36, height: 36)
                }
                .sheet(isPresented: $showMore) {
                    MorePanel(
                        isGroup: isGroup,
                        onPhoto: { showMore = false; showPhotoPicker = true },
                        onCamera: {
                            showMore = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showCamera = true }
                        },
                        onRedPacket: { showMore = false; showRedPacket = true },
                        onTransfer: { showMore = false; showTransfer = true },
                        onGift: { showMore = false; showGift = true },
                        onVoiceCall: { showMore = false; startCall(1) },
                        onVideoCall: { showMore = false; startCall(2) },
                        onGroupCall: { type in
                            showMore = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                callType = type
                                showGroupCall = true
                            }
                        },
                        onGroupLive: {
                            showMore = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                liveGid = convId
                                showLive = true
                            }
                        }
                    )
                    .presentationDetents([.height(isGroup ? 320 : 300)])
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(AKColor.card)
        .onChange(of: photoItem) { item in
            guard let item else { return }
            Task { await sendPhoto(item) }
        }
    }

    private func handleInputChange(_ value: String) {
        if isGroup, value.last == "@", !members.isEmpty {
            showAtPicker = true
        }
        guard isGroup, !value.isEmpty, convId != myId else { return }
        let now = Date().timeIntervalSince1970
        if now - lastTypingSent > 2 {
            lastTypingSent = now
            Task { await APIClient.shared.sendTyping(convType: convType, convId: convId) }
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
                replaceLocal(local, with: saved)
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

    private func sendPhoto(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        await sendPhotoData(data)
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

    private func deleteLocal(_ msg: Message) {
        messages.removeAll { $0.listKey == msg.listKey }
        errorText = "已删除"
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
            if !atUids.contains(-1) { atUids.append(-1) }
            inputFocused = true
            return
        }
        if let member = members.first(where: { $0.uid == uid }) {
            let display = member.name ?? name
            text += "@\(display) "
            if !atUids.contains(uid) { atUids.append(uid) }
        }
        inputFocused = true
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
    let readHint: Int
    let playingVoice: Bool
    let onVoiceTap: () -> Void
    let onRetry: () -> Void
    let onAvatarTap: () -> Void
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

    /// 气泡最大宽度：屏宽 70%（对齐安卓 maxBubble 0.68 并取整）
    private var maxBubble: CGFloat { UIScreen.main.bounds.width * 0.70 }

    private var mentionHighlight: Color {
        if !mine, message.atMe == 1 || message.atAll == 1 {
            return AKColor.goldSoft.opacity(0.55)
        }
        return Color.clear
    }

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
            onOpenAlbum: onOpenAlbum
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
                        .onTapGesture { onAvatarTap() }
                    Spacer().frame(width: 7)
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
                            if let m = member, m.isPretty == 1 {
                                PrettyBadge(number: m.prettyNo ?? "")
                            }
                            if let m = member, m.vipLevel > 0 {
                                VipBadge(level: m.vipLevel)
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
                        .padding(.leading, 6)
                        .padding(.bottom, 5)
                    }

                    bodyView

                    HStack(spacing: 4) {
                        if message.status == 2 {
                            Button(action: onRetry) {
                                Text("发送失败，点击重发")
                                    .font(.system(size: 10))
                                    .foregroundColor(AKColor.red)
                            }
                            .buttonStyle(.plain)
                        } else if message.status == 0 {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 10, height: 10)
                        }
                        Text(ChatClock.clock(message.createdAt))
                            .font(.system(size: 10))
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
                } else {
                    Spacer(minLength: 44)
                }
            }
            .background(mentionHighlight)
        }
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
}

