import SwiftUI
import UIKit

/// 联系客服：客服卡 + 常见问题 + 底部发送消息（对齐安卓 ContactScreen）
struct CustomerServiceView: View {
    /// 客服资料（后台 /api/v1/cs 返回；未接入前用默认占位）
    var name: String = "在线客服"
    var avatar: String? = nil
    var contact: String? = nil
    var yxId: String? = nil

    @Environment(\.openURL) private var openURL
    @State private var openFaq = -1
    @State private var copied = false

    private static let faqs: [(String, String)] = [
        ("如何充值K币？", "进入「我的 → K币钱包 → 充值」，填写金额后提交，客服会收到通知，确认到账后K币立即到账。"),
        ("提现多久到账？", "提现申请提交后，管理员会在 24 小时内审核。审核通过后 1-2 个工作日内到账。"),
        ("靓号怎么购买？", "进入「我的 → 靓号商城」，选择喜欢的靓号，确认支付后即刻生效为你的新AK号。"),
        ("会员有什么特权？", "VIP/SVIP 会员可享受更多群成员上限、专属徽章、更多特权。详见「我的 → VIP 会员」。"),
        ("忘记密码怎么办？", "请在登录页点击「忘记密码」，通过邮箱验证码重置；如无法重置请联系在线客服。")
    ]

    private let serviceURL = URL(string: "https://www.aksliao.cn/service.php")!

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                heroCard
                if let contact, !contact.isEmpty {
                    contactCard(contact)
                }
                faqCard
            }
            .padding(14)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .navigationTitle("联系客服")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
        .safeAreaInset(edge: .bottom) { sendBar }
    }

    // MARK: - 客服卡

    private var heroCard: some View {
        VStack(spacing: 0) {
            AvatarView(url: avatar, name: name, size: 78)
            Text(name)
                .font(.system(size: 21, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 12)
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: 0x4ADE80))
                    .frame(width: 6, height: 6)
                Text("在线 · 随时为您服务")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.top, 10)
            if let yxId, !yxId.isEmpty {
                Text("靓号：\(yxId)")
                    .font(.system(size: 12.5))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.top, 8)
            }
        }
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color(hex: 0x12B886), Color(hex: 0x5B8DEF), Color(hex: 0x8B7CF6)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - 联系方式

    private func contactCard(_ text: String) -> some View {
        HStack(spacing: 10) {
            Text("✆")
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(Color(hex: 0x2FC98A))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("联系方式")
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.sub)
                Text(text)
                    .font(.system(size: 13.5))
                    .foregroundColor(AKColor.text)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button {
                UIPasteboard.general.string = text
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { copied = false }
            } label: {
                Text(copied ? "已复制" : "复制")
                    .font(.system(size: 12.5))
                    .foregroundColor(Color(hex: 0x2FA84F))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(AKColor.brandSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 常见问题

    private var faqCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color(hex: 0x43C463))
                    .frame(width: 3, height: 12)
                Text("常见问题")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.sub)
                Spacer(minLength: 0)
            }
            .padding(14)

            ForEach(Self.faqs.indices, id: \.self) { index in
                VStack(spacing: 0) {
                    Button {
                        openFaq = openFaq == index ? -1 : index
                    } label: {
                        HStack(spacing: 10) {
                            Text("Q")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: 0x3B82F6))
                                .frame(width: 20, height: 20)
                                .background(AKColor.blueSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            Text(Self.faqs[index].0)
                                .font(.system(size: 14.5))
                                .foregroundColor(AKColor.text)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AKColor.placeholder)
                                .rotationEffect(.degrees(openFaq == index ? 90 : 0))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if openFaq == index {
                        Text(Self.faqs[index].1)
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.sub)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 44)
                            .padding(.trailing, 14)
                            .padding(.bottom, 14)
                    }

                    if index < Self.faqs.count - 1 {
                        Rectangle()
                            .fill(AKColor.line)
                            .frame(height: 0.5)
                            .padding(.leading, 44)
                    }
                }
            }
        }
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 底部发送消息

    private var sendBar: some View {
        Button {
            openURL(serviceURL)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "message.fill")
                    .font(.system(size: 15))
                Text("发送消息")
                    .font(.system(size: 16, weight: .medium))
            }
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
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AKColor.bg)
    }
}
