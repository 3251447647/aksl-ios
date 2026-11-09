import SwiftUI
import UIKit

/// USDT 充值：主视觉 + 数量输入 + 订单地址 + 充值记录（对齐安卓 UsdtScreen）
struct UsdtView: View {
    @State private var config: UsdtConfig?
    @State private var orders: [UsdtOrder] = []
    @State private var coinText = ""
    @State private var created: UsdtCreateResult?
    @State private var busy = false
    @State private var errorText: String?
    @State private var copied = false

    private let presets = [100, 500, 1000, 5000]

    private var coin: Int64 { Int64(coinText.trimmingCharacters(in: .whitespaces)) ?? 0 }
    private var minCoin: Int64 { Int64(config?.min ?? 10) }

    private var estimate: String {
        guard let c = config, c.rate > 0, coin > 0 else { return "输入数量后显示预计支付" }
        return "预计支付 ≈ \(String(format: "%.2f", Double(coin) / c.rate)) USDT"
    }

    var body: some View {
        List {
            hero
                .listRowInsets(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if let c = config {
                if c.enabled == 0 {
                    notice("暂未开放 USDT 充值")
                        .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 24, trailing: 14))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    inputCard
                        .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 12, trailing: 14))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    if let r = created {
                        createdCard(r, config: c)
                            .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 12, trailing: 14))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }

                    sectionTitle("我的充值记录")
                        .listRowInsets(EdgeInsets(top: 2, leading: 14, bottom: 8, trailing: 14))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    orderCard
                        .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 24, trailing: 14))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            } else if errorText == nil {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .listRowInsets(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            if let errorText {
                Text(errorText)
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.red)
                    .padding(.horizontal, 4)
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 16, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AKColor.bg.ignoresSafeArea())
        .reportsDetailPage()
        .navigationTitle("USDT 充值")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - 主视觉

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("USDT 充值")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            Text("TRC20 通道 · 自动识别到账")
                .font(.system(size: 12.5))
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, 5)
            Text("1 USDT ≈ \(config?.rate ?? 0) K币")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.top, 16)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(hex: 0x123B3F), Color(hex: 0x1D6B5E), Color(hex: 0x2F8F6B)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - 输入卡

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("充值数量")
                .font(.system(size: 13.5))
                .foregroundColor(AKColor.sub)

            HStack(spacing: 6) {
                TextField("最少 \(config?.min ?? 10) K币", text: $coinText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AKColor.text)
            }
            .padding(.horizontal, 14)
            .frame(height: 56)
            .background(AKColor.fill)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.top, 10)

            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { value in
                    let picked = coinText == "\(value)"
                    Button {
                        coinText = "\(value)"
                    } label: {
                        Text("\(value)")
                            .font(.system(size: 13))
                            .foregroundColor(picked ? Color(hex: 0x2FA84F) : AKColor.sub)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(picked ? AKColor.brandSoft : AKColor.fill)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 10)

            Text(estimate)
                .font(.system(size: 12))
                .foregroundColor(coin > 0 ? Color(hex: 0x2FA84F) : AKColor.hint)
                .padding(.top, 10)

            if coin > 0 && coin < minCoin {
                Text("最少 \(minCoin) K币")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.red)
                    .padding(.top, 4)
            }

            Button {
                Task { await create() }
            } label: {
                Text(busy ? "生成中…" : "生成充值订单")
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
            .disabled(busy || coin < minCoin)
            .opacity(coin < minCoin ? 0.6 : 1)
            .padding(.top, 14)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 转账地址

    private func createdCard(_ r: UsdtCreateResult, config c: UsdtConfig) -> some View {
        let address = r.address.isEmpty ? c.address : r.address
        return VStack(alignment: .leading, spacing: 0) {
            Text("请转账 \(r.amountUsdt) USDT 到以下地址")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AKColor.gold)
            Text(address)
                .font(.system(size: 12))
                .foregroundColor(AKColor.sub)
                .padding(.top, 8)
            Button {
                UIPasteboard.general.string = address
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            } label: {
                Text(copied ? "已复制" : "复制地址")
                    .font(.system(size: 12.5))
                    .foregroundColor(Color(hex: 0x2FA84F))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            Text("转账后系统会自动识别到账（约 1-3 分钟），到账 \(r.coin) K币")
                .font(.system(size: 11.5))
                .foregroundColor(AKColor.gold)
                .padding(.top, 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.goldSoft)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 充值记录

    private var orderCard: some View {
        VStack(spacing: 0) {
            if orders.isEmpty {
                Text("暂无充值记录")
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.hint)
                    .frame(maxWidth: .infinity)
                    .frame(height: 90)
            } else {
                ForEach(orders.indices, id: \.self) { index in
                    let o = orders[index]
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(o.amountUsdt) USDT → \(o.coin) K币")
                                .font(.system(size: 14.5))
                                .foregroundColor(AKColor.text)
                            Text(TimeText.short(o.createdAt) + (o.remark.isEmpty ? "" : " · \(o.remark)"))
                                .font(.system(size: 11.5))
                                .foregroundColor(AKColor.hint)
                        }
                        Spacer(minLength: 0)
                        Text(statusText(o.status))
                            .font(.system(size: 11.5))
                            .foregroundColor(statusColor(o.status))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(statusBackground(o.status))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .padding(14)

                    if index < orders.count - 1 {
                        Rectangle().fill(AKColor.line).frame(height: 0.5).padding(.horizontal, 14)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .akCardRow(top: true, bottom: true)
    }

    private func statusText(_ status: Int) -> String {
        switch status {
        case 2: return "已完成"
        case 3: return "已拒绝"
        case 1: return "待确认"
        default: return "待支付"
        }
    }

    private func statusColor(_ status: Int) -> Color {
        switch status {
        case 2: return Color(hex: 0x2FA84F)
        case 3: return AKColor.red
        default: return AKColor.gold
        }
    }

    private func statusBackground(_ status: Int) -> Color {
        switch status {
        case 2: return AKColor.brandSoft
        case 3: return AKColor.redSoft
        default: return AKColor.goldSoft
        }
    }

    // MARK: - 小组件

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13))
            .foregroundColor(AKColor.muted)
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5))
            .foregroundColor(AKColor.hint)
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .akCardRow(top: true, bottom: true)
    }

    // MARK: - 数据

    private func load() async {
        do {
            config = try await APIClient.shared.usdtConfig()
            orders = (try? await APIClient.shared.usdtOrders())?.list ?? []
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func create() async {
        guard coin > 0 else { return }
        busy = true
        defer { busy = false }
        do {
            created = try await APIClient.shared.usdtCreate(coin: coin)
            orders = (try? await APIClient.shared.usdtOrders())?.list ?? []
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }
}
