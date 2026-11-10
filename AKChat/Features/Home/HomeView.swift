import SwiftUI

struct ScanTarget: Identifiable {
    let id: Int64
}

struct IncomingCall: Identifiable {
    let id: Int64
    let callerId: Int64
    let name: String
    let avatar: String?
    let callType: Int
}

/// 首页：与安卓 ConvListScreen 同一套布局——自绘顶栏（AK商聊 + 未读数 + 深色加号弹窗）、
/// 搜索条、通讯录通知条、会话行（44 头像 / 右侧时间与未读窄列 / 置顶底色 / @我）。
struct HomeView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.colorScheme) private var scheme
    @Environment(\.tabBarVisibility) private var tabBar
    @State private var showCreateGroup = false
    @State private var showAddFriend = false
    @State private var showSearch = false
    @State private var showScanner = false
    @State private var showRequests = false
    @State private var showGroupInvites = false
    @State private var scanTarget: ScanTarget?
    @State private var plusOpen = false
    @State private var noticePopup: Notice?
    @State private var noticeDetail: NoticeDetail?
    @State private var showNoticeDetail = false
    @State private var noticeSeen: Set<Int64> = []
    /// 公告弹窗是悬浮层，弹出时借 tab 栏的深度计数把它盖住
    @State private var noticeOverlayPage = UUID()

    private static let noticeDismissKey = "platformNoticeDismissedIds"

    private var filtered: [Conversation] { app.conversations }
    /// 顶栏角标只算非免打扰会话
    private var unreadBadge: Int {
        app.conversations.filter { $0.isMute != 1 }.reduce(0) { $0 + $1.unread }
    }
    private var pendingFriends: Int { app.contacts?.pending ?? 0 }
    private var groupInvites: Int { app.contacts?.groupInviteUnread ?? 0 }

    private func handleScan(_ code: String) {
        let text = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = text.range(of: "id=") {
            let tail = text[range.upperBound...]
            let num = tail.prefix { $0.isNumber }
            if let uid = Int64(num), uid > 0 {
                scanTarget = ScanTarget(id: uid)
                return
            }
        }
        if let uid = Int64(text), uid > 0 {
            scanTarget = ScanTarget(id: uid)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topBar
                searchBar
                if pendingFriends > 0 || groupInvites > 0 {
                    noticeBar
                }
                conversationList
            }
            .background(AKColor.bg)
            .overlay {
                if plusOpen {
                    ZStack(alignment: .topTrailing) {
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .onTapGesture { plusOpen = false }
                        plusMenu
                            .padding(.trailing, 8)
                            .padding(.top, 52)
                    }
                    .transition(.opacity)
                }
            }
            .overlay {
                if let n = noticePopup {
                    ZStack {
                        Color.black.opacity(0.45).ignoresSafeArea()
                            .onTapGesture {
                                noticeSeen.insert(n.id)
                                noticePopup = nil
                            }
                        SystemNoticePopup(
                            notice: n,
                            onLater: {
                                noticeSeen.insert(n.id)
                                noticePopup = nil
                            },
                            onDetail: {
                                Task {
                                    if let d = try? await APIClient.shared.notice(id: n.id) {
                                        noticeSeen.insert(n.id)
                                        noticePopup = nil
                                        noticeDetail = d
                                        showNoticeDetail = true
                                    }
                                }
                            },
                            onConfirm: {
                                rememberNotice(n.id, persist: true)
                                Task { await APIClient.shared.readNotice(id: n.id) }
                            }
                        )
                    }
                    .transition(.opacity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                let t = AKPerf.start()
                await app.refreshConversations()
                AKPerf.log("home.refresh", since: t, "\(app.conversations.count) 个会话")
            }
            .task {
                async let notices: Void = loadNoticePopup()
                let t = AKPerf.start()
                await app.refreshConversations()
                AKPerf.log("home.conversations", since: t, "\(app.conversations.count) 个会话")
                let c = AKPerf.start()
                await app.loadContacts()
                AKPerf.log("home.contacts", since: c)
                _ = await notices
            }
            .sheet(isPresented: $showScanner) {
                ScannerView { code in handleScan(code) }
            }
            .navigationDestination(isPresented: $showCreateGroup) {
                CreateGroupView().reportsDetailPage().restoresSwipeBack()
            }
            .navigationDestination(isPresented: $showAddFriend) {
                AddFriendView().reportsDetailPage().restoresSwipeBack()
            }
            .navigationDestination(isPresented: $showSearch) {
                SearchView().reportsDetailPage().restoresSwipeBack()
            }
            .navigationDestination(isPresented: $showRequests) {
                FriendRequestsView().reportsDetailPage().restoresSwipeBack()
            }
            .navigationDestination(isPresented: $showGroupInvites) {
                GroupInvitesView().reportsDetailPage().restoresSwipeBack()
            }
            .navigationDestination(isPresented: $showNoticeDetail) {
                if let d = noticeDetail {
                    NoticeDetailView(detail: d, isRead: false) {
                        rememberNotice(d.id, persist: true)
                    }
                    .restoresSwipeBack()
                }
            }
            .onChange(of: noticePopup) { value in
                if value != nil {
                    tabBar.enter(noticeOverlayPage)
                } else {
                    tabBar.leave(noticeOverlayPage)
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { scanTarget != nil },
                set: { if !$0 { scanTarget = nil } }
            )) {
                if let target = scanTarget {
                    UserProfileView(uid: target.id).reportsDetailPage().restoresSwipeBack()
                }
            }
        }
    }

    /* ---------- 顶栏 ---------- */

    private var topBar: some View {
        HStack(spacing: 8) {
            Text("AK商聊")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AKColor.text)
                .kerning(0.5)
            if unreadBadge > 0 {
                Text("\(unreadBadge > 99 ? 99 : unreadBadge)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(AKColor.red)
                    .frame(minWidth: 17, minHeight: 17)
                    .background(AKColor.redSoft)
                    .clipShape(Capsule())
            }
            Spacer(minLength: 0)
            Button {
                plusOpen = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(AKColor.text)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(AKColor.card)
    }

    /// 与安卓一致：深色圆角浮层，168 宽，四项（发起群聊 / 添加好友·群 / 扫一扫 / 一键已读）
    private var plusMenu: some View {
        VStack(spacing: 0) {
            plusItem("发起群聊", "person.3.fill") { plusOpen = false; showCreateGroup = true }
            plusItem("添加好友/群", "person.badge.plus") { plusOpen = false; showAddFriend = true }
            plusItem("扫一扫", "qrcode.viewfinder") { plusOpen = false; showScanner = true }
            plusItem("一键已读", "checkmark.circle") {
                plusOpen = false
                Task { await app.markAllRead() }
            }
        }
        .frame(width: 168)
        .background(Color(hex: 0x252528).opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.top, 52)
        .padding(.trailing, 8)
    }

    private func plusItem(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /* ---------- 搜索条 ---------- */

    private var searchBar: some View {
        Button {
            showSearch = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.muted)
                Text("搜索聊天、联系人")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.muted)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(AKColor.fill)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(AKColor.card)
        }
        .buttonStyle(.plain)
    }

    /* ---------- 系统公告弹窗 ---------- */

    private static func storedNoticeIds() -> Set<Int64> {
        Set((UserDefaults.standard.stringArray(forKey: noticeDismissKey) ?? []).compactMap { Int64($0) })
    }

    /// 启动/进首页只拉未读，已确认过的 id 本机再记一份，服务端还没清时也不重弹
    private func loadNoticePopup() async {
        guard noticePopup == nil, let data: NoticeUnreadResp = try? await APIClient.shared.get(
            "api/v1/notices", query: ["only_unread": "1"]
        ) else { return }
        let seen = Self.storedNoticeIds().union(noticeSeen)
        noticePopup = data.list.first { $0.id > 0 && $0.read != 1 && !seen.contains($0.id) }
    }

    private func rememberNotice(_ id: Int64, persist: Bool) {
        noticeSeen.insert(id)
        if persist {
            var ids = UserDefaults.standard.stringArray(forKey: Self.noticeDismissKey) ?? []
            if !ids.contains("\(id)") {
                ids.append("\(id)")
                UserDefaults.standard.set(Array(ids.suffix(100)), forKey: Self.noticeDismissKey)
            }
        }
        noticePopup = nil
    }

    /* ---------- 通讯录通知条 ---------- */

    private var noticeBar: some View {
        HStack(spacing: 8) {
            Text("通讯录通知")
                .font(.system(size: 12.5))
                .foregroundColor(AKColor.gold)
            Spacer(minLength: 0)
            if pendingFriends > 0 {
                Button { showRequests = true } label: {
                    Text("新朋友 \(pendingFriends) ›")
                        .font(.system(size: 12.5))
                        .foregroundColor(AKColor.link)
                }
                .buttonStyle(.plain)
            }
            if groupInvites > 0 {
                Button { showGroupInvites = true } label: {
                    Text("群邀请 \(groupInvites) ›")
                        .font(.system(size: 12.5))
                        .foregroundColor(AKColor.link)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AKColor.goldSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    /* ---------- 会话列表 ---------- */

    private var conversationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filtered) { conv in
                    NavigationLink {
                        ChatView(convType: conv.convType, convId: conv.convId, title: conv.name ?? "聊天")
                    } label: {
                        ConversationRow(conv: conv, dark: scheme == .dark)
                            .equatable()
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                            Button {
                                Task { await app.togglePin(conv) }
                            } label: {
                                Label(conv.isTop == 1 ? "取消置顶" : "置顶会话", systemImage: "pin")
                            }
                            Button {
                                Task { await app.toggleMute(conv) }
                            } label: {
                                Label(conv.isMute == 1 ? "取消免打扰" : "消息免打扰", systemImage: "bell.slash")
                            }
                            if conv.unread > 0 {
                                Button {
                                    Task { await app.markRead(convType: conv.convType, convId: conv.convId, lastId: conv.lastMsgId) }
                                } label: {
                                    Label("标为已读", systemImage: "checkmark.circle")
                                }
                            }
                            Button(role: .destructive) {
                                Task { await app.clearConversation(conv) }
                            } label: {
                                Label("清空聊天记录", systemImage: "trash.slash")
                            }
                            Button(role: .destructive) {
                                Task { await app.deleteConversation(conv) }
                            } label: {
                                Label("删除会话", systemImage: "trash")
                            }
                        }
                }
                if filtered.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 38))
                            .foregroundColor(AKColor.hint)
                        Text("还没有聊天，去通讯录找人聊聊")
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 120)
                }
                Spacer(minLength: 20)
            }
        }
        .background(AKColor.card)
        .scrollIndicators(.hidden)
    }
}

/// 会话行：严格对齐安卓 ConvRow（44 头像 / 12·8 内边距 / 右侧 44 窄列 / 17 未读圆 / 置顶底色）
/// Equatable：会话数据没变时，首页整体重算（秒回推送/未读变化）不会重建这一行
private struct ConversationRow: View, Equatable {
    let conv: Conversation
    /// 由父视图传入而不是读 @Environment，这样深色/浅色切换也能参与 == 比较
    let dark: Bool

    private var rowBg: Color {
        guard conv.isTop == 1 else { return AKColor.card }
        return dark ? Color(hex: 0x1E2128) : Color(hex: 0xF0F2F5)
    }

    private var title: String {
        let n = conv.name ?? ""
        if !n.isEmpty { return n }
        return conv.convType == "group" ? "群聊" : "用户"
    }

    /// 摘要：@全体成员 > [谁@我] > 群内昵称：内容 > 内容
    private var summary: Text {
        var head: Text = Text("")
        if conv.convType == "group" && conv.atAll > 0 {
            head = Text("@全体成员 ").foregroundColor(AKColor.red)
        } else if conv.convType == "group" && conv.atMe > 0 {
            let from = conv.lastFromName
            head = Text(from.isEmpty ? "[有人@我] " : "[\(from)@我] ").foregroundColor(AKColor.red)
        }
        let showName = conv.convType == "group" && conv.lastFrom != "me"
            && conv.lastType != 11 && !conv.lastFromName.isEmpty
        if showName {
            head = head + Text("\(conv.lastFromName)：").foregroundColor(AKColor.sub)
        }
        let body = conv.digest?.isEmpty == false ? conv.digest! : "暂无消息"
        return head + Text(body).foregroundColor(AKColor.hint)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(url: conv.avatar, name: title, size: 44)
                if conv.convType == "private" && conv.online == 1 {
                    Circle()
                        .fill(Color(hex: 0x34C759))
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(AKColor.card, lineWidth: 2))
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AKColor.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    if conv.isPretty == 1, let no = conv.prettyNo, !no.isEmpty {
                        PrettyBadge(number: no, isGroup: conv.convType == "group")
                    }
                    if conv.vipLevel > 0 {
                        VipBadge(level: conv.vipLevel)
                    }
                    Spacer(minLength: 0)
                }
                summary
                    .font(.system(size: 13))
                    .lineLimit(1)
            }

            /* 右侧固定窄列：时间在上，未读在下 */
            VStack(alignment: .trailing, spacing: 3) {
                Text(TimeText.listTime(conv.lastTime))
                    .font(.system(size: 10.5))
                    .foregroundColor(AKColor.hint)
                    .lineLimit(1)
                if conv.unread > 0 {
                    Text(conv.unread > 99 ? "99+" : "\(conv.unread)")
                        .font(.system(size: conv.unread > 9 ? 7.5 : 9, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(minWidth: 17, minHeight: 17)
                        .background(conv.isMute == 1
                                    ? (dark ? Color(hex: 0x4A4E55) : Color(hex: 0xC7C9CC))
                                    : Color(hex: 0xF54D4D))
                        .clipShape(Capsule())
                } else if conv.isMute == 1 {
                    Image(systemName: "speaker.slash.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AKColor.hint)
                }
            }
            .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.leading, 12)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .background(rowBg)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AKColor.line)
                .frame(height: 0.5)
                .padding(.leading, 68)
        }
    }
}
