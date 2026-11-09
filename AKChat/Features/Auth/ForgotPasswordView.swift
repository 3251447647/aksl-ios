import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var code = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var countdown = 0
    @State private var info: String?
    @State private var error: String?
    @State private var sending = false
    @State private var done = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.fill").foregroundColor(AKColor.muted)
                            TextField("注册邮箱", text: $email)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.emailAddress)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .background(AKColor.fill)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        HStack(spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "number").foregroundColor(AKColor.muted)
                                TextField("6 位邮箱验证码", text: $code)
                                    .keyboardType(.numberPad)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 46)
                            .background(AKColor.fill)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

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

                        HStack(spacing: 10) {
                            Image(systemName: "lock.fill").foregroundColor(AKColor.muted)
                            SecureField("新密码（6-32 位）", text: $password)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .background(AKColor.fill)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        HStack(spacing: 10) {
                            Image(systemName: "lock.rotation").foregroundColor(AKColor.muted)
                            SecureField("确认新密码", text: $confirm)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .background(AKColor.fill)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

                    Button {
                        Task { await submit() }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AKColor.brand)
                            if sending {
                                ProgressView().tint(.white)
                            } else {
                                Text("重置密码").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                            }
                        }
                        .frame(height: 50)
                    }
                    .disabled(sending || email.isEmpty || code.isEmpty || password.isEmpty)

                    Text("重置成功后所有设备会退出登录，需要用新密码重新登录。")
                        .font(.system(size: 11))
                        .foregroundColor(AKColor.hint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            }
            .background(AKColor.bg)
            .reportsDetailPage()
            .navigationTitle("找回密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
            .alert("密码已重置", isPresented: $done) {
                Button("去登录") { dismiss() }
            } message: {
                Text("请用新密码登录")
            }
        }
    }

    private func requestCode() async {
        let mail = email.trimmingCharacters(in: .whitespaces)
        guard !mail.isEmpty, countdown == 0 else { return }
        sending = true
        info = nil
        error = nil
        defer { sending = false }
        do {
            info = try await APIClient.shared.sendEmailCode(email: mail, purpose: "reset")
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
        let mail = email.trimmingCharacters(in: .whitespaces)
        guard code.count == 6 else {
            error = "请输入 6 位邮箱验证码"
            return
        }
        guard password.count >= 6 && password.count <= 32 else {
            error = "密码需为 6-32 位"
            return
        }
        guard password == confirm else {
            error = "两次输入的密码不一致"
            return
        }
        sending = true
        error = nil
        defer { sending = false }
        do {
            try await APIClient.shared.resetPassword(email: mail, code: code, password: password)
            done = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}
