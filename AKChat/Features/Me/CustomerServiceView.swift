import SwiftUI
import UIKit

/// 客服资料（GET /api/v1/cs）：客服本人 + 官方群 + 联系方式 + 后台提示
struct CsInfo: Decodable {
    let uid: Int64
    let name: String
    let avatar: String
    let prettyNo: String
    let yxId: String
    let vipLevel: Int
    let contact: String
    let tip: String
    let groupId: Int64
    let groupName: String
    let groupAvatar: String
    let groupPretty: String
    let groupNo: String

    enum CodingKeys: String, CodingKey {
        case uid, name, avatar, contact, tip
        case prettyNo = "pretty_no"
        case yxId = "yx_id"
        case vipLevel = "vip_level"
        case groupId = "group_id"
        case groupName = "group_name"
        case groupAvatar = "group_avatar"
        case groupPretty = "group_pretty"
        case groupNo = "group_no"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uid = (try? c.decode(Int64.self, forKey: .uid)) ?? 0
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        avatar = (try? c.decode(String.self, forKey: .avatar)) ?? ""
        prettyNo = (try? c.decode(String.self, forKey: .prettyNo)) ?? ""
        yxId = (try? c.decode(String.self, forKey: .yxId)) ?? ""
        vipLevel = (try? c.decode(Int.self, forKey: .vipLevel)) ?? 0
        contact = (try? c.decode(String.self, forKey: .contact)) ?? ""
        tip = (try? c.decode(String.self, forKey: .tip)) ?? ""
        groupId = (try? c.decode(Int64.self, forKey: .groupId)) ?? 0
        groupName = (try? c.decode(String.self, forKey: .groupName)) ?? ""
        groupAvatar = (try? c.decode(String.self, forKey: .groupAvatar)) ?? ""
        groupPretty = (try? c.decode(String.self, forKey: .groupPretty)) ?? ""
        groupNo = (try? c.decode(String.self, forKey: .groupNo)) ?? ""
    }
}

extension APIClient {
    func customerService() async throws -> CsInfo {
        try await get("api/v1/cs")
    }
}

/// 联系客服：客服卡 + 官方群 + 联系方式 + 常见问题 + 发消息（对齐安卓 ContactScreen）
struct CustomerServiceView: View {
    /// 兼容旧调用方传入的占位资料；服务端返回后以服务端为准
    var name: String = "在线客服"
    var avatar: String? = nil
    var contact: String? = nil
    var yxId: String? = nil

    @State private var info: CsInfo?
    @State private var group: GroupPreviewInfo?
    @State private var openFaq = -1
    @State private var copied = false

    private static let faqs: [(String, String)] = [
        ("如何充值K币？", "进入「我的 → K币钱包 → 充值」，填写金额后提交，客服会收到通知，确认到账后K币立即到账。"),
        ("提现多久到账？", "提现申请提交后，管理员会在 24 小时内审核。审核通过后 1-2 个工作日内到账。"),
        ("靓号怎么购买？", "进入「我的 → 靓号商城」，选择喜欢的靓号，确认支付后即刻生效为你的新AK号。"),
        ("会员有什么特权？", "VIP/SVIP 会员可享受更多群成员上限、专属徽章、更多特权。详见「我的 → VIP 会员」。"),
        ("忘记密码怎么办？", "请在登录页点击「忘记密码」，通过邮箱验证码重置；如无法重置请联系在线客服。")
    ]

    private var displayName: String {
        if let value = info?.name, !value.isEmpty { return value }
        return name
    }

    private var displayAvatar: String? {
        if let value = info?.avatar, !value.isEmpty { return value }
        return avatar
    }

    private var displayContact: String {
        if let value = info?.contact, !value.isEmpty { return value }
        return contact ?? ""
    }

    private var displayYxId: String {
        if let value = info?.yxId, !value.isEmpty { return value }
        return yxId ?? ""
    }

    private var serviceUid: Int64 { info?.uid ?? 0 }
    private var groupId: Int64 { info?.groupId ?? 0 }
    private var groupIsMember: Bool { (group?.isMember ?? 0) == 1 }
    private var groupName: String {
        let value = info?.groupName ?? ""
        return value.isEmpty ? "AK官方群聊" : value
    }
    private var groupNo: String {
        let value = info?.groupNo ?? ""
        return value.isEmpty ? "666666" : value
    }
    private var groupPretty: String {
        let value = info?.groupPretty ?? ""
        return value.isEmpty ? groupNo : value
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                heroCard
                if groupId > 0 { groupCard }
                contactCard
                if let tip = info?.tip, !tip.isEmpty {
                    tipCard(tip)
                }
                faqCard
            }
            .padding(14)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .reportsDetailPage()
        .navigationTitle("联系客服")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
        .safeAreaInset(edge: .bottom) { sendBar }
        .task { await load() }
    }

    // MARK: - 客服卡

    private var heroCard: some View {
        VStack(spacing: 0) {
            AvatarView(url: displayAvatar, name: displayName, size: 78)
            HStack(spacing: 6) {
                Text(displayName)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let pretty = info?.prettyNo, !pretty.isEmpty {
                    PrettyBadge(number: pretty)
                }
                if (info?.vipLevel ?? 0) > 0 {
                    VipBadge(level: info?.vipLevel ?? 0)
                }
            }
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

            if !displayYxId.isEmpty {
                Text("靓号：\(displayYxId)")
                    .font(.system(size: 12.5))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.top, 8)
            }

            if serviceUid > 0 {
                NavigationLink {
                    ChatView(convType: "private", convId: serviceUid, title: displayName)
                } label: {
                    HStack(spacing: 6) {
                        Text("💬").font(.system(size: 15))
                        Text("立即咨询")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: 0x2FA84F))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(AKColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.top, 16)
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

    // MARK: - 官方群

    private var groupCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(AKColor.gold)
                    .frame(width: 3, height: 12)
                Text("官方群聊")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.sub)
                Spacer(minLength: 6)
                Text("群靓官方群")
                    .font(.system(size: 11))
                    .foregroundColor(AKColor.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(AKColor.goldSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack(spacing: 10) {
                AvatarView(url: info?.groupAvatar, name: groupName, size: 46)
                VStack(alignment: .leading, spacing: 5) {
                    Text(groupName)
                        .font(.system(size: 15.5, weight: .medium))
                        .foregroundColor(AKColor.text)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        PrettyBadge(number: groupPretty, isGroup: true)
                        Text("群号 \(groupNo)")
                            .font(.system(size: 11))
                            .foregroundColor(AKColor.gold)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(AKColor.goldSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                Spacer(minLength: 6)
                groupAction
            }
            .padding(.top, 12)

            Text("加入即可与官方和其他用户交流")
                .font(.system(size: 11.5))
                .foregroundColor(AKColor.muted)
                .padding(.top, 10)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var groupAction: some View {
        if groupIsMember {
            NavigationLink {
                ChatView(convType: "group", convId: groupId, title: groupName)
            } label: {
                Text("✓ 已加入")
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(colors: [Color(hex: 0x43C463), Color(hex: 0x2FA84F)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                GroupPreviewView(groupId: groupId)
            } label: {
                Text("加入群聊")
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(colors: [Color(hex: 0x43C463), Color(hex: 0x2FA84F)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 联系方式

    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("联系方式")
                .font(.system(size: 13))
                .foregroundColor(AKColor.sub)
            HStack(spacing: 10) {
                Text("✆")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Color(hex: 0x2FC98A))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                Text(displayContact.isEmpty ? "暂无联系方式" : displayContact)
                    .font(.system(size: 13.5))
                    .foregroundColor(AKColor.text)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button {
                    UIPasteboard.general.string = displayContact
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
                .disabled(displayContact.isEmpty)
            }
            .padding(.top, 10)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 后台提示

    private func tipCard(_ tip: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 16))
                .foregroundColor(AKColor.gold)
            Text(tip)
                .font(.system(size: 13))
                .foregroundColor(AKColor.gold)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.goldSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    // MARK: - 底部发消息

    private var sendBar: some View {
        Group {
            if serviceUid > 0 {
                NavigationLink {
                    ChatView(convType: "private", convId: serviceUid, title: displayName)
                } label: {
                    sendLabel("发送消息", enabled: true)
                }
                .buttonStyle(.plain)
            } else {
                Button {} label: {
                    sendLabel("客服暂未配置", enabled: false)
                }
                .buttonStyle(.plain)
                .disabled(true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AKColor.bg)
    }

    private func sendLabel(_ title: String, enabled: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "message.fill")
                .font(.system(size: 15))
            Text(title)
                .font(.system(size: 16, weight: .medium))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(
            LinearGradient(colors: enabled
                           ? [Color(hex: 0x43C463), Color(hex: 0x2FA84F)]
                           : [AKColor.placeholder, AKColor.placeholder],
                           startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func load() async {
        guard let data = try? await APIClient.shared.customerService() else { return }
        info = data
        if data.groupId > 0 {
            group = try? await APIClient.shared.groupPreview(id: data.groupId)
        }
    }
}
