import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var app: AppState

    @State private var account = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var showRegister = false
    @State private var showForgot = false
    @State private var showPolicy = false
    @State private var policyKind: PolicyDetailView.Kind = .terms

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 72)

            VStack(spacing: 10) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.black.opacity(0.12), radius: 12, y: 6)
                Text("AK商聊")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(AKColor.text)
                Text("安全、简单的即时通讯")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.muted)
            }

            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "person.fill").foregroundColor(AKColor.muted)
                    TextField("AK号 / 邮箱", text: $account)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack(spacing: 10) {
                    Image(systemName: "lock.fill").foregroundColor(AKColor.muted)
                    Group {
                        if showPassword {
                            TextField("密码", text: $password)
                        } else {
                            SecureField("密码", text: $password)
                        }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundColor(AKColor.muted)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if let err = app.errorText {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    Task { await app.login(account: account.trimmingCharacters(in: .whitespaces), password: password) }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AKColor.brand)
                        if app.loading {
                            ProgressView().tint(.white)
                        } else {
                            Text("登录").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                        }
                    }
                    .frame(height: 50)
                }
                .disabled(account.isEmpty || password.isEmpty || app.loading)
                .opacity(account.isEmpty || password.isEmpty ? 0.5 : 1)

                HStack(spacing: 20) {
                    Button("注册账号") { showRegister = true }
                    Button("忘记密码") { showForgot = true }
                }
                .font(.system(size: 13))
                .foregroundColor(AKColor.link)
                .padding(.top, 4)
            }
            .padding(.horizontal, 28)
            .padding(.top, 42)

            Spacer()
            HStack(spacing: 2) {
                Text("登录即代表同意")
                    .font(.system(size: 11))
                    .foregroundColor(AKColor.hint)
                Button {
                    policyKind = .terms
                    showPolicy = true
                } label: {
                    Text("《用户协议》")
                        .font(.system(size: 11))
                        .foregroundColor(AKColor.link)
                }
                .buttonStyle(.plain)
                Text("与")
                    .font(.system(size: 11))
                    .foregroundColor(AKColor.hint)
                Button {
                    policyKind = .privacy
                    showPolicy = true
                } label: {
                    Text("《隐私政策》")
                        .font(.system(size: 11))
                        .foregroundColor(AKColor.link)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 24)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .sheet(isPresented: $showRegister) {
            RegisterView().environmentObject(app)
        }
        .sheet(isPresented: $showForgot) {
            ForgotPasswordView()
        }
        .sheet(isPresented: $showPolicy) {
            NavigationStack {
                PolicyDetailView(kind: policyKind)
            }
        }
    }
}
