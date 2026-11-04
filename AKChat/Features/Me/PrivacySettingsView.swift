import SwiftUI

struct PrivacySettingsView: View {
    @State private var settings: PrivacySettings?
    @State private var loading = true
    @State private var error: String?
    @State private var saving = false

    var body: some View {
        Form {
            if loading {
                ProgressView()
            } else {
                Section {
                    toggleRow("允许通过 AK号搜到我", key: "allow_friend_request", value: settings?.allowFriendRequest ?? 1)
                    toggleRow("允许被邀请进群", key: "allow_group_invite", value: settings?.allowGroupInvite ?? 1)
                    toggleRow("自动通过好友申请", key: "auto_accept_friend", value: settings?.autoAcceptFriend ?? 0)
                } footer: {
                    Text("关闭后其他人无法搜索到你、也不能把你拉进群；已在群里的不受影响。")
                }

                Section("账号安全") {
                    NavigationLink("修改登录密码") {
                        ChangePasswordView(type: "login")
                    }
                    NavigationLink((settings?.hasPayPassword ?? 0) == 1 ? "修改支付密码" : "设置支付密码") {
                        ChangePasswordView(type: "pay")
                    }
                }

                if let error {
                    Section {
                        Text(error).font(.system(size: 12)).foregroundColor(AKColor.red)
                    }
                }
            }
        }
        .navigationTitle("隐私与安全")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func toggleRow(_ title: String, key: String, value: Int) -> some View {
        Toggle(title, isOn: Binding(
            get: { value == 1 },
            set: { newValue in
                Task { await update(key: key, value: newValue) }
            }
        ))
        .disabled(saving)
    }

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
        Form {
            Section {
                SecureField(isPay && old.isEmpty ? "支付密码" : "原密码", text: $old)
                SecureField(isPay ? "新支付密码（4-8 位数字）" : "新密码（6-32 位）", text: $new)
                SecureField("确认新密码", text: $confirm)
            } footer: {
                Text(isPay ? "支付密码用于红包、转账和礼物，请与登录密码不同。" : "修改成功后其他设备会被要求重新登录。")
            }

            if let error {
                Section { Text(error).font(.system(size: 12)).foregroundColor(AKColor.red) }
            }
            if let info {
                Section { Text(info).font(.system(size: 12)).foregroundColor(AKColor.brand) }
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    Text(saving ? "保存中…" : "保存")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(saving ? AKColor.muted : AKColor.brand)
                }
                .disabled(saving)
            }
        }
        .navigationTitle(isPay ? "支付密码" : "登录密码")
        .navigationBarTitleDisplayMode(.inline)
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
