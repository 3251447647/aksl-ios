import SwiftUI

/// 群聊列表：与通讯录「群聊」分段同一套行样式（对齐安卓 ContactsScreen）
struct GroupsListView: View {
    @EnvironmentObject private var app: AppState

    private var groups: [ContactGroup] { app.contacts?.groups ?? [] }

    var body: some View {
        Group {
            if groups.isEmpty {
                Text("还没有加入任何群聊")
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.placeholder)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(groups.enumerated()), id: \.element.id) { idx, g in
                        groupRow(g, isLast: idx == groups.count - 1)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(AKColor.card)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(AKColor.bg)
            }
        }
        .background(AKColor.bg)
        .navigationTitle("群聊")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await app.loadContacts() }
        .task { await app.loadContacts() }
    }

    private func groupRow(_ g: ContactGroup, isLast: Bool) -> some View {
        NavigationLink {
            ChatView(convType: "group", convId: g.id, title: g.name ?? "群聊")
        } label: {
            VStack(spacing: 0) {
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
                if !isLast {
                    Rectangle().fill(AKColor.fill).frame(height: 0.6).padding(.leading, 72)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
