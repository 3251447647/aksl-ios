import SwiftUI

/// 通讯录：新朋友 / 群通知 / 系统公告 + 好友·群聊分段 + 首字母索引（对齐安卓 ContactsScreen）
struct ContactsView: View {
    @EnvironmentObject private var app: AppState
    @State private var profileTarget: ProfileTarget?
    @State private var showAddFriend = false
    @State private var tab = 0

    private var friends: [ContactFriend] { app.contacts?.friends ?? [] }
    private var groups: [ContactGroup] { app.contacts?.groups ?? [] }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 10) {
                            searchBar
                            entries
                            tabBar
                            if tab == 0 { friendList } else { groupList }
                        }
                        .padding(.bottom, 14)
                    }
                    .overlay(alignment: .trailing) {
                        if tab == 0 && friendSections.count > 1 {
                            indexBar(proxy)
                        }
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
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.hint)
                Text("搜索 / 添加好友")
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.hint)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(AKColor.fill)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.top, 6)
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
                entryRow("系统公告", "megaphone.fill", Color(hex: 0x5AA9F5), badge: 0)
            }
        }
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 10)
    }

    private func entryRow(_ title: String, _ icon: String, _ color: Color, badge: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(title).font(.system(size: 15)).foregroundColor(AKColor.text)
            Spacer()
            if badge > 0 {
                Text("\(badge)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(AKColor.red).clipShape(Capsule())
            }
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(AKColor.hint)
        }
        .padding(.horizontal, 13)
        .frame(height: 54)
        .contentShape(Rectangle())
    }

    private var divider: some View {
        Rectangle().fill(AKColor.line).frame(height: 0.5).padding(.leading, 63)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabItem("好友 (\(friends.count))", 0)
            tabItem("群聊 (\(groups.count))", 1)
        }
        .background(
            VStack(spacing: 0) {
                Spacer()
                Rectangle().fill(AKColor.line).frame(height: 0.5)
            }
        )
        .padding(.top, 4)
    }

    private func tabItem(_ title: String, _ index: Int) -> some View {
        Button {
            tab = index
        } label: {
            VStack(spacing: 7) {
                Text(title)
                    .font(.system(size: 14.5, weight: tab == index ? .semibold : .regular))
                    .foregroundColor(tab == index ? AKColor.text : AKColor.muted)
                Rectangle()
                    .fill(tab == index ? AKColor.brand : Color.clear)
                    .frame(width: 26, height: 2.5)
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 好友列表

    private var friendList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("共 \(friends.count) 位好友")
                .font(.system(size: 12.5))
                .foregroundColor(AKColor.muted)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            ForEach(friendSections) { sec in
                Text(sec.letter)
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .frame(height: 26)
                    .background(AKColor.fill)
                    .id("sec-" + sec.letter)
                VStack(spacing: 0) {
                    ForEach(sec.items) { f in
                        NavigationLink {
                            ChatView(convType: "private", convId: f.id, title: f.displayName)
                        } label: {
                            friendRow(f)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                profileTarget = ProfileTarget(id: f.id)
                            } label: {
                                Label("查看资料", systemImage: "person.crop.circle")
                            }
                        }
                    }
                }
                .background(AKColor.card)
            }
            if friendSections.isEmpty {
                Text("还没有好友，点上方搜索添加")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.hint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
        }
    }

    private func friendRow(_ f: ContactFriend) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomLeading) {
                AvatarView(url: f.avatar, name: f.displayName, size: 46)
                if f.isPretty == 1, let no = f.prettyNo, !no.isEmpty {
                    Text(no)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(Color(hex: 0xF3D27C))
                        .padding(.horizontal, 3)
                        .frame(height: 13)
                        .background(Color(hex: 0x1A1A1A).opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .offset(x: -2, y: 3)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
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
                Text("AK号 \(f.yxId ?? "")")
                    .font(.system(size: 12))
                    .foregroundColor(f.isPretty == 1 ? Color(hex: 0xC9A44C) : AKColor.muted)
            }
            Spacer(minLength: 0)
            if f.online == 1 {
                Circle().fill(AKColor.brand).frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 66)
        .contentShape(Rectangle())
    }

    // MARK: - 群列表

    private var groupList: some View {
        VStack(spacing: 0) {
            ForEach(groups) { g in
                NavigationLink {
                    ChatView(convType: "group", convId: g.id, title: g.name ?? "群聊")
                } label: {
                    HStack(spacing: 12) {
                        AvatarView(url: g.avatar, name: g.name ?? "群聊", size: 46)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 5) {
                                Text(g.name ?? "群聊")
                                    .font(.system(size: 15))
                                    .foregroundColor(akNameColor(vipLevel: 0, isPretty: g.isPretty, isGroup: true))
                                    .lineLimit(1)
                                if g.isPretty == 1, let no = g.prettyNo, !no.isEmpty {
                                    PrettyBadge(number: no, isGroup: true)
                                }
                            }
                            Text("\(g.memberCount) 人")
                                .font(.system(size: 12))
                                .foregroundColor(AKColor.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 13)
                    .frame(height: 66)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if groups.isEmpty {
                Text("还没有群聊")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.hint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
        }
        .background(AKColor.card)
    }

    // MARK: - 索引

    private func indexBar(_ proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            ForEach(friendSections) { sec in
                Text(sec.letter)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(AKColor.sub)
                    .frame(width: 15, height: 13)
                    .contentShape(Rectangle())
                    .onTapGesture { proxy.scrollTo("sec-" + sec.letter, anchor: .top) }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 1)
        .background(.ultraThinMaterial, in: Capsule())
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
