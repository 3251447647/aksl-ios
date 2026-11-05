import SwiftUI

struct GroupInfoView: View {
    let groupId: Int64
    var onLeft: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppState
    @State private var info: GroupInfo?
    @State private var loading = true
    @State private var errorText: String?
    @State private var confirmLeave = false

    var body: some View {
        List {
            if let info {
                Section {
                    HStack(spacing: 14) {
                        AvatarView(url: info.avatar, name: info.name ?? "群聊", size: 62)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(info.name ?? "群聊")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(AKColor.text)
                                if info.isPretty == 1, !info.displayNo.isEmpty {
                                    BadgeView(text: "群靓 \(info.displayNo)")
                                }
                            }
                            Text("群号：\(info.groupNo ?? info.displayNo)　\(info.memberCount)/\(info.maxMember)")
                                .font(.system(size: 12))
                                .foregroundColor(AKColor.muted)
                            if let intro = info.intro, !intro.isEmpty {
                                Text(intro).font(.system(size: 12)).foregroundColor(AKColor.sub)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                if info.isBanned == 1 {
                    Section {
                        Label(info.banReason ?? "该群已被封禁", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(AKColor.red)
                    }
                }

                if let notice = info.notice, !notice.isEmpty {
                    Section("群公告") {
                        Text(notice)
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.text)
                            .padding(.vertical, 2)
                    }
                }

                Section {
                    NavigationLink { GroupNoticesView(groupId: groupId) } label: {
                        Label("群公告记录", systemImage: "megaphone")
                    }
                    NavigationLink {
                        GroupMembersView(groupId: groupId, myRole: info.myRole, myUid: app.user?.id ?? 0)
                    } label: {
                        Label("群成员管理", systemImage: "person.2")
                    }
                    if info.allowInvite == 1 {
                        NavigationLink { InviteMembersView(groupId: groupId) } label: {
                            Label("邀请好友进群", systemImage: "person.badge.plus")
                        }
                    }
                    NavigationLink { LiveRoomView(gid: groupId) } label: {
                        Label("直播间", systemImage: "video")
                    }
                    NavigationLink { GroupCallView(gid: groupId, callType: 1) } label: {
                        Label("群语音通话", systemImage: "phone")
                    }
                    NavigationLink { GroupCallView(gid: groupId, callType: 2) } label: {
                        Label("群视频通话", systemImage: "video.fill")
                    }
                }

                Section("群成员（\(info.memberCount)）") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 12) {
                        ForEach(info.members) { m in
                            VStack(spacing: 4) {
                                AvatarView(url: m.avatar, name: m.name ?? "成员", size: 44)
                                Text(m.name ?? "成员")
                                    .font(.system(size: 10))
                                    .foregroundColor(AKColor.muted)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    Button(role: .destructive) {
                        confirmLeave = true
                    } label: {
                        Text("退出群聊").frame(maxWidth: .infinity)
                    }
                }
            } else if loading {
                ProgressView().frame(maxWidth: .infinity)
            } else if let errorText {
                Text(errorText).font(.system(size: 13)).foregroundColor(AKColor.red)
            }
        }
        .navigationTitle("群资料")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .alert("退出群聊？", isPresented: $confirmLeave) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) {
                Task {
                    await APIClient.shared.quitGroup(id: groupId)
                    onLeft?()
                    dismiss()
                }
            }
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            info = try await APIClient.shared.groupInfo(id: groupId)
        } catch {
            errorText = error.localizedDescription
        }
    }
}
