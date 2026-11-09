import SwiftUI

/// 个人资料：渐变身份卡 + 基础资料 / 账号信息 / 联系方式 / 安全设置（对齐安卓 ProfileEditScreen）
struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppState

    @State private var nickname = ""
    @State private var bio = ""
    @State private var saving = false

    private var vipLevel: Int { app.user?.vipLevel ?? 0 }
    private var vipDays: Int { app.user?.vipDays ?? 0 }
    private var prettyNo: String { app.user?.prettyYxid ?? "" }

    var body: some View {
        List {
            Group {
                Text("完善资料，让好友更容易认出你")
                .font(.system(size: 12))
                .foregroundColor(AKColor.hint)
                .padding(.horizontal, 4)
                .listRowInsets(EdgeInsets(top: 10, leading: 14, bottom: 8, trailing: 14))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            identityCard
                .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 12, trailing: 14))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            groupTitle("基础资料")
                .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 8, trailing: 14))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("昵称")
                        .font(.system(size: 15))
                        .foregroundColor(AKColor.text)
                    Spacer(minLength: 8)
                    TextField("昵称", text: $nickname)
                        .font(.system(size: 15))
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(AKColor.text)
                        .frame(maxWidth: 180)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(AKColor.placeholder)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)

                divider

                VStack(alignment: .leading, spacing: 10) {
                    Text("个人简介")
                        .font(.system(size: 15))
                        .foregroundColor(AKColor.text)
                    ZStack(alignment: .bottomTrailing) {
                        TextEditor(text: $bio)
                            .font(.system(size: 14))
                            .foregroundColor(AKColor.text)
                            .scrollContentBackground(.hidden)
                            .frame(height: 96)
                        Text("\(bio.count)/100")
                            .font(.system(size: 11))
                            .foregroundColor(AKColor.placeholder)
                    }
                    .padding(12)
                    .background(AKColor.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .akCardRow(top: true, bottom: true, radius: 16)
            .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 12, trailing: 14))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            }

            Group {
                groupTitle("账号信息")
                .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 8, trailing: 14))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            VStack(spacing: 0) {
                infoRow("账号", app.user?.account ?? "-", mono: true)
                divider
                infoRow("AK号", app.user?.yxId ?? app.user?.showYxid ?? "-")
                divider
                infoRow("靓号", prettyNo.isEmpty ? "未拥有" : prettyNo, highlight: !prettyNo.isEmpty)
                divider
                infoRow("会员", levelText + (vipDays > 0 ? " · 剩余 \(vipDays) 天" : ""))
            }
            .akCardRow(top: true, bottom: true, radius: 16)
            .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 12, trailing: 14))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            groupTitle("联系方式")
                .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 8, trailing: 14))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            VStack(spacing: 0) {
                contactRow("邮箱", app.user?.email ?? "")
                divider
                contactRow("手机号", app.user?.phone ?? "")
            }
            .akCardRow(top: true, bottom: true, radius: 16)
            .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 12, trailing: 14))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            groupTitle("安全设置")
                .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 8, trailing: 14))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            VStack(spacing: 0) {
                NavigationLink {
                    ChangePasswordView(type: "login")
                } label: {
                    securityRow("登录密码", trailing: "修改")
                }
                .buttonStyle(.plain)
                divider
                NavigationLink {
                    ChangePasswordView(type: "pay")
                } label: {
                    securityRow("支付密码", trailing: "已设置")
                }
                .buttonStyle(.plain)
            }
            .akCardRow(top: true, bottom: true, radius: 16)
            .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 12, trailing: 14))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            }

            Group {
                HStack(spacing: 10) {
                    Text("?")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(AKColor.gold)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("忘记登录 / 支付密码？")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AKColor.gold)
                    Text("联系客服帮你重置账号密码")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.gold)
                }
                Spacer(minLength: 8)
                NavigationLink { CustomerServiceView() } label: {
                    Text("联系客服")
                        .font(.system(size: 12.5))
                        .foregroundColor(AKColor.gold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(AKColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(14)
            .background(AKColor.goldSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 18, trailing: 14))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            Button {
                Task { await save() }
            } label: {
                Text(saving ? "保存中…" : "保存修改")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(colors: [Color(hex: 0x43C463), Color(hex: 0x2FA84F)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .opacity(canSave ? 1 : 0.5)
            }
            .buttonStyle(.plain)
            .disabled(!canSave || saving)
            .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 30, trailing: 14))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AKColor.bg.ignoresSafeArea())
        .navigationTitle("个人资料")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            nickname = app.user?.nickname ?? ""
            bio = app.user?.bio ?? ""
        }
        .onChange(of: nickname) { value in
            if value.count > 20 { nickname = String(value.prefix(20)) }
        }
        .onChange(of: bio) { value in
            if value.count > 100 { bio = String(value.prefix(100)) }
        }
    }

    private var canSave: Bool {
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var levelText: String {
        switch vipLevel {
        case 2: return "至尊 SVIP"
        case 1: return "VIP"
        default: return "普通用户"
        }
    }

    // MARK: - 身份卡

    private var identityCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                AvatarView(url: app.user?.avatar, name: app.user?.displayName ?? "我", size: 62)
                    .padding(3)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Text(app.user?.nickname ?? "")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if vipLevel > 0 { VipBadge(level: vipLevel) }
                        if !prettyNo.isEmpty { PrettyBadge(number: prettyNo) }
                    }
                    Text(levelText + (vipDays > 0 ? " · 剩余 \(vipDays) 天" : ""))
                        .font(.system(size: 12.5))
                        .foregroundColor(.white.opacity(0.9))
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 0) {
                cardStat(app.user?.account ?? "-", "账号")
                cardDivider
                cardStat(prettyNo.isEmpty ? "-" : prettyNo, "靓号")
                cardDivider
                cardStat(vipLevel == 2 ? "SVIP" : (vipLevel == 1 ? "VIP" : "普通"), "会员等级")
            }
            .padding(.top, 16)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: vipLevel == 2
                            ? [Color(hex: 0xF7A23B), Color(hex: 0xF2B33D)]
                            : [Color(hex: 0x69C0FF), Color(hex: 0x3B82F6)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var cardDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.2))
            .frame(width: 0.5, height: 28)
    }

    private func cardStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 行组件

    private var divider: some View {
        Rectangle()
            .fill(AKColor.line)
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    private func groupTitle(_ title: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(hex: 0x43C463))
                .frame(width: 3, height: 12)
            Text(title)
                .font(.system(size: 12.5))
                .foregroundColor(AKColor.muted)
        }
        .padding(.leading, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoRow(_ label: String, _ value: String, mono: Bool = false, highlight: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(AKColor.text)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 15, design: mono ? .monospaced : .default))
                .fontWeight(highlight ? .bold : .regular)
                .foregroundColor(highlight ? AKColor.red : AKColor.sub)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private func contactRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(AKColor.text)
            Spacer(minLength: 8)
            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.sub)
                    .lineLimit(1)
                Text("已绑定")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: 0x2FA84F))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(AKColor.brandSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Text("未绑定")
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.hint)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private func securityRow(_ title: String, trailing: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(AKColor.text)
            Spacer(minLength: 8)
            Text(trailing)
                .font(.system(size: 13))
                .foregroundColor(AKColor.hint)
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(AKColor.placeholder)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }

    private func save() async {
        saving = true
        await app.updateProfile(nickname: nickname.trimmingCharacters(in: .whitespaces),
                                bio: bio.trimmingCharacters(in: .whitespaces))
        saving = false
        dismiss()
    }
}
