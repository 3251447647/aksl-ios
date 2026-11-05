import SwiftUI

struct ScanTarget: Identifiable {
    let id: Int64
}

struct HomeView: View {
    @EnvironmentObject private var app: AppState
    @State private var showCreateGroup = false
    @State private var showAddFriend = false
    @State private var showSearch = false
    @State private var showScanner = false
    @State private var scanTarget: ScanTarget?

    private var filtered: [Conversation] { app.conversations }

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
                searchBar
                List {
                    ForEach(filtered) { conv in
                        NavigationLink {
                            ChatView(convType: conv.convType, convId: conv.convId, title: conv.name ?? "聊天")
                        } label: {
                            ConversationRow(conv: conv)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparatorTint(AKColor.line)
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
                                    Task {
                                        await app.markRead(convType: conv.convType, convId: conv.convId, lastId: conv.lastMsgId)
                                    }
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
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { await app.deleteConversation(conv) }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                            Button {
                                Task { await app.togglePin(conv) }
                            } label: {
                                Label(conv.isTop == 1 ? "取消置顶" : "置顶", systemImage: "pin")
                            }
                            .tint(AKColor.gold)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await app.toggleMute(conv) }
                            } label: {
                                Label(conv.isMute == 1 ? "取消免打扰" : "免打扰", systemImage: "bell.slash")
                            }
                            .tint(AKColor.sub)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .overlay {
                    if filtered.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 38)).foregroundColor(AKColor.hint)
                            Text("还没有聊天，去通讯录找人聊聊")
                                .font(.system(size: 13)).foregroundColor(AKColor.muted)
                        }
                    }
                }
            }
            .background(AKColor.bg)
            .navigationTitle("AK商聊")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showScanner = true
                        } label: {
                            Label("扫一扫", systemImage: "qrcode.viewfinder")
                        }
                        Button {
                            showCreateGroup = true
                        } label: {
                            Label("发起群聊", systemImage: "person.3")
                        }
                        Button {
                            showAddFriend = true
                        } label: {
                            Label("添加好友", systemImage: "person.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus.circle").foregroundColor(AKColor.text)
                    }
                }
            }
            .refreshable { await app.refreshConversations() }
            .task { await app.refreshConversations() }
            .sheet(isPresented: $showCreateGroup) {
                NavigationStack { CreateGroupView() }
            }
            .sheet(isPresented: $showAddFriend) {
                NavigationStack { AddFriendView() }
            }
            .sheet(isPresented: $showScanner) {
                ScannerView { code in
                    handleScan(code)
                }
            }
            .sheet(item: $scanTarget) { target in
                NavigationStack {
                    UserProfileView(uid: target.id)
                }
            }
            .sheet(isPresented: $showSearch) {
                NavigationStack { SearchView() }
            }
        }
    }

    private var searchBar: some View {
        Button {
            showSearch = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(AKColor.muted)
                Text("搜索聊天、联系人")
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.muted)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(AKColor.fill)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AKColor.card)
        }
    }
}

private struct ConversationRow: View {
    let conv: Conversation

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                AvatarView(url: conv.avatar, name: conv.name ?? "聊天", size: 48)
                    .overlay(alignment: .bottomTrailing) {
                        if conv.convType == "private" && conv.online == 1 {
                            Circle().fill(AKColor.brand)
                                .frame(width: 11, height: 11)
                                .overlay(Circle().stroke(AKColor.card, lineWidth: 2))
                                .offset(x: 2, y: 2)
                        }
                    }
                if conv.unread > 0 && conv.isMute == 0 {
                    Text(conv.unread > 99 ? "99+" : "\(conv.unread)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(AKColor.red)
                        .clipShape(Capsule())
                        .offset(x: 6, y: -6)
                } else if conv.isMute == 1 && conv.unread > 0 {
                    Circle().fill(AKColor.muted).frame(width: 8, height: 8).offset(x: 4, y: -2)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(conv.name ?? "聊天")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AKColor.text)
                        .lineLimit(1)
                    if conv.isPretty == 1, let no = conv.prettyNo, !no.isEmpty {
                        BadgeView(text: "靓 \(no)")
                    }
                    if conv.vipLevel > 0 {
                        BadgeView(text: conv.vipLevel >= 2 ? "SVIP" : "VIP", color: AKColor.gold, background: AKColor.goldSoft)
                    }
                    if conv.isTop == 1 {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundColor(AKColor.muted)
                    }
                    Spacer(minLength: 0)
                    Text(TimeText.short(conv.lastTime))
                        .font(.system(size: 11))
                        .foregroundColor(AKColor.muted)
                }
                HStack(spacing: 6) {
                    if conv.atMe > 0 {
                        Text("[有人@我]")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AKColor.red)
                    }
                    Text(conv.digest?.isEmpty == false ? conv.digest! : "暂无消息")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.muted)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(conv.isTop == 1 ? AKColor.cardAlt : AKColor.card)
        .contentShape(Rectangle())
    }
}
