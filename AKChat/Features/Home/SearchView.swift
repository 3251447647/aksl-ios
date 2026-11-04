import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var keyword = ""
    @State private var tab = 0
    @State private var users: [SearchUser] = []
    @State private var groups: [SearchGroup] = []
    @State private var messages: [SearchMessageItem] = []
    @State private var loading = false
    @State private var error: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var joinTarget: SearchGroup?
    @State private var joinReason = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(AKColor.muted)
                    TextField("搜索联系人、群聊、聊天记录", text: $keyword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { triggerSearch() }
                        .onChange(of: keyword) { _ in triggerSearch() }
                    if !keyword.isEmpty {
                        Button {
                            keyword = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AKColor.hint)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button("取消") { dismiss() }
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.link)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AKColor.card)

            Picker("", selection: $tab) {
                Text("聊天记录").tag(0)
                Text("用户").tag(1)
                Text("群聊").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            List {
                if loading {
                    ProgressView()
                }
                if let error {
                    Text(error).font(.system(size: 12)).foregroundColor(AKColor.red)
                }
                if tab == 0 {
                    ForEach(messages) { item in
                        NavigationLink {
                            ChatView(convType: item.convType, convId: item.convId,
                                     title: item.convName.isEmpty ? "聊天" : item.convName)
                        } label: {
                            messageRow(item)
                        }
                    }
                } else if tab == 1 {
                    ForEach(users) { user in
                        NavigationLink {
                            UserProfileView(uid: user.id)
                        } label: {
                            userRow(user)
                        }
                    }
                } else {
                    ForEach(groups) { group in
                        Button {
                            if group.isMember == 1 {
                                joinTarget = nil
                            } else {
                                joinReason = ""
                                joinTarget = group
                            }
                        } label: {
                            groupRow(group)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .background(AKColor.bg)
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
        .alert("加入群聊", isPresented: Binding(
            get: { joinTarget != nil },
            set: { if !$0 { joinTarget = nil } }
        )) {
            TextField("申请理由（部分群需要）", text: $joinReason)
            Button("取消", role: .cancel) { joinTarget = nil }
            Button("申请加入") {
                if let group = joinTarget, group.isMember == 0 {
                    Task { await join(group) }
                }
            }
        } message: {
            if let group = joinTarget {
                Text(group.name)
            }
        }
    }

    private func messageRow(_ item: SearchMessageItem) -> some View {
        HStack(spacing: 10) {
            AvatarView(url: item.convAvatar, name: item.convName.isEmpty ? "聊天" : item.convName, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.convName.isEmpty ? "聊天" : item.convName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AKColor.text)
                    Spacer()
                    Text(TimeText.short(item.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(AKColor.hint)
                }
                Text(item.fromName.isEmpty ? item.digest : "\(item.fromName)：\(item.digest)")
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.muted)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private func userRow(_ user: SearchUser) -> some View {
        HStack(spacing: 10) {
            AvatarView(url: user.avatar, name: user.nickname ?? "用户", size: 36)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(user.nickname ?? "用户")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(akNameColor(vipLevel: user.vipLevel,
                                                     isPretty: user.isPretty,
                                                     isGroup: false))
                    if user.vipLevel > 0 { VipBadge(level: user.vipLevel) }
                    if user.isPretty == 1 { PrettyBadge(number: user.prettyNo) }
                }
                Text("AK号：\(user.yxId ?? "")")
                    .font(.system(size: 11))
                    .foregroundColor(AKColor.muted)
            }
            Spacer()
            if user.isFriend == 1 {
                Text("好友").font(.system(size: 11)).foregroundColor(AKColor.muted)
            }
        }
        .padding(.vertical, 3)
    }

    private func groupRow(_ group: SearchGroup) -> some View {
        HStack(spacing: 10) {
            AvatarView(url: group.avatar, name: group.name, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(group.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(group.isPretty == 1 ? AKColor.gold : AKColor.text)
                    if group.isPretty == 1 { PrettyBadge(number: "", isGroup: true) }
                }
                Text("\(group.memberCount) 人 · 群号 \(group.groupNo)")
                    .font(.system(size: 11))
                    .foregroundColor(AKColor.muted)
            }
            Spacer()
            Text(group.isMember == 1 ? "已加入" : "申请加入")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(group.isMember == 1 ? AKColor.muted : AKColor.brand)
        }
        .padding(.vertical, 3)
    }

    private func triggerSearch() {
        searchTask?.cancel()
        let kw = keyword.trimmingCharacters(in: .whitespaces)
        guard !kw.isEmpty else {
            users = []
            groups = []
            messages = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            await runSearch(kw)
        }
    }

    private func runSearch(_ kw: String) async {
        loading = true
        defer { loading = false }
        do {
            let data = try await APIClient.shared.search(keyword: kw)
            users = data.users
            groups = data.groups
            let msgData = try await APIClient.shared.searchMessages(keyword: kw)
            messages = msgData.list
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func join(_ group: SearchGroup) async {
        do {
            let msg = try await APIClient.shared.joinGroup(id: group.id, reason: joinReason)
            error = msg
            if let data = try? await APIClient.shared.search(keyword: keyword) {
                groups = data.groups
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
