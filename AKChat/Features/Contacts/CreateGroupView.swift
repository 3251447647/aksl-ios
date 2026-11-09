import SwiftUI

/// 发起群聊：群名称 / 群介绍 + 勾选成员，底部固定「创建群聊」（对齐安卓 CreateGroupScreen）
struct CreateGroupView: View {
    @EnvironmentObject private var app: AppState

    @State private var name = ""
    @State private var intro = ""
    @State private var selected: Set<Int64> = []
    @State private var creating = false
    @State private var toastText: String?
    @State private var created: CreateGroupResult?

    private var friends: [ContactFriend] { app.contacts?.friends ?? [] }
    private var canSubmit: Bool {
        !creating && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    editCard
                    memberHeader
                    memberList
                }
                .padding(.bottom, 16)
            }
            bottomBar
        }
        .background(AKColor.bg)
        .overlay(alignment: .bottom) { toastView }
        .navigationTitle("创建群聊")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
        .task { await app.loadContacts() }
        .background(
            NavigationLink(
                isActive: Binding(get: { created != nil }, set: { if !$0 { created = nil } }),
                destination: {
                    if let g = created {
                        ChatView(convType: "group", convId: g.id, title: g.name ?? name)
                    }
                },
                label: { EmptyView() }
            )
        )
    }

    private var editCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text("群名称")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AKColor.sub)
                Text(" *")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.red)
                Spacer()
                Text("\(name.count)/20")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.hint)
            }
            TextField("请输入群名称", text: $name)
                .font(.system(size: 14))
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(AKColor.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(AKColor.line, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onChange(of: name) { value in
                    if value.count > 20 { name = String(value.prefix(20)) }
                }
                .padding(.top, 6)

            HStack(spacing: 0) {
                Text("群简介")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AKColor.sub)
                Spacer()
                Text("\(intro.count)/200")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.hint)
            }
            .padding(.top, 14)

            TextField("介绍一下这个群吧…", text: $intro, axis: .vertical)
                .font(.system(size: 14))
                .lineLimit(3...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(minHeight: 78, alignment: .topLeading)
                .background(AKColor.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(AKColor.line, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onChange(of: intro) { value in
                    if value.count > 200 { intro = String(value.prefix(200)) }
                }
                .padding(.top, 6)
        }
        .padding(16)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    private var memberHeader: some View {
        HStack(spacing: 0) {
            Text("选择成员（可选，已选 \(selected.count)）")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AKColor.sub)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var memberList: some View {
        VStack(spacing: 0) {
            if friends.isEmpty {
                Text("还没有好友，先去添加好友吧")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.hint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 44)
            } else {
                ForEach(Array(friends.enumerated()), id: \.element.id) { idx, f in
                    friendRow(f)
                    if idx < friends.count - 1 {
                        Rectangle().fill(AKColor.line).frame(height: 0.6)
                    }
                }
            }
        }
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 12)
    }

    private func friendRow(_ f: ContactFriend) -> some View {
        let on = selected.contains(f.id)
        return Button {
            if on {
                selected.remove(f.id)
            } else {
                selected.insert(f.id)
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(on ? AKColor.brand : AKColor.line)
                        .frame(width: 20, height: 20)
                    if on {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                AvatarView(url: f.avatar, name: f.displayName, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(akNameColor(vipLevel: f.vipLevel, isPretty: 0, isGroup: false))
                        .lineLimit(1)
                    if let yx = f.yxId, !yx.isEmpty {
                        Text("AK号 \(yx)")
                            .font(.system(size: 11.5))
                            .foregroundColor(AKColor.hint)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var bottomBar: some View {
        Button {
            Task { await create() }
        } label: {
            Text(creating ? "创建中…" : "创建群聊")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(canSubmit ? .white : AKColor.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(canSubmit ? AKColor.brand : AKColor.line)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AKColor.card)
    }

    private func create() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            showToast("请输入群名称")
            return
        }
        creating = true
        defer { creating = false }
        do {
            let result = try await APIClient.shared.createGroup(
                name: trimmed,
                intro: intro.trimmingCharacters(in: .whitespaces),
                members: Array(selected)
            )
            created = result
            await app.refreshConversations()
            await app.loadContacts()
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
                    .padding(.bottom, 90)
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
