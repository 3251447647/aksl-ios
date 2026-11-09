import SwiftUI

/// 通讯录：新朋友 / 群通知 / 系统公告 + 好友·群聊分段 + 首字母索引（对齐安卓 ContactsScreen）
struct ContactsView: View {
    @EnvironmentObject private var app: AppState
    @State private var profileTarget: ProfileTarget?
    @State private var showAddFriend = false
    @State private var tab = 0
    @State private var activeLetter: String?

    private var friends: [ContactFriend] { app.contacts?.friends ?? [] }
    private var groups: [ContactGroup] { app.contacts?.groups ?? [] }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                entries
                Color.clear.frame(height: 10)
                tabBar
                if tab == 0 {
                    ScrollViewReader { proxy in
                        ScrollView {
                            friendList
                                .padding(.bottom, 14)
                        }
                        .overlay(alignment: .trailing) {
                            if friendSections.count > 1 {
                                indexBar(proxy)
                            }
                        }
                        .overlay {
                            if let letter = activeLetter {
                                Text(letter)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Color(hex: 0x1A1D26).opacity(0.8))
                                    .clipShape(Circle())
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                } else {
                    ScrollView {
                        groupList.padding(.bottom, 14)
                    }
                }
            }
            .background(AKColor.bg)
            .navigationTitle("通讯录")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await app.loadContacts() }
            .task { await app.loadContacts() }
            .sheet(item: $profileTarget) { target in
                NavigationStack { UserProfileView(uid: target.id) }
            }
            .sheet(isPresented: $showAddFriend) {
                NavigationStack { AddFriendView() }
            }
        }
    }

    // MARK: - 顶部

    private var searchBar: some View {
        Button {
            showAddFriend = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundColor(AKColor.muted)
                Text("搜索 / 添加好友")
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.muted)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(AKColor.fill)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(AKColor.card)
        }
        .buttonStyle(.plain)
    }

    private var entries: some View {
        VStack(spacing: 0) {
            NavigationLink { FriendRequestsView() } label: {
                entryRow("新朋友", "person.badge.plus", Color(hex: 0xF0B429),
                         badge: app.contacts?.pending ?? 0)
            }
            divider
            NavigationLink { GroupInvitesView() } label: {
                entryRow("群通知", "person.3.fill", AKColor.brand,
                         badge: app.contacts?.groupInviteUnread ?? 0)
            }
            divider
            NavigationLink { NoticesView() } label: {
                entryRow("系统公告", "megaphone.fill", Color(hex: 0x57C7FF), badge: 0)
            }
        }
        .background(AKColor.card)
    }

    private func entryRow(_ title: String, _ icon: String, _ color: Color, badge: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            Text(title).font(.system(size: 15)).foregroundColor(AKColor.text)
            Spacer(minLength: 0)
            if badge > 0 {
                Text(badge > 99 ? "99+" : "\(badge)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, badge > 9 ? 4 : 0)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(AKColor.red)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var divider: some View {
        Rectangle().fill(AKColor.fill).frame(height: 0.6).padding(.leading, 66)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabItem("好友 (\(friends.count))", 0)
            tabItem("群聊 (\(groups.count))", 1)
        }
        .background(
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle().fill(AKColor.fill).frame(height: 0.6)
            }
        )
    }

    private func tabItem(_ title: String, _ index: Int) -> some View {
        Button {
            tab = index
        } label: {
            VStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 14, weight: tab == index ? .semibold : .regular))
                    .foregroundColor(tab == index ? AKColor.text : AKColor.muted)
                Rectangle()
                    .fill(tab == index ? AKColor.brand : Color.clear)
                    .frame(width: 22, height: 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 好友列表

    private var friendList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("共 \(friends.count) 位好友")
                .font(.system(size: 12))
                .foregroundColor(AKColor.muted)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            ForEach(friendSections) { sec in
                Text(sec.letter)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AKColor.sub)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                    .background(AKColor.bg)
                    .id("sec-" + sec.letter)
                VStack(spacing: 0) {
                    ForEach(Array(sec.items.enumerated()), id: \.element.id) { idx, f in
                        Button {
                            profileTarget = ProfileTarget(id: f.id)
                        } label: {
                            friendRow(f)
                        }
                        .buttonStyle(.plain)
                        if idx < sec.items.count - 1 {
                            Rectangle().fill(AKColor.fill).frame(height: 0.6).padding(.leading, 72)
                        }
                    }
                }
                .background(AKColor.card)
            }
            if friendSections.isEmpty {
                Text("还没有好友，点上面「新朋友」添加")
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.placeholder)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
            }
        }
    }

    private func friendRow(_ f: ContactFriend) -> some View {
        HStack(spacing: 12) {
            AvatarView(url: f.avatar, name: f.displayName, size: 44)
                .overlay(alignment: .bottomTrailing) {
                    if f.online == 1 {
                        Circle().fill(AKColor.brand).frame(width: 11, height: 11)
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(f.displayName)
                        .font(.system(size: 15))
                        .foregroundColor(akNameColor(vipLevel: f.vipLevel, isPretty: f.isPretty, isGroup: false))
                        .lineLimit(1)
                    if f.isPretty == 1, let no = f.prettyNo, !no.isEmpty {
                        PrettyBadge(number: no)
                    }
                    if f.vipLevel > 0 { VipBadge(level: f.vipLevel) }
                    if f.isBot == 1 {
                        Text("AI机器人")
                            .font(.system(size: 10))
                            .foregroundColor(AKColor.link)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(AKColor.blueSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                Text("AK号 " + akSubtitleNumber(f))
                    .font(.system(size: f.isPretty == 1 ? 12.5 : 11.5,
                                  weight: f.isPretty == 1 ? .semibold : .regular))
                    .foregroundColor(f.isPretty == 1 ? AKColor.gold : AKColor.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .frame(height: 66)
        .contentShape(Rectangle())
    }

    private func akSubtitleNumber(_ f: ContactFriend) -> String {
        if f.isPretty == 1, let no = f.prettyNo, !no.isEmpty { return no }
        return f.yxId ?? ""
    }

    // MARK: - 群列表

    private var groupList: some View {
        VStack(spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.element.id) { idx, g in
                NavigationLink {
                    ChatView(convType: "group", convId: g.id, title: g.name ?? "群聊")
                } label: {
                    HStack(spacing: 12) {
                        AvatarView(url: g.avatar, name: g.name ?? "群聊", size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(g.name ?? "群聊")
                                    .font(.system(size: 15))
                                    .foregroundColor(akNameColor(vipLevel: 0, isPretty: g.isPretty, isGroup: true))
                                    .lineLimit(1)
                                if g.isPretty == 1, let no = g.prettyNo, !no.isEmpty {
                                    PrettyBadge(number: no, isGroup: true)
                                }
                                if g.myRole == 1 {
                                    BadgeView(text: "群主", color: AKColor.gold, background: AKColor.goldSoft)
                                } else if g.myRole == 2 {
                                    BadgeView(text: "管理员", color: AKColor.link, background: AKColor.blueSoft)
                                }
                            }
                            Text("\(g.memberCount) 人")
                                .font(.system(size: 11.5))
                                .foregroundColor(AKColor.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 13)
                    .frame(height: 66)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if idx < groups.count - 1 {
                    Rectangle().fill(AKColor.fill).frame(height: 0.6).padding(.leading, 72)
                }
            }
            if groups.isEmpty {
                Text("还没有加入任何群聊")
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.placeholder)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
            }
        }
        .background(AKColor.card)
    }

    // MARK: - 索引

    private func indexBar(_ proxy: ScrollViewProxy) -> some View {
        let rowHeight: CGFloat = 17
        return VStack(spacing: 0) {
            ForEach(friendSections) { sec in
                Text(sec.letter)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(AKColor.sub)
                    .frame(width: 18, height: rowHeight)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    let count = friendSections.count
                    guard count > 0 else { return }
                    let idx = min(max(Int((value.location.y - 6) / rowHeight), 0), count - 1)
                    let letter = friendSections[idx].letter
                    guard letter != activeLetter else { return }
                    activeLetter = letter
                    proxy.scrollTo("sec-" + letter, anchor: .top)
                }
                .onEnded { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        activeLetter = nil
                    }
                }
        )
        .padding(.trailing, 2)
    }

    // MARK: - 分组

    private struct FriendSection: Identifiable {
        let letter: String
        let items: [ContactFriend]
        var id: String { letter }
    }

    private var friendSections: [FriendSection] {
        var buckets: [String: [ContactFriend]] = [:]
        for f in friends {
            buckets[Self.initial(of: f.displayName), default: []].append(f)
        }
        let letters = buckets.keys.sorted { a, b in
            if a == "#" { return false }
            if b == "#" { return true }
            return a < b
        }
        return letters.map { FriendSection(letter: $0, items: (buckets[$0] ?? []).sorted { $0.displayName < $1.displayName }) }
    }

    private static func initial(of name: String) -> String {
        let first = String(name.prefix(1))
        guard !first.isEmpty else { return "#" }
        if let ascii = first.uppercased().unicodeScalars.first, ascii.value >= 65, ascii.value <= 90 {
            return String(Character(ascii))
        }
        let mutable = NSMutableString(string: first) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformMandarinLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        let latin = (mutable as String).uppercased()
        if let c = latin.first, c >= "A", c <= "Z" { return String(c) }
        return "#"
    }
}
