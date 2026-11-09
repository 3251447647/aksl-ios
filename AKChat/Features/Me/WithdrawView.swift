import SwiftUI
import Foundation
import UIKit
import PhotosUI

/// 提现所需的钱包配置（GET /api/v1/wallet/info）
struct WithdrawWallet: Decodable {
    let coin: Int64
    let withdrawMin: Int64
    let withdrawFeeRate: Double

    enum CodingKeys: String, CodingKey {
        case coin
        case withdrawMin = "withdraw_min"
        case withdrawFeeRate = "withdraw_fee_rate"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        coin = (try? c.decode(Int64.self, forKey: .coin)) ?? 0
        withdrawMin = (try? c.decode(Int64.self, forKey: .withdrawMin)) ?? 0
        withdrawFeeRate = (try? c.decode(Double.self, forKey: .withdrawFeeRate)) ?? 0
    }
}

extension APIClient {
    func withdrawWallet() async throws -> WithdrawWallet {
        try await get("api/v1/wallet/info")
    }

    /// 提现成功时返回服务端提示（含手续费/实际到账）
    func withdraw(amount: Int64, account: String, qrcode: String, password: String) async throws -> String {
        try await postRaw("api/v1/wallet/withdraw", body: [
            "amount": amount,
            "account": account,
            "qrcode": qrcode,
            "pay_password": password
        ])
    }
}

/// 提现申请：金额/快捷金额 + 门槛与手续费 + 收款账号 + 收款码 + 支付密码（对齐安卓 WalletScreen 提现面板）
struct WithdrawView: View {
    @State private var wallet: WithdrawWallet?
    @State private var amount = ""
    @State private var account = ""
    @State private var password = ""
    @State private var showPwd = false
    @State private var qrURL = ""
    @State private var qrItem: PhotosPickerItem?
    @State private var showQrPicker = false
    @State private var uploading = false
    @State private var busy = false
    @State private var errorText: String?
    @State private var tipText: String?

    private let quickAmounts = ["100", "500", "1000", "全部"]

    private var amountValue: Int64 { Int64(amount) ?? 0 }

    private var fee: Int64 {
        guard let wallet, wallet.withdrawFeeRate > 0 else { return 0 }
        return Int64(ceil(Double(amountValue) * wallet.withdrawFeeRate / 100.0))
    }

    private var limitTip: String {
        var parts: [String] = []
        if let wallet, wallet.withdrawMin > 0 {
            parts.append("最低提现 \(wallet.withdrawMin) K币")
        }
        if let wallet, wallet.withdrawFeeRate > 0 {
            if amountValue > 0 {
                let net = amountValue - fee
                parts.append("手续费 \(wallet.withdrawFeeRate)% = \(fee) K币，实际到账 \(net) K币")
            } else {
                parts.append("手续费 \(wallet.withdrawFeeRate)%（提交时扣除）")
            }
        }
        return parts.joined(separator: "　·　")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("提现金额 *")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.sub)
                WalletInputField(placeholder: "请输入提现K币数", text: $amount,
                                 limit: 7, height: 48, digitsOnly: true)

                HStack(spacing: 8) {
                    ForEach(quickAmounts, id: \.self) { value in
                        Button {
                            if value == "全部" {
                                amount = "\(wallet?.coin ?? 0)"
                            } else {
                                amount = value
                            }
                        } label: {
                            Text(value)
                                .font(.system(size: 13))
                                .foregroundColor(isQuickActive(value) ? Color(hex: 0x2FA84F) : AKColor.sub)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(isQuickActive(value) ? AKColor.brandSoft : AKColor.fill)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !limitTip.isEmpty {
                    Text(limitTip)
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.muted)
                }

                Text("收款账号 *")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.sub)
                WalletInputField(placeholder: "微信号 / 支付宝 / 银行卡号", text: $account,
                                 limit: 60, height: 48)

                HStack(spacing: 6) {
                    Text("收款码")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.sub)
                    Text("选填")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.placeholder)
                }
                qrRow

                Text("支付密码 *")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.sub)
                passwordField

                if let errorText, !errorText.isEmpty {
                    Text(errorText)
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.red)
                }

                Button {
                    Task { await submit() }
                } label: {
                    Text(busy ? "提交中…" : "提交申请")
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

                Text("提交后等待管理员审核，审核通过后打款")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.placeholder)
                    .frame(maxWidth: .infinity)
            }
            .padding(18)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .reportsDetailPage()
        .navigationTitle("提现申请")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .photosPicker(isPresented: $showQrPicker, selection: $qrItem, matching: .images)
        .onChange(of: qrItem) { item in
            Task { await uploadQr(item) }
        }
        .alert("提示", isPresented: Binding(
            get: { tipText != nil },
            set: { if !$0 { tipText = nil } }
        )) {
            Button("好", role: .cancel) { tipText = nil }
        } message: {
            Text(tipText ?? "")
        }
    }

    private func isQuickActive(_ value: String) -> Bool {
        if value == "全部" {
            let coin = wallet?.coin ?? 0
            return coin > 0 && amount == "\(coin)"
        }
        return amount == value
    }

    private var qrRow: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AKColor.card)
                if let url = APIClient.fullURL(qrURL) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Color.clear
                        }
                    }
                } else if uploading {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Text("⛶")
                        .font(.system(size: 22))
                        .foregroundColor(AKColor.placeholder)
                }
            }
            .frame(width: 58, height: 58)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { showQrPicker = true }

            VStack(alignment: .leading, spacing: 3) {
                Text(qrURL.isEmpty ? "上传收款码" : "收款码已上传")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AKColor.text)
                Text("选填，上传后客服直接扫码打款")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.muted)
            }
            Spacer(minLength: 6)
            Button {
                showQrPicker = true
            } label: {
                Text("选择图片")
                    .font(.system(size: 12.5))
                    .foregroundColor(Color(hex: 0x2FA84F))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(AKColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(AKColor.fill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var passwordField: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AKColor.fill)
            HStack(spacing: 8) {
                Group {
                    if showPwd {
                        TextField("", text: $password)
                    } else {
                        SecureField("", text: $password)
                    }
                }
                .font(.system(size: 15))
                .foregroundColor(AKColor.text)
                .keyboardType(.numberPad)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

                Button {
                    showPwd.toggle()
                } label: {
                    Image(systemName: showPwd ? "eye.slash" : "eye")
                        .font(.system(size: 15))
                        .foregroundColor(AKColor.placeholder)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)

            if password.isEmpty {
                Text("6 位支付密码")
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.placeholder)
                    .padding(.horizontal, 14)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 48)
        .onChange(of: password) { value in
            let next = String(value.filter { $0.isNumber }.prefix(8))
            if next != value { password = next }
        }
    }

    private func load() async {
        if let data = try? await APIClient.shared.withdrawWallet() {
            wallet = data
        }
    }

    private func uploadQr(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        uploading = true
        defer { uploading = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.8),
              let uploaded = try? await APIClient.shared.upload(data: jpeg, filename: "withdraw_qr.jpg", kind: "image")
        else {
            errorText = "上传失败"
            return
        }
        qrURL = uploaded.url
        qrItem = nil
        errorText = nil
    }

    private func submit() async {
        guard !busy else { return }
        let coin = amountValue
        guard coin > 0 else {
            errorText = "请输入提现金额"
            return
        }
        if let wallet, wallet.withdrawMin > 0, coin < wallet.withdrawMin {
            errorText = "最低提现 \(wallet.withdrawMin) K币"
            return
        }
        busy = true
        defer { busy = false }
        do {
            let message = try await APIClient.shared.withdraw(
                amount: coin,
                account: account,
                qrcode: qrURL,
                password: password
            )
            tipText = message.isEmpty ? "已提交" : message
            errorText = nil
            password = ""
            await load()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
