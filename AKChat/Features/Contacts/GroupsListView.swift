import SwiftUI

struct GroupsListView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        List {
            ForEach(app.contacts?.groups ?? []) { g in
                NavigationLink {
                    ChatView(convType: "group", convId: g.id, title: g.name ?? "群聊")
                } label: {
                    HStack(spacing: 12) {
                        AvatarView(url: g.avatar, name: g.name ?? "群聊", size: 42)
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
            if (app.contacts?.groups ?? []).isEmpty {
                Text("还没有群聊").font(.system(size: 13)).foregroundColor(AKColor.muted)
            }
        }
        .navigationTitle("群聊")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await app.loadContacts() }
        .task { await app.loadContacts() }
    }
}
