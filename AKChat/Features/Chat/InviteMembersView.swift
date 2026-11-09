import SwiftUI

/// 邀请好友入群：搜索 + 多选 + 底部「邀请 N 人」
/// 行高、头像与搜索框尺寸对齐安卓 InviteFriendsScreen.kt
struct InviteMembersView: View {
    let groupId: Int64

    @Environment(\.dismiss) private var dismiss
    @State private var list: [InvitableFriend] = []
    @State private var canInvite = 1
    @State private var keyword = ""
    @State private var selected: Set<Int64> = []
    @State private var loading = true
    @State private var sending = false
    @State private var groupName = ""

    private var shown: [InvitableFriend] {
        let k = keyword.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty else { return list }
        return list.filter {
            ($0.name ?? "").range(of: k, options: .caseInsensitive) != nil
                || ($0.nickname ?? "").range(of: k, options: .caseInsensitive) != nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if canInvite == 1 {
                searchBar
            }

            if canInvite == 0 {
                hint("群主已关闭成员邀请，暂无邀请权限")
            } else if loading && list.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                Spacer(minLength: 0)
            } else if list.isEmpty {
                hint("没有可邀请的好友了")
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(shown.enumerated()), id: \.element.id) { idx, f in
                            friendRow(f)
                            if idx < shown.count - 1 {
                                Rectangle()
                                    .fill(AKColor.line)
                                    .frame(height: 0.6)
                                    .padding(.leading, 76)
                            }
                        }
                    }
                    .background(AKColor.card)
                }
                Spacer(minLength: 0)
                bottomBar
            }
        }
        .background(AKColor.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("邀请好友")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AKColor.text)
                    if !groupName.isEmpty {
                        Text(groupName)
                            .font(.system(size: 10.5))
                            .foregroundColor(AKColor.hint)
                            .lineLimit(1)
                    }
                }
            }
        }
        .task { await load() }
    }

    private var searchBar: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundColor(AKColor.hint)
            TextField("搜索好友昵称 / AK号", text: $keyword)
                .font(.system(size: 13.5))
                .foregroundColor(AKColor.text)
                .autocorrectionDisabled()
            if !keyword.isEmpty {
                Button {
                    keyword = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AKColor.placeholder)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 38)
        .background(AKColor.fill)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(AKColor.card)
    }

    private func hint(_ text: String) -> some View {
        VStack {
            Spacer(minLength: 0)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(AKColor.hint)
                .multilineTextAlignment(.center)
                .padding(24)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func friendRow(_ f: InvitableFriend) -> some View {
        let checked = selected.contains(f.id)
        return Button {
            if checked { selected.remove(f.id) } else { selected.insert(f.id) }
        } label: {
            HStack(spacing: 11) {
                ZStack {
                    Circle()
                        .fill(checked ? AKColor.brand : AKColor.line)
                        .frame(width: 20, height: 20)
                    if checked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .fill(AKColor.card)
                            .frame(width: 17, height: 17)
                    }
                }
                AvatarView(url: f.avatar, name: f.displayName, size: 40)
                Text(f.displayName)
                    .font(.system(size: 15))
                    .foregroundColor(AKColor.text)
                    .lineLimit(1)
                Spacer(minLength: 6)
            }
            .padding(.horizontal, 16)
            .frame(height: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Text("已选 \(selected.count) 人")
                .font(.system(size: 13))
                .foregroundColor(AKColor.sub)
            Spacer(minLength: 6)
            Button {
                Task { await invite() }
            } label: {
                Text(selected.isEmpty ? "邀请" : "邀请 \(selected.count) 人")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .frame(height: 38)
                    .background(selected.isEmpty ? AKColor.line : AKColor.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(selected.isEmpty || sending)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AKColor.card)
    }

    private func load() async {
        loading = true
        defer { loading = false }
        if let data = try? await APIClient.shared.invitable(gid: groupId) {
            list = data.list
            canInvite = data.canInvite
        }
        if let info = try? await APIClient.shared.groupInfo(id: groupId) {
            groupName = info.name ?? ""
        }
    }

    private func invite() async {
        sending = true
        defer { sending = false }
        await APIClient.shared.inviteMembers(gid: groupId, uids: Array(selected))
        dismiss()
    }
}
