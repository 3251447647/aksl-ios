import SwiftUI
import UIKit

struct RegisterView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var nickname = ""
    @State private var email = ""
    @State private var code = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var invite = ""
    @State private var agreed = false
    @State private var countdown = 0
    @State private var info: String?
    @State private var error: String?
    @State private var sending = false

    private var canSubmit: Bool {
        !nickname.isEmpty && !email.isEmpty && !code.isEmpty &&
        !password.isEmpty && agreed && !sending && !app.loading
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(spacing: 12) {
                        field(icon: "person.fill", placeholder: "昵称（2-20 个字符）", text: $nickname)
                        field(icon: "envelope.fill", placeholder: "邮箱", text: $email, keyboard: .emailAddress)
                        HStack(spacing: 8) {
                            field(icon: "number", placeholder: "6 位邮箱验证码", text: $code, keyboard: .numberPad)
                            Button {
                                Task { await requestCode() }
                            } label: {
                                Text(countdown > 0 ? "\(countdown)s" : "获取验证码")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(countdown > 0 ? AKColor.muted : AKColor.brand)
                                    .frame(width: 92, height: 46)
                                    .background(AKColor.fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .disabled(countdown > 0 || email.isEmpty || sending)
                        }
                        field(icon: "lock.fill", placeholder: "密码（6-32 位）", text: $password, secure: true)
                        field(icon: "lock.rotation", placeholder: "确认密码", text: $confirm, secure: true)
                        field(icon: "ticket.fill", placeholder: "邀请码（选填）", text: $invite)
                    }
                    .padding(16)
                    .background(AKColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if let info {
                        Text(info).font(.system(size: 12)).foregroundColor(AKColor.sub)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let error {
                        Text(error).font(.system(size: 12)).foregroundColor(AKColor.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let err = app.errorText, !err.isEmpty {
                        Text(err).font(.system(size: 12)).foregroundColor(AKColor.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        agreed.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: agreed ? "checkmark.square.fill" : "square")
                                .foregroundColor(agreed ? AKColor.brand : AKColor.muted)
                            Text("我已阅读并同意《用户协议》与《隐私政策》")
                                .font(.system(size: 12))
                                .foregroundColor(AKColor.sub)
                            Spacer(minLength: 0)
                        }
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(canSubmit ? AKColor.brand : AKColor.placeholder)
                            if app.loading || sending {
                                ProgressView().tint(.white)
                            } else {
                                Text("注册并登录")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(height: 50)
                    }
                    .disabled(!canSubmit)
                }
                .padding(16)
            }
            .background(AKColor.bg)
            .reportsDetailPage()
            .navigationTitle("注册账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear { app.errorText = nil }
        }
    }

    private func field(icon: String, placeholder: String, text: Binding<String>,
                       secure: Bool = false, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(AKColor.muted)
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(keyboard)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(AKColor.fill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func requestCode() async {
        let mail = email.trimmingCharacters(in: .whitespaces)
        guard !mail.isEmpty, countdown == 0 else { return }
        sending = true
        info = nil
        error = nil
        defer { sending = false }
        do {
            info = try await APIClient.shared.sendEmailCode(email: mail, purpose: "register")
            countdown = 60
            startCountdown()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func startCountdown() {
        Task {
            while countdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    if countdown > 0 { countdown -= 1 }
                }
            }
        }
    }

    private func submit() async {
        error = nil
        let nick = nickname.trimmingCharacters(in: .whitespaces)
        let mail = email.trimmingCharacters(in: .whitespaces)
        let pwd = password
        guard nick.count >= 2 && nick.count <= 20 else {
            error = "昵称需为 2-20 个字符"
            return
        }
        guard mail.contains("@") else {
            error = "请输入正确的邮箱地址"
            return
        }
        guard code.count == 6 else {
            error = "请输入 6 位邮箱验证码"
            return
        }
        guard pwd.count >= 6 && pwd.count <= 32 else {
            error = "密码需为 6-32 位"
            return
        }
        guard pwd == confirm else {
            error = "两次输入的密码不一致"
            return
        }
        await app.register(nickname: nick, password: pwd, email: mail,
                           code: code, invite: invite.trimmingCharacters(in: .whitespaces))
        if app.isLoggedIn { dismiss() }
    }
}
