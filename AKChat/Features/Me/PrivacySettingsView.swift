import SwiftUI

/// 隐私设置：好友 / 群聊 / 黑名单 / 危险操作 分组卡（对齐安卓 PrivacyScreen）
struct PrivacySettingsView: View {
    @EnvironmentObject private var app: AppState
    @State private var settings: PrivacySettings?
    @State private var loading = true
    @State private var error: String?
    @State private var saving = false
    @State private var showDelete = false

    var body: some View {
        List {
            if loading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                sectionTitle("好友隐私")
                    .listRowInsets(EdgeInsets(top: 12, leading: 14, bottom: 8, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                VStack(spacing: 0) {
                    switchRow(title: "允许任何人添加我为好友",
                              desc: "关闭后，别人无法向你发送好友申请",
                              isOn: settings?.allowFriendRequest ?? 1,
                              key: "allow_friend_request")
                    divider(start: 16)
                    switchRow(title: "添加好友无需验证",
                              desc: "开启后，别人添加你会直接成为好友，不再发送好友申请",
                              isOn: settings?.autoAcceptFriend ?? 0,
                              key: "auto_accept_friend")
                }
                .akCardRow(top: true, bottom: true, radius: 16)
                .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 16, trailing: 14))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                sectionTitle("群聊隐私")
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 8, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                VStack(spacing: 0) {
                    switchRow(title: "允许任何人邀请我加入群聊",
                              desc: "关闭后，别人邀请你需要你同意才能进群",
                              isOn: settings?.allowGroupInvite ?? 1,
                              key: "allow_group_invite")
                }
                .akCardRow(top: true, bottom: true, radius: 16)
                .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 16, trailing: 14))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                sectionTitle("隐私")
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 8, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                NavigationLink {
                    BlacklistView()
                } label: {
                    linkRow(title: "黑名单管理",
                            desc: "被拉黑的人无法给你发消息、看你的动态，也无法加你为好友")
                }
                .buttonStyle(.plain)
                .akCardRow(top: true, bottom: true, radius: 16)
                .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 16, trailing: 14))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                sectionTitle("危险操作")
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 8, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                Button {
                    showDelete = true
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("注销账号")
                                .font(.system(size: 15))
                                .foregroundColor(AKColor.red)
                            Text("永久删除账号及全部数据，靓号将回收")
                                .font(.system(size: 11.5))
                                .foregroundColor(AKColor.hint)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15))
                            .foregroundColor(AKColor.placeholder)
                    }
                    .padding(16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .akCardRow(top: true, bottom: true, radius: 16)
                .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 24, trailing: 14))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                if let error {
                    Text(error)
                        .font(.system(size: 12.5))
                        .foregroundColor(AKColor.red)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 16, trailing: 14))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AKColor.bg.ignoresSafeArea())
        .navigationTitle("隐私设置")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("注销账号", isPresented: $showDelete) {
            Button("返回", role: .cancel) {}
            Button("确认注销", role: .destructive) {
                Task {
                    await APIClient.shared.deleteAccount()
                    app.logout()
                }
            }
        } message: {
            Text("注销后，以下数据将被永久删除且无法恢复：\n• 个人资料、头像、简介将被清空，昵称统一显示为「已注销账号」\n• 账号名与手机号将被释放\n• 你会退出所有群聊，其他用户也无法再给你发送消息\n• 聊天记录会保留（对方仍可查看历史消息）\n• 靓号将被回收，其他用户可以重新获取\n• 当前这个账号本身将无法再次登录\n注销不可撤销")
        }
    }

    // MARK: - 组件

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12.5))
            .foregroundColor(AKColor.muted)
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func divider(start: CGFloat) -> some View {
        Rectangle()
            .fill(AKColor.line)
            .frame(height: 0.5)
            .padding(.leading, start)
    }

    private func switchRow(title: String, desc: String, isOn: Int, key: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(AKColor.text)
                Text(desc)
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.hint)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(
                get: { isOn == 1 },
                set: { newValue in
                    Task { await update(key: key, value: newValue) }
                }
            ))
            .labelsHidden()
            .tint(AKColor.brand)
            .disabled(saving)
        }
        .padding(16)
    }

    private func linkRow(title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(AKColor.text)
                Text(desc)
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.hint)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 15))
                .foregroundColor(AKColor.placeholder)
        }
        .padding(16)
        .contentShape(Rectangle())
    }

    // MARK: - 数据

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            settings = try await APIClient.shared.privacy()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func update(key: String, value: Bool) async {
        guard let current = settings else { return }
        saving = true
        defer { saving = false }
        var friend = current.allowFriendRequest
        var invite = current.allowGroupInvite
        var auto = current.autoAcceptFriend
        if key == "allow_friend_request" { friend = value ? 1 : 0 }
        if key == "allow_group_invite" { invite = value ? 1 : 0 }
        if key == "auto_accept_friend" { auto = value ? 1 : 0 }
        settings = PrivacySettings(allowFriendRequest: friend, allowGroupInvite: invite,
                                   autoAcceptFriend: auto, hasPayPassword: current.hasPayPassword)
        do {
            try await APIClient.shared.setPrivacy(key: key, value: value)
            error = nil
        } catch {
            self.error = error.localizedDescription
            await load()
        }
    }
}

extension PrivacySettings {
    init(allowFriendRequest: Int, allowGroupInvite: Int, autoAcceptFriend: Int, hasPayPassword: Int) {
        self.allowFriendRequest = allowFriendRequest
        self.allowGroupInvite = allowGroupInvite
        self.autoAcceptFriend = autoAcceptFriend
        self.hasPayPassword = hasPayPassword
    }
}

struct ChangePasswordView: View {
    let type: String

    @State private var old = ""
    @State private var new = ""
    @State private var confirm = ""
    @State private var error: String?
    @State private var info: String?
    @State private var saving = false
    @Environment(\.dismiss) private var dismiss

    private var isPay: Bool { type == "pay" }

    var body: some View {
        List {
            inputRow(SecureField(isPay && old.isEmpty ? "支付密码" : "原密码", text: $old))
            divider
            inputRow(SecureField(isPay ? "新支付密码（4-8 位数字）" : "新密码（6-32 位）", text: $new))
            divider
            inputRow(SecureField("确认新密码", text: $confirm))

            Text(isPay ? "支付密码用于红包、转账和礼物，请与登录密码不同。" : "修改成功后其他设备会被要求重新登录。")
                .font(.system(size: 12))
                .foregroundColor(AKColor.muted)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 12, trailing: 14))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if let error {
                Text(error)
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.red)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 12, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            if let info {
                Text(info)
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.brand)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 12, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            Button {
                Task { await submit() }
            } label: {
                Text(saving ? "保存中…" : "保存")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        LinearGradient(colors: [Color(hex: 0x43C463), Color(hex: 0x2FA84F)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(saving)
            .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 24, trailing: 14))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AKColor.bg.ignoresSafeArea())
        .navigationTitle(isPay ? "支付密码" : "登录密码")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var divider: some View {
        Rectangle()
            .fill(AKColor.line)
            .frame(height: 0.5)
            .padding(.leading, 16)
            .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    private func inputRow<F: View>(_ field: F) -> some View {
        field
            .font(.system(size: 15))
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .akCardRow()
            .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    private func submit() async {
        error = nil
        info = nil
        guard !old.isEmpty else {
            error = "请输入原密码"
            return
        }
        if isPay {
            guard new.range(of: "^[0-9]{4,8}$", options: .regularExpression) != nil else {
                error = "支付密码需为 4-8 位数字"
                return
            }
        } else {
            guard new.count >= 6 && new.count <= 32 else {
                error = "新密码需为 6-32 位"
                return
            }
        }
        guard new == confirm else {
            error = "两次输入不一致"
            return
        }
        saving = true
        defer { saving = false }
        do {
            try await APIClient.shared.changePassword(type: type, old: old, new: new)
            info = "修改成功"
            old = ""
            new = ""
            confirm = ""
        } catch {
            self.error = error.localizedDescription
        }
    }
}
