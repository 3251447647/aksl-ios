import SwiftUI
import UIKit

/// 充值提交结果（POST /api/v1/wallet/recharge）
struct RechargeResult: Decodable {
    let id: Int64
    let messageId: Int64
    let amount: Int64
    let serviceId: Int64
    let contact: String
    let tip: String

    enum CodingKeys: String, CodingKey {
        case id, amount, contact, tip
        case messageId = "message_id"
        case serviceId = "service_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        messageId = (try? c.decode(Int64.self, forKey: .messageId)) ?? 0
        amount = (try? c.decode(Int64.self, forKey: .amount)) ?? 0
        serviceId = (try? c.decode(Int64.self, forKey: .serviceId)) ?? 0
        contact = (try? c.decode(String.self, forKey: .contact)) ?? ""
        tip = (try? c.decode(String.self, forKey: .tip)) ?? ""
    }
}

extension APIClient {
    func recharge(amount: Int64, remark: String) async throws -> RechargeResult {
        try await post("api/v1/wallet/recharge", body: [
            "amount": amount,
            "remark": remark
        ])
    }
}

/// 充值K币：客服收款卡 + USDT 入口 + 金额/快捷金额 + 备注（对齐安卓 WalletScreen 充值面板）
struct RechargeView: View {
    @State private var cs: CsInfo?
    @State private var usdt: UsdtConfig?
    @State private var amount = ""
    @State private var remark = ""
    @State private var busy = false
    @State private var errorText: String?
    @State private var serviceId: Int64 = 0
    @State private var goChat = false
    @State private var copied = false

    private let quickAmounts = [100, 500, 1000, 5000]

    private var csName: String {
        let value = cs?.name ?? ""
        return value.isEmpty ? "客服" : value
    }
    private var csNo: String {
        let value = cs?.yxId ?? ""
        return value.isEmpty ? "-" : value
    }
    private var csContact: String {
        let value = cs?.contact ?? ""
        return value.isEmpty ? "-" : value
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                contactCard

                if let usdt, usdt.enabled == 1, !usdt.address.isEmpty {
                    usdtEntry(usdt)
                }

                Text("充值金额 *")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.sub)
                WalletInputField(placeholder: "请输入想要充值的K币数", text: $amount,
                                 limit: 7, height: 48, digitsOnly: true)

                HStack(spacing: 8) {
                    ForEach(quickAmounts, id: \.self) { value in
                        Button {
                            amount = "\(value)"
                        } label: {
                            Text("\(value)")
                                .font(.system(size: 13))
                                .foregroundColor(amount == "\(value)" ? Color(hex: 0x2FA84F) : AKColor.sub)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(amount == "\(value)" ? AKColor.brandSoft : AKColor.fill)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 6) {
                    Text("备注")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.sub)
                    Text("选填")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.placeholder)
                }
                WalletInputField(placeholder: "付款方式 / 转账单号等", text: $remark,
                                 limit: 50, height: 64, multiline: true)

                if let errorText, !errorText.isEmpty {
                    Text(errorText)
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.red)
                }

                Button {
                    Task { await submit() }
                } label: {
                    Text(busy ? "提交中…" : "立即充值")
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
                .disabled(busy)
                .opacity(busy ? 0.72 : 1)

                Text("提交后自动跳转到客服聊天")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.placeholder)
                    .frame(maxWidth: .infinity)
            }
            .padding(18)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .reportsDetailPage()
        .navigationTitle("充值K币")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .navigationDestination(isPresented: $goChat) {
            ChatView(convType: "private", convId: serviceId, title: csName)
        }
    }

    // MARK: - 客服收款卡

    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("🎧").font(.system(size: 14))
                Text("联系客服完成付款")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AKColor.text)
            }

            HStack(spacing: 10) {
                AvatarView(url: cs?.avatar, name: csName, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(csName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AKColor.text)
                        .lineLimit(1)
                    Text("AK号：\(csNo)")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.hint)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(AKColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.top, 10)

            HStack(spacing: 10) {
                Text("联系方式")
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.muted)
                Text(csContact)
                    .font(.system(size: 12.5))
                    .foregroundColor(Color(hex: 0x2FA84F))
                    .lineLimit(1)
                Spacer(minLength: 6)
                Button {
                    UIPasteboard.general.string = cs?.contact ?? ""
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { copied = false }
                } label: {
                    Text(copied ? "已复制" : "复制")
                        .font(.system(size: 12.5))
                        .foregroundColor(Color(hex: 0x2FA84F))
                }
                .buttonStyle(.plain)
                .disabled((cs?.contact ?? "").isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AKColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.top, 8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.blueSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - USDT

    private func usdtEntry(_ config: UsdtConfig) -> some View {
        NavigationLink {
            UsdtView()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("₮")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Color(hex: 0x43C463))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("USDT 充值（TRC20）")
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundColor(AKColor.text)
                        Text("自动识别到账，实时加K币")
                            .font(.system(size: 11.5))
                            .foregroundColor(AKColor.hint)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AKColor.placeholder)
                }
                Text("收款地址：\(config.address)")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.sub)
                    .lineLimit(2)
                if config.rate > 0 {
                    Text("汇率：1 USDT ≈ \(Int(config.rate)) K币")
                        .font(.system(size: 11))
                        .foregroundColor(AKColor.hint)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AKColor.brandSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        if let data = try? await APIClient.shared.customerService() {
            cs = data
        }
        if let config = try? await APIClient.shared.usdtConfig() {
            usdt = config
        }
    }

    private func submit() async {
        guard !busy else { return }
        let coin = Int64(amount) ?? 0
        guard coin > 0 else {
            errorText = "请输入充值金额"
            return
        }
        busy = true
        defer { busy = false }
        do {
            let result = try await APIClient.shared.recharge(amount: coin, remark: remark)
            serviceId = result.serviceId > 0 ? result.serviceId : (cs?.uid ?? 0)
            errorText = nil
            if serviceId > 0 { goChat = true }
        } catch {
            errorText = error.localizedDescription
        }
    }
}
