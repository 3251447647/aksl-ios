import SwiftUI

/// 添加好友：按 AK号 / 邮箱 / 群号 / 群名 精确搜索，结果分「联系人」「群聊」两组（对齐安卓 AddFriendScreen）
struct AddFriendView: View {
    /// 预填搜索词（数字串「添加好友」入口），不自动搜索
    var initialKeyword: String = ""

    @State private var keyword: String
    @State private var users: [SearchUser] = []
    @State private var groups: [SearchGroup] = []
    @State private var searching = false
    @State private var sent: Set<Int64> = []
    @State private var target: SearchUser?
    @State private var verifyMsg = "你好，我想加你为好友"
    @State private var toastText: String?

    init(initialKeyword: String = "") {
        self.initialKeyword = initialKeyword
        _keyword = State(initialValue: initialKeyword)
    }

    private var hasResult: Bool { !users.isEmpty || !groups.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if hasResult {
                resultList
            } else {
                Text("输入 AK号 / 邮箱 / 群号 / 群名，精确搜索")
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.horizontal, 40)
                    .padding(.top, 40)
                Spacer(minLength: 0)
            }
        }
        .background(AKColor.bg)
        .overlay(alignment: .bottom) { toastView }
        .reportsDetailPage()
        .navigationTitle("添加好友")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
        .navigationBarBackButtonHidden(true)
        .alert("发送好友申请", isPresented: Binding(
            get: { target != nil },
            set: { if !$0 { target = nil } }
        )) {
            TextField("验证消息", text: $verifyMsg)
            Button("取消", role: .cancel) { target = nil }
            Button("发送") {
                if let user = target { Task { await add(user) } }
            }
        } message: {
            if let user = target {
                Text("对方：\(user.nickname ?? "用户")")
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            TextField("AK号 / 邮箱 / 群号 / 群名", text: $keyword)
                .font(.system(size: 13.5))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { Task { await search() } }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Button {
                Task { await search() }
            } label: {
                Text(searching ? "搜索中" : "搜索")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(keyword.trimmingCharacters(in: .whitespaces).isEmpty ? AKColor.hint : AKColor.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .disabled(searching || keyword.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(12)
        .background(AKColor.card)
    }

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
        .background(AKColor.bg)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func rowView(_ row: AddFriendRow) -> some View {
        switch row {
        case .userHeader:
            Text("搜索到的联系人")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AKColor.muted)
                .padding(.leading, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)
        case .groupHeader:
            Text("搜索到的群聊")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AKColor.muted)
                .padding(.leading, 16)
                .padding(.top, 14)
                .padding(.bottom, 4)
        case .user(let user):
            userRow(user)
        case .group(let group):
            groupRow(group)
        }
    }

    private func userRow(_ user: SearchUser) -> some View {
        HStack(spacing: 12) {
            AvatarView(url: user.avatar, name: user.nickname ?? "用户", size: 46)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(user.nickname ?? "用户")
                        .font(.system(size: 15))
                        .foregroundColor(akNameColor(vipLevel: user.vipLevel,
                                                     isPretty: user.isPretty,
                                                     isGroup: false))
                        .lineLimit(1)
                    if user.isPretty == 1, !user.prettyNo.isEmpty {
                        Text("靓号：\(user.prettyNo)")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(Color(hex: 0xE5484D))
                    }
                    if user.vipLevel > 0 { VipBadge(level: user.vipLevel) }
                }
                Text("AK号 \(user.yxId ?? "")")
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if user.isFriend == 1 {
                Text("已是好友")
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.muted)
            } else if sent.contains(user.id) {
                Text("已申请")
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.muted)
            } else {
                Button {
                    verifyMsg = "你好，我想加你为好友"
                    target = user
                } label: {
                    Text("添加")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(AKColor.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func groupRow(_ group: SearchGroup) -> some View {
        if group.isMember == 1 {
            NavigationLink {
                GroupInfoView(groupId: group.id).restoresSwipeBack()
            } label: {
                groupRowContent(group)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                GroupPreviewView(groupId: group.id).restoresSwipeBack()
            } label: {
                groupRowContent(group)
            }
            .buttonStyle(.plain)
        }
    }

    private func groupRowContent(_ group: SearchGroup) -> some View {
        HStack(spacing: 12) {
            AvatarView(url: group.avatar, name: group.name, size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.system(size: 15))
                    .foregroundColor(AKColor.text)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text((group.isPretty == 1 ? "靓群号 " : "群号 ") + group.groupNo)
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.muted)
                        .lineLimit(1)
                    Text("\(group.memberCount) 人")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.muted)
                }
            }
            Spacer(minLength: 0)
            if group.isMember == 1 {
                Text("进入")
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.brand)
            } else {
                Text("加入")
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(AKColor.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - 数据

    private enum AddFriendRow: Identifiable {
        case userHeader
        case user(SearchUser)
        case groupHeader
        case group(SearchGroup)

        var id: String {
            switch self {
            case .userHeader: return "sec_user"
            case .groupHeader: return "sec_group"
            case .user(let u): return "u\(u.id)"
            case .group(let g): return "g\(g.id)"
            }
        }
    }

    private var resultRows: [AddFriendRow] {
        var rows: [AddFriendRow] = []
        if !users.isEmpty {
            rows.append(.userHeader)
            rows.append(contentsOf: users.map { AddFriendRow.user($0) })
        }
        if !groups.isEmpty {
            rows.append(.groupHeader)
            rows.append(contentsOf: groups.map { AddFriendRow.group($0) })
        }
        return rows
    }

    private func search() async {
        let kw = keyword.trimmingCharacters(in: .whitespaces)
        guard !kw.isEmpty else { return }
        searching = true
        defer { searching = false }
        do {
            let data = try await APIClient.shared.search(keyword: kw)
            users = data.users
            groups = data.groups
        } catch {
            users = []
            groups = []
            showToast(error.localizedDescription)
        }
    }

    private func add(_ user: SearchUser) async {
        let msg = verifyMsg.trimmingCharacters(in: .whitespaces)
        target = nil
        guard !msg.isEmpty else {
            showToast("请填写验证消息")
            return
        }
        do {
            _ = try await APIClient.shared.postRaw("api/v1/friends/add",
                                                   body: ["to_uid": user.id, "message": msg])
            sent.insert(user.id)
            showToast("好友申请已发送")
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
