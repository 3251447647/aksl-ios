import SwiftUI
import UIKit

/// USDT 充值：显示汇率、输入 K币 数量、生成订单与收款地址、历史订单
struct UsdtView: View {
    @State private var config: UsdtConfig?
    @State private var orders: [UsdtOrder] = []
    @State private var coinText = ""
    @State private var created: UsdtCreateResult?
    @State private var busy = false
    @State private var errorText: String?
    @State private var copied = false

    private var coin: Int64 { Int64(coinText.trimmingCharacters(in: .whitespaces)) ?? 0 }

    private var estimate: String {
        guard let c = config, c.rate > 0, coin > 0 else { return "0.00" }
        let v = Double(coin) / c.rate
        return String(format: "%.2f", v)
    }

    var body: some View {
        List {
            if let c = config {
                if c.enabled == 0 {
                    Section {
                        Text("暂未开放 USDT 充值").font(.system(size: 13)).foregroundColor(AKColor.muted)
                    }
                } else {
                    Section {
                        HStack {
                            Text("汇率").font(.system(size: 13)).foregroundColor(AKColor.sub)
                            Spacer()
                            Text("1 USDT ≈ \(String(format: "%.2f", c.rate)) K币")
                                .font(.system(size: 13)).foregroundColor(AKColor.text)
                        }
                        HStack {
                            Text("最低充值").font(.system(size: 13)).foregroundColor(AKColor.sub)
                            Spacer()
                            Text("\(c.min) K币").font(.system(size: 13)).foregroundColor(AKColor.text)
                        }
                    }

                    Section("充值") {
                        HStack {
                            TextField("输入 K币 数量", text: $coinText)
                                .keyboardType(.numberPad)
                                .font(.system(size: 14))
                        }
                        HStack {
                            Text("需支付").font(.system(size: 13)).foregroundColor(AKColor.sub)
                            Spacer()
                            Text("\(estimate) USDT").font(.system(size: 15, weight: .semibold)).foregroundColor(AKColor.brand)
                        }
                        Button {
                            Task { await create() }
                        } label: {
                            HStack {
                                Text(created == nil ? "生成充值订单" : "重新生成订单")
                                Spacer()
                                if busy { ProgressView() }
                            }
                        }
                        .disabled(busy || coin <= 0)
                    }

                    if let r = created {
                        Section("向以下地址转账") {
                            HStack {
                                Text(r.address.isEmpty ? (c.address) : r.address)
                                    .font(.system(size: 12.5, design: .monospaced))
                                    .foregroundColor(AKColor.text)
                                Spacer()
                                Button(copied ? "已复制" : "复制") {
                                    UIPasteboard.general.string = r.address.isEmpty ? c.address : r.address
                                    copied = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                                }
                                .font(.system(size: 13))
                            }
                            Text("订单金额 \(r.amountUsdt) USDT · 到账 \(r.coin) K币")
                                .font(.system(size: 12)).foregroundColor(AKColor.muted)
                            Text("请务必使用 TRC20 通道转账，转账后等待系统自动确认。")
                                .font(.system(size: 11.5)).foregroundColor(AKColor.hint)
                        }
                    }
                }
            } else if errorText == nil {
                Section { ProgressView() }
            }

            if let errorText {
                Section { Text(errorText).font(.system(size: 13)).foregroundColor(AKColor.red) }
            }

            if !orders.isEmpty {
                Section("充值记录") {
                    ForEach(orders) { o in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("\(o.amountUsdt) USDT → \(o.coin) K币")
                                    .font(.system(size: 13.5)).foregroundColor(AKColor.text)
                                Spacer()
                                Text(o.statusText)
                                    .font(.system(size: 12))
                                    .foregroundColor(o.status == 1 ? AKColor.brand : AKColor.muted)
                            }
                            Text(TimeText.short(o.createdAt))
                                .font(.system(size: 11)).foregroundColor(AKColor.hint)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("USDT 充值")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

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
