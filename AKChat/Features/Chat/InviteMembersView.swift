import SwiftUI

/// 邀请好友入群：可搜索、多选，底部「邀请 N 人」（对齐安卓 InviteFriendsScreen）
struct InviteMembersView: View {
    let groupId: Int64

    @Environment(\.dismiss) private var dismiss
    @State private var list: [InvitableFriend] = []
    @State private var canInvite = 1
    @State private var keyword = ""
    @State private var selected: Set<Int64> = []
    @State private var loading = true
    @State private var sending = false

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
            List {
                if canInvite == 1 {
                    searchRow
                }

                if canInvite == 0 {
                    Text("群主已关闭成员邀请，暂无邀请权限")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.hint)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else if list.isEmpty {
                    Text("没有可邀请的好友了")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.hint)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(shown) { f in
                        friendRow(f)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AKColor.bg.ignoresSafeArea())

            if canInvite == 1 && !list.isEmpty {
                bottomBar
            }
        }
        .background(AKColor.bg.ignoresSafeArea())
        .navigationTitle("邀请好友")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var searchRow: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(AKColor.hint)
            TextField("搜索好友昵称", text: $keyword)
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
        .frame(height: 36)
        .background(AKColor.fill)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(AKColor.card)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func friendRow(_ f: InvitableFriend) -> some View {
        let checked = selected.contains(f.id)
        return VStack(spacing: 0) {
            Button {
                if checked { selected.remove(f.id) } else { selected.insert(f.id) }
            } label: {
                HStack(spacing: 11) {
                    ZStack {
                        Circle()
                            .fill(checked ? AKColor.brand : AKColor.card)
                            .frame(width: 20, height: 20)
                        if checked {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Circle()
                                .strokeBorder(AKColor.line, lineWidth: 1)
                                .frame(width: 20, height: 20)
                        }
                    }
                    AvatarView(url: f.avatar, name: f.displayName, size: 40)
                    Text(f.displayName)
                        .font(.system(size: 14.5))
                        .foregroundColor(AKColor.text)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(AKColor.line)
                .frame(height: 0.5)
                .padding(.leading, 76)
        }
        .background(AKColor.card)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Text("已选 \(selected.count) 人")
                .font(.system(size: 13))
                .foregroundColor(AKColor.sub)
            Spacer(minLength: 0)
            Button {
                Task { await invite() }
            } label: {
                Text(selected.isEmpty ? "邀请" : "邀请 \(selected.count) 人")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .frame(height: 36)
                    .background(selected.isEmpty ? AKColor.line : AKColor.brand)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(selected.isEmpty || sending)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AKColor.card)
        .overlay(alignment: .top) {
            Rectangle().fill(AKColor.line).frame(height: 0.5)
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        if let data = try? await APIClient.shared.invitable(gid: groupId) {
            list = data.list
            canInvite = data.canInvite
        }
    }

    private func invite() async {
        sending = true
        defer { sending = false }
        await APIClient.shared.inviteMembers(gid: groupId, uids: Array(selected))
        dismiss()
    }
}
