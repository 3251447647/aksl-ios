import SwiftUI
import PhotosUI

/// 群资料（聊天信息）：群成员宫格 → 群名/群号 → 群二维码 / 群公告 / 群管理 / 群直播 / 群语音通话
/// → 查找聊天记录 / 我在本群的昵称 / 聊天背景（群主）→ 退出群聊
/// 顺序与文案对齐安卓 GroupProfileScreen.kt；行高 50、卡片圆角 12、分隔线缩进 14
struct GroupInfoView: View {
    let groupId: Int64
    var onLeft: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppState
    @State private var info: GroupInfo?
    @State private var loading = true
    @State private var errorText: String?
    @State private var confirmLeave = false
    @State private var chatBg: String = ""
    @State private var showBgPicker = false
    @State private var bgItem: PhotosPickerItem?
    @State private var showNick = false
    @State private var nickDraft = ""
    @State private var noticePending = false

    private var isOwner: Bool { (info?.myRole ?? 0) == 1 }
    private var isManager: Bool { isOwner || (info?.myRole ?? 0) == 2 }
    private var myUid: Int64 { app.user?.id ?? 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let g = info {
                    if g.isBanned == 1 { bannedBar(g) }
                    membersCard(g)
                    nameCard(g)
                    linkCard(g)
                    chatCard(g)
                    if !isOwner { leaveCard }
                } else if loading {
                    ProgressView().padding(.top, 60)
                } else if let errorText {
                    Text(errorText)
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.red)
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .navigationTitle("聊天信息")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { BackButton() }
        }
        .task { await load() }
        .refreshable { await load() }
        .photosPicker(isPresented: $showBgPicker, selection: $bgItem, matching: .images)
        .onChange(of: bgItem) { item in
            guard let item else { return }
            Task {
                defer { bgItem = nil }
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else { return }
                    let up = try await APIClient.shared.upload(data: data, filename: "bg.jpg", kind: "bg")
                    let r = try await APIClient.shared.setChatBg(convType: "group", convId: groupId, url: up.url)
                    await MainActor.run { chatBg = r.bg ?? "" }
                } catch {
                    await MainActor.run { errorText = error.localizedDescription }
                }
            }
        }
        .alert("修改我在本群的昵称", isPresented: $showNick) {
            TextField("留空则使用昵称", text: $nickDraft)
            Button("取消", role: .cancel) {}
            Button("保存") { Task { await saveNick() } }
        } message: {
            Text("群昵称只在本群内显示。")
        }
        .alert("退出群聊", isPresented: $confirmLeave) {
            Button("取消", role: .cancel) {}
            Button("退出群聊", role: .destructive) {
                Task {
                    await APIClient.shared.quitGroup(id: groupId)
                    onLeft?()
                    dismiss()
                }
            }
        } message: {
            Text("退出后将不再接收「\(info?.name ?? "")」的消息，聊天记录会一并清除。确定退出吗？")
        }
    }

    // MARK: - 封禁提示

    private func bannedBar(_ g: GroupInfo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("该群已被封禁")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(hex: 0xD92D20))
            Text("群内所有成员（包括群主）均无法发送消息，如有疑问请联系在线客服处理"
                 + ((g.banReason ?? "").isEmpty ? "" : "。封禁原因：\(g.banReason ?? "")"))
                .font(.system(size: 12))
                .foregroundColor(AKColor.red)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(AKColor.redSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 群成员宫格

    private func membersCard(_ g: GroupInfo) -> some View {
        let canInvite = g.allowInvite == 1
        let shown = Array(g.members.prefix(15))
        return card {
            NavigationLink {
                GroupMembersView(groupId: groupId, myRole: g.myRole, myUid: myUid)
            } label: {
                HStack(spacing: 6) {
                    Text("群成员")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AKColor.text)
                    Spacer(minLength: 6)
                    Text(g.maxMember > 0 ? "\(g.memberCount)/\(g.maxMember)" : "\(g.memberCount) 人")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.hint)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.placeholder)
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(spacing: 14) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 14) {
                    ForEach(shown) { m in
                        NavigationLink {
                            UserProfileView(uid: m.uid)
                        } label: {
                            memberCell(m)
                        }
                        .buttonStyle(.plain)
                    }
                    if canInvite {
                        NavigationLink {
                            InviteMembersView(groupId: groupId)
                        } label: {
                            inviteCell(enabled: true)
                        }
                        .buttonStyle(.plain)
                    } else {
                        inviteCell(enabled: false)
                    }
                }
                if !canInvite {
                    Text("群主已关闭成员邀请，暂无邀请权限")
                        .font(.system(size: 11))
                        .foregroundColor(AKColor.hint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
    }

    private func memberCell(_ m: GroupMember) -> some View {
        VStack(spacing: 5) {
            AvatarView(url: m.avatar, name: m.name ?? "成员", size: 48)
            Text(m.name ?? "成员")
                .font(.system(size: 10.5))
                .foregroundColor(akNameColor(vipLevel: m.vipLevel, isPretty: m.isPretty, isGroup: false))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity)
    }

    private func inviteCell(enabled: Bool) -> some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous).fill(AKColor.fill)
                RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(AKColor.line, lineWidth: 1)
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(enabled ? AKColor.muted : AKColor.placeholder)
            }
            .frame(width: 48, height: 48)
            Text("邀请")
                .font(.system(size: 10.5))
                .foregroundColor(enabled ? AKColor.hint : AKColor.placeholder)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 群名 / 群号

    private func nameCard(_ g: GroupInfo) -> some View {
        HStack(spacing: 14) {
            AvatarView(url: g.avatar, name: g.name ?? "群聊", size: 56)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(g.name ?? "群聊")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AKColor.text)
                        .lineLimit(1)
                    if g.isPretty == 1, !(g.prettyGroupNo ?? "").isEmpty {
                        PrettyBadge(number: g.prettyGroupNo ?? "", isGroup: true)
                    }
                    NavigationLink {
                        GroupQRCodeView(groupId: groupId)
                    } label: {
                        Image(systemName: "qrcode")
                            .font(.system(size: 11))
                            .foregroundColor(AKColor.sub)
                            .frame(width: 22, height: 22)
                            .background(AKColor.fill)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                Text("群号：\(groupNoText(g))")
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.hint)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func groupNoText(_ g: GroupInfo) -> String {
        if let no = g.groupNo, !no.isEmpty { return no }
        return String(g.id)
    }

    // MARK: - 群二维码 / 群公告 / 群管理 / 群直播 / 群语音

    private func linkCard(_ g: GroupInfo) -> some View {
        card {
            NavigationLink { GroupQRCodeView(groupId: groupId) } label: {
                row("群二维码")
            }
            .buttonStyle(.plain)

            divider

            NavigationLink { GroupNoticesView(groupId: groupId) } label: {
                noticeRow(g)
            }
            .buttonStyle(.plain)

            if isManager {
                divider
                NavigationLink {
                    GroupMembersView(groupId: groupId, myRole: g.myRole, myUid: myUid)
                } label: {
                    row("群管理")
                }
                .buttonStyle(.plain)
            }

            divider
            NavigationLink { LiveRoomView(gid: groupId) } label: {
                row("群直播")
            }
            .buttonStyle(.plain)

            divider
            NavigationLink { GroupCallView(gid: groupId, callType: 1) } label: {
                row("群语音通话")
            }
            .buttonStyle(.plain)
        }
    }

    private func noticeRow(_ g: GroupInfo) -> some View {
        HStack(alignment: .top, spacing: 8) {
            HStack(spacing: 6) {
                Text("群公告")
                    .font(.system(size: 15))
                    .foregroundColor(AKColor.text)
                if noticePending {
                    Circle()
                        .fill(AKColor.red)
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.top, 1)
            Spacer(minLength: 8)
            Text((g.notice ?? "").isEmpty ? "未设置" : (g.notice ?? ""))
                .font(.system(size: 13))
                .foregroundColor(AKColor.hint)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .frame(maxWidth: 210, alignment: .trailing)
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(AKColor.placeholder)
                .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(minHeight: 50)
        .contentShape(Rectangle())
    }

    // MARK: - 聊天设置

    private func chatCard(_ g: GroupInfo) -> some View {
        card {
            NavigationLink {
                MessageSearchView(scopeType: "group", scopeId: groupId, scopeTitle: g.name ?? "群聊")
            } label: {
                row("查找聊天记录", value: "图片、视频、文件等")
            }
            .buttonStyle(.plain)

            divider

            Button {
                nickDraft = g.myNickname
                showNick = true
            } label: {
                row("我在本群的昵称", value: g.myNickname.isEmpty ? "未设置" : g.myNickname)
            }
            .buttonStyle(.plain)

            if isOwner {
                divider
                Button {
                    showBgPicker = true
                } label: {
                    row("聊天背景", value: chatBg.isEmpty ? "默认" : "已设置",
                        valueColor: chatBg.isEmpty ? AKColor.hint : AKColor.brand)
                }
                .buttonStyle(.plain)

                if !chatBg.isEmpty {
                    divider
                    Button {
                        Task { await clearBg() }
                    } label: {
                        row("恢复默认背景")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var leaveCard: some View {
        card {
            Button {
                confirmLeave = true
            } label: {
                HStack {
                    Text("退出群聊")
                        .font(.system(size: 15))
                        .foregroundColor(AKColor.red)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 基础件

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AKColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func row(_ title: String, value: String? = nil, valueColor: Color = AKColor.hint) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(AKColor.text)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.system(size: 13))
                    .foregroundColor(valueColor)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(AKColor.placeholder)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .contentShape(Rectangle())
    }

    private var divider: some View {
        Rectangle()
            .fill(AKColor.line)
            .frame(height: 0.5)
            .padding(.leading, 14)
    }

    // MARK: - 数据

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            info = try await APIClient.shared.groupInfo(id: groupId)
            if let bg = try? await APIClient.shared.chatBg(convType: "group", convId: groupId) {
                chatBg = bg.bg ?? ""
            }
            noticePending = (await APIClient.shared.pendingGroupNotice(gid: groupId)) != nil
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func saveNick() async {
        do {
            try await APIClient.shared.setGroupMyNickname(
                gid: groupId, userId: myUid, nickname: nickDraft.trimmingCharacters(in: .whitespaces)
            )
            await load()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func clearBg() async {
        _ = try? await APIClient.shared.setChatBg(convType: "group", convId: groupId, url: "")
        chatBg = ""
    }
}
