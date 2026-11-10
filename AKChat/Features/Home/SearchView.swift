import SwiftUI

/// 全局搜索：用户 / 群聊 / 聊天记录（对齐安卓 SearchScreen 的搜索框、分组与结果行）
struct SearchView: View {
    @EnvironmentObject private var app: AppState
    @State private var keyword = ""
    /// 0 全部 1 用户 2 群聊
    @State private var tab = 0
    @State private var users: [SearchUser] = []
    @State private var groups: [SearchGroup] = []
    @State private var errorText: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var sent: Set<Int64> = []
    @State private var openMessageSearch = false
    @State private var toastText: String?
    @FocusState private var focused: Bool
    @AppStorage("akSearchHistory") private var historyJSON = "[]"

    private var kw: String { keyword.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if kw.isEmpty {
                if history.isEmpty {
                    Text("输入关键词开始搜索")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.hint)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    historyView
                }
            } else {
                chips
                if let errorText {
                    Text(errorText)
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.top, 6)
                }
                resultList
            }
        }
        .background(AKColor.bg)
        .overlay(alignment: .bottom) { toastView }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                focused = true
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .background(
            NavigationLink(isActive: $openMessageSearch) {
                MessageSearchView(scopeType: "", scopeId: 0, scopeTitle: "", initialKeyword: kw)
            } label: { EmptyView() }
        )
    }

    // MARK: - 搜索历史

    private var history: [String] {
        guard let data = historyJSON.data(using: .utf8),
              let list = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return list
    }

    private func remember(_ text: String) {
        guard !text.isEmpty else { return }
        var list = history.filter { $0 != text }
        list.insert(text, at: 0)
        if list.count > 10 { list = Array(list.prefix(10)) }
        if let data = try? JSONEncoder().encode(list),
           let json = String(data: data, encoding: .utf8) {
            historyJSON = json
        }
    }

    private func clearHistory() {
        historyJSON = "[]"
    }

    private var historyView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("搜索历史")
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.hint)
                Spacer(minLength: 0)
                Button {
                    clearHistory()
                } label: {
                    Text("清空")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.link)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(history, id: \.self) { item in
                        Button {
                            keyword = item
                            triggerSearch()
                        } label: {
                            Text(item)
                                .font(.system(size: 14))
                                .foregroundColor(AKColor.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(AKColor.card)
            }
        }
    }

    // MARK: - 顶部

    private var topBar: some View {
        HStack(spacing: 6) {
            BackButton()
                .frame(width: 34, height: 34)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundColor(AKColor.muted)
                TextField("搜 AK号 / 靓号 / 群号 / 群靓号 / 聊天记录", text: $keyword)
                    .font(.system(size: 14))
                    .focused($focused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { triggerSearch() }
                    .onChange(of: keyword) { _ in triggerSearch() }
                if !keyword.isEmpty {
                    Button {
                        keyword = ""
                        users = []
                        groups = []
                        errorText = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(AKColor.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(AKColor.fill)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.leading, 4)
        .padding(.trailing, 14)
        .padding(.vertical, 8)
        .background(AKColor.card)
    }

    private var chips: some View {
        HStack(spacing: 2) {
            chip("全部", 0)
            chip("用户", 1)
            chip("群聊", 2)
            Button {
                if kw.isEmpty { return }
                openMessageSearch = true
            } label: {
                Text("聊天记录")
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.sub)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AKColor.card)
    }

    private func chip(_ title: String, _ index: Int) -> some View {
        Button {
            tab = index
        } label: {
            Text(title)
                .font(.system(size: 12.5, weight: tab == index ? .medium : .regular))
                .foregroundColor(tab == index ? AKColor.brand : AKColor.sub)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(tab == index ? AKColor.brandSoft : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 结果

    private var resultList: some View {
        List {
            ForEach(resultRows) { row in
                rowView(row)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(AKColor.card)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AKColor.bg)
    }

    @ViewBuilder
    private func rowView(_ row: SearchRow) -> some View {
        switch row {
        case .userHeader:
            sectionHeader("用户")
        case .groupHeader:
            sectionHeader("群聊")
        case .messageHeader:
            sectionHeader("聊天记录")
        case .user(let user):
            userRow(user)
        case .group(let group):
            groupRow(group)
        case .messageEntry(let text):
            messageEntryRow(text)
        case .empty:
            Text("没有找到「\(kw)」相关内容")
                .font(.system(size: 13))
                .foregroundColor(AKColor.hint)
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(AKColor.hint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)
            .background(AKColor.bg)
    }

    private func userRow(_ user: SearchUser) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                NavigationLink {
                    UserProfileView(uid: user.id, presetName: user.nickname ?? "").restoresSwipeBack()
                } label: {
                    userInfo(user)
                }
                .buttonStyle(.plain)
                userAction(user)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            rowDivider
        }
    }

    private func userInfo(_ user: SearchUser) -> some View {
        HStack(spacing: 11) {
            AvatarView(url: user.avatar, name: user.nickname ?? "用户", size: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(user.nickname ?? "用户")
                        .font(.system(size: 15))
                        .foregroundColor(akNameColor(vipLevel: user.vipLevel,
                                                     isPretty: user.isPretty,
                                                     isGroup: false))
                        .lineLimit(1)
                    if user.isPretty == 1 {
                        PrettyBadge(number: user.prettyNo)
                    }
                    if user.vipLevel > 0 { VipBadge(level: user.vipLevel) }
                }
                if let yx = user.yxId, !yx.isEmpty {
                    Text("AK号：\(yx)")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.hint)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func userAction(_ user: SearchUser) -> some View {
        if isSelf(user) {
            Text("我的备忘")
                .font(.system(size: 11.5))
                .foregroundColor(AKColor.hint)
        } else if user.isFriend == 0 && !sent.contains(user.id) {
            Button {
                Task { await addFriend(user) }
            } label: {
                Text("加好友")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.brand)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AKColor.brandSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(.plain)
        } else if user.isFriend == 0 {
            Text("已申请")
                .font(.system(size: 11.5))
                .foregroundColor(AKColor.hint)
        } else {
            Text("发消息")
                .font(.system(size: 11.5))
                .foregroundColor(AKColor.hint)
        }
    }

    private func isSelf(_ user: SearchUser) -> Bool {
        guard let myId = app.user?.id else { return false }
        return myId == user.id
    }

    private func groupRow(_ group: SearchGroup) -> some View {
        VStack(spacing: 0) {
            NavigationLink {
                ChatView(convType: "group", convId: group.id, title: group.name)
            } label: {
                groupRowContent(group)
            }
            .buttonStyle(.plain)
            rowDivider
        }
    }

    private func groupRowContent(_ group: SearchGroup) -> some View {
        HStack(spacing: 11) {
            AvatarView(url: group.avatar, name: group.name, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(group.name)
                        .font(.system(size: 15))
                        .foregroundColor(akNameColor(vipLevel: 0, isPretty: group.isPretty, isGroup: true))
                        .lineLimit(1)
                    if group.isPretty == 1, !group.prettyNo.isEmpty {
                        PrettyBadge(number: group.prettyNo, isGroup: true)
                    }
                }
                Text(groupSubtitle(group))
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.hint)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if group.isMember == 0 {
                Text("加入")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.brand)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func groupSubtitle(_ group: SearchGroup) -> String {
        var text = "\(group.memberCount) 人"
        if !group.groupNo.isEmpty { text += " · 群号 \(group.groupNo)" }
        return text
    }

    private func messageEntryRow(_ text: String) -> some View {
        NavigationLink {
            MessageSearchView(scopeType: "", scopeId: 0, scopeTitle: "", initialKeyword: kw)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundColor(AKColor.brand)
                Text(text)
                    .font(.system(size: 13.5))
                    .foregroundColor(AKColor.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var rowDivider: some View {
        Rectangle().fill(AKColor.line).frame(height: 0.5).padding(.leading, 65)
    }

    // MARK: - 数据

    private enum SearchRow: Identifiable {
        case userHeader
        case user(SearchUser)
        case groupHeader
        case group(SearchGroup)
        case messageHeader
        case messageEntry(String)
        case empty

        var id: String {
            switch self {
            case .userHeader: return "sec_user"
            case .groupHeader: return "sec_group"
            case .messageHeader: return "sec_message"
            case .user(let u): return "u\(u.id)"
            case .group(let g): return "g\(g.id)"
            case .messageEntry: return "message_entry"
            case .empty: return "empty"
            }
        }
    }

    private var resultRows: [SearchRow] {
        var rows: [SearchRow] = []
        let showUsers = tab == 0 || tab == 1
        let showGroups = tab == 0 || tab == 2
        if showUsers && !users.isEmpty {
            rows.append(.userHeader)
            rows.append(contentsOf: users.map { SearchRow.user($0) })
        }
        if showGroups && !groups.isEmpty {
            rows.append(.groupHeader)
            rows.append(contentsOf: groups.map { SearchRow.group($0) })
        }
        if tab == 0 {
            rows.append(.messageHeader)
            rows.append(.messageEntry("在全部聊天记录中搜索「\(kw)」"))
            if users.isEmpty && groups.isEmpty {
                rows.append(.empty)
            }
        } else if (showUsers && users.isEmpty) || (showGroups && groups.isEmpty) {
            rows.append(.empty)
        }
        return rows
    }

    private func triggerSearch() {
        searchTask?.cancel()
        errorText = nil
        let text = kw
        guard !text.isEmpty else {
            users = []
            groups = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            await runSearch(text)
        }
    }

    private func runSearch(_ text: String) async {
        do {
            let data = try await APIClient.shared.search(keyword: text)
            users = data.users
            groups = data.groups
            errorText = nil
            remember(text)
        } catch {
            users = []
            groups = []
            errorText = error.localizedDescription
        }
    }

    private func addFriend(_ user: SearchUser) async {
        do {
            let msg = try await APIClient.shared.postRaw(
                "api/v1/friends/add",
                body: ["to_uid": user.id, "message": "你好，我想加你为好友"]
            )
            sent.insert(user.id)
            showToast(msg.isEmpty ? "好友申请已发送" : msg)
        } catch {
            showToast(error.localizedDescription)
        }
    }

    private var toastView: some View {
        Group {
            if let toastText {
                Text(toastText)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color(hex: 0x1A1D26).opacity(0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 40)
                    .padding(.bottom, 28)
            }
        }
    }

    private func showToast(_ message: String) {
        toastText = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if toastText == message { toastText = nil }
        }
    }
}
