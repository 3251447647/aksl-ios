import SwiftUI

struct ContactsView: View {
    @EnvironmentObject private var app: AppState
    @State private var profileTarget: ProfileTarget?

    var body: some View {
        NavigationStack {
          ScrollViewReader { proxy in
            List {
                Section {
                    NavigationLink {
                        FriendRequestsView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 20)).foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(AKColor.gold)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Text("新的朋友").foregroundColor(AKColor.text)
                            Spacer()
                            if (app.contacts?.pending ?? 0) > 0 {
                                Text("\(app.contacts?.pending ?? 0)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(AKColor.red).clipShape(Capsule())
                            }
                        }
                    }
                    NavigationLink {
                        GroupsListView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 18)).foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(AKColor.brand)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Text("群聊").foregroundColor(AKColor.text)
                        }
                    }
                    NavigationLink {
                        GroupInvitesView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 17)).foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(AKColor.link)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Text("群邀请").foregroundColor(AKColor.text)
                        }
                    }
                }

                if let friends = app.contacts?.friends, !friends.isEmpty {
                    ForEach(friendSections, id: \.letter) { sec in
                        Section(header: Text(sec.letter).id("sec-" + sec.letter)) {
                        ForEach(sec.items) { f in
                            NavigationLink {
                                ChatView(convType: "private", convId: f.id, title: f.displayName)
                            } label: {
                                HStack(spacing: 12) {
                                    AvatarView(url: f.avatar, name: f.displayName, size: 40)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 5) {
                                            Text(f.displayName).foregroundColor(AKColor.text)
                                            if f.isBot == 1 { BadgeView(text: "AI机器人", color: AKColor.link, background: AKColor.blueSoft) }
                                            if f.isPretty == 1, let no = f.prettyNo { BadgeView(text: no) }
                                        }
                                        Text(f.yxId ?? "").font(.system(size: 11)).foregroundColor(AKColor.muted)
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    profileTarget = ProfileTarget(id: f.id)
                                } label: {
                                    Label("资料", systemImage: "person.crop.circle")
                                }
                                .tint(AKColor.link)
                            }
                        }
                        }
                    }
                }

                if let groups = app.contacts?.groups, !groups.isEmpty {
                    Section("群聊") {
                        ForEach(groups) { g in
                            NavigationLink {
                                ChatView(convType: "group", convId: g.id, title: g.name ?? "群聊")
                            } label: {
                                HStack(spacing: 12) {
                                    AvatarView(url: g.avatar, name: g.name ?? "群聊", size: 40)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 5) {
                                            Text(g.name ?? "群聊").foregroundColor(AKColor.text)
                                            if g.isPretty == 1, let no = g.prettyNo { BadgeView(text: no) }
                                        }
                                        Text("\(g.memberCount) 人").font(.system(size: 11)).foregroundColor(AKColor.muted)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("通讯录")
            .refreshable { await app.loadContacts() }
            .task { await app.loadContacts() }
            .overlay(alignment: .trailing) {
                if friendSections.count > 1 {
                    VStack(spacing: 0) {
                        ForEach(friendSections, id: \.letter) { sec in
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
            }
            .sheet(item: $profileTarget) { target in
                NavigationStack {
                    UserProfileView(uid: target.id)
                }
            }
          }
        }
    }

    /// 好友按首字母分组（中文取拼音首字母），右侧索引跳转
    private struct FriendSection: Identifiable {
        let letter: String
        let items: [ContactFriend]
        var id: String { letter }
    }

    private var friendSections: [FriendSection] {
        let friends = app.contacts?.friends ?? []
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
        if let ascii = first.uppercased().unicodeScalars.first,
           ascii.value >= 65, ascii.value <= 90 {
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
