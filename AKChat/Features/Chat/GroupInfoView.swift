import SwiftUI
import PhotosUI

/// 群资料（聊天信息）：卡片式，成员宫格 + 群信息 + 聊天设置 + 退出（对齐安卓 GroupProfileScreen）
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

    private var isOwner: Bool { (info?.myRole ?? 0) == 1 }
    private var isManager: Bool { isOwner || (info?.myRole ?? 0) == 2 }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let info {
                    memberCard(info)
                    infoCard(info)
                    chatCard(info)
                    if !isOwner {
                        leaveButton
                    }
                } else if loading {
                    ProgressView().padding(.top, 40)
                } else if let errorText {
                    Text(errorText).font(.system(size: 13)).foregroundColor(AKColor.red).padding(.top, 20)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .navigationTitle("聊天信息")
        .navigationBarTitleDisplayMode(.inline)
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
        }
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

    // MARK: - 群成员

    private func memberCard(_ g: GroupInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("群成员").font(.system(size: 14.5, weight: .medium)).foregroundColor(AKColor.text)
                Spacer()
                Text("\(g.memberCount) 人").font(.system(size: 12)).foregroundColor(AKColor.hint)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 12) {
                ForEach(g.members.prefix(15)) { m in
                    NavigationLink {
                        UserProfileView(uid: m.uid)
                    } label: {
                        VStack(spacing: 4) {
                            AvatarView(url: m.avatar, name: m.name ?? "成员", size: 44)
                            Text(m.name ?? "成员")
                                .font(.system(size: 10))
                                .foregroundColor(AKColor.muted)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
                if g.allowInvite == 1 {
                    NavigationLink {
                        InviteMembersView(groupId: groupId)
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(AKColor.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "plus")
                                    .font(.system(size: 16))
                                    .foregroundColor(AKColor.hint)
                            }
                            Text("邀请").font(.system(size: 10)).foregroundColor(AKColor.hint)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            NavigationLink {
                GroupMembersView(groupId: groupId, myRole: g.myRole, myUid: app.user?.id ?? 0)
            } label: {
                HStack {
                    Text("查看全部群成员").font(.system(size: 13)).foregroundColor(AKColor.sub)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(AKColor.hint)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 群信息

    private func infoCard(_ g: GroupInfo) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                AvatarView(url: g.avatar, name: g.name ?? "群聊", size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(g.name ?? "群聊").font(.system(size: 15, weight: .medium)).foregroundColor(AKColor.text).lineLimit(1)
                        if g.isPretty == 1, !g.displayNo.isEmpty {
                            PrettyBadge(number: g.displayNo, isGroup: true)
                        }
                    }
                    Text("群号 \(g.displayNo)").font(.system(size: 12)).foregroundColor(AKColor.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(height: 66)

            divider
            NavigationLink { GroupQRCodeView(groupId: groupId) } label: {
                row("群二维码", "qrcode")
            }
            .buttonStyle(.plain)

            divider
            NavigationLink { GroupNoticesView(groupId: groupId) } label: {
                HStack(spacing: 10) {
                    Text("群公告").font(.system(size: 14.5)).foregroundColor(AKColor.text)
                    Spacer()
                    Text((g.notice ?? "").isEmpty ? "未设置" : (g.notice ?? "").replacingOccurrences(of: "\n", with: " "))
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.hint)
                        .lineLimit(1)
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(AKColor.hint)
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
            }
            .buttonStyle(.plain)

            if isManager {
                divider
                NavigationLink {
                    GroupMembersView(groupId: groupId, myRole: g.myRole, myUid: app.user?.id ?? 0)
                } label: {
                    row("群管理", "person.badge.shield.checkmark")
                }
                .buttonStyle(.plain)
            }

            divider
            NavigationLink { LiveRoomView(gid: groupId) } label: {
                row("群直播", "dot.radiowaves.left.and.right")
            }
            .buttonStyle(.plain)

            divider
            NavigationLink { GroupCallView(gid: groupId, callType: 1) } label: {
                row("群语音通话", "phone")
            }
            .buttonStyle(.plain)
        }
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 聊天设置

    private func chatCard(_ g: GroupInfo) -> some View {
        VStack(spacing: 0) {
            NavigationLink {
                MessageSearchView(scopeType: "group", scopeId: groupId, scopeTitle: g.name ?? "群聊")
            } label: {
                HStack(spacing: 10) {
                    Text("查找聊天记录").font(.system(size: 14.5)).foregroundColor(AKColor.text)
                    Spacer()
                    Text("图片、视频、文件等").font(.system(size: 12)).foregroundColor(AKColor.hint)
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(AKColor.hint)
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
            }
            .buttonStyle(.plain)

            divider
                Button {
                    nickDraft = g.myNickname
                    showNick = true
                } label: {
                    HStack(spacing: 10) {
                        Text("我在本群的昵称").font(.system(size: 14.5)).foregroundColor(AKColor.text)
                        Spacer()
                        Text(g.myNickname.isEmpty ? "未设置" : g.myNickname)
                            .font(.system(size: 12))
                            .foregroundColor(AKColor.hint)
                        Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(AKColor.hint)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                }
                .buttonStyle(.plain)

            if isOwner {
                divider
                Button {
                    showBgPicker = true
                } label: {
                    HStack(spacing: 10) {
                        Text("聊天背景").font(.system(size: 14.5)).foregroundColor(AKColor.text)
                        Spacer()
                        Text(chatBg.isEmpty ? "默认" : "已设置")
                            .font(.system(size: 12))
                            .foregroundColor(chatBg.isEmpty ? AKColor.hint : AKColor.brand)
                        Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(AKColor.hint)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                }
                .buttonStyle(.plain)
                if !chatBg.isEmpty {
                    divider
                    Button {
                        Task { await clearBg() }
                    } label: {
                        HStack {
                            Text("恢复默认背景").font(.system(size: 14.5)).foregroundColor(AKColor.text)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 50)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var leaveButton: some View {
        Button {
            confirmLeave = true
        } label: {
            Text("退出群聊")
                .font(.system(size: 15))
                .foregroundColor(AKColor.red)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AKColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func row(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 10) {
            Text(title).font(.system(size: 14.5)).foregroundColor(AKColor.text)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(AKColor.hint)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .contentShape(Rectangle())
    }

    private var divider: some View {
        Rectangle().fill(AKColor.line).frame(height: 0.5).padding(.leading, 14)
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
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func saveNick() async {
        do {
            try await APIClient.shared.setGroupMyNickname(
                gid: groupId, userId: app.user?.id ?? 0, nickname: nickDraft.trimmingCharacters(in: .whitespaces)
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
