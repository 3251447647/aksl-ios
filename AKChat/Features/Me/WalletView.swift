import SwiftUI

/// K币钱包：余额卡 + 快捷入口 + 收支明细（对齐安卓 WalletScreen）
struct WalletView: View {
    @State private var info: WalletInfo?
    @State private var logs: [WalletLog] = []
    @State private var usdt: UsdtConfig?
    @State private var errorText: String?
    @State private var filter = 0
    @State private var showRecharge = false
    @State private var tip: String?
    @State private var showCs = false
    @State private var rechargeAmount = ""
    @State private var rechargeRemark = ""

    private let filterTitles = ["全部", "收入", "支出"]

    private var shownLogs: [WalletLog] {
        switch filter {
        case 1: return logs.filter { $0.type == 1 }
        case 2: return logs.filter { $0.type != 1 }
        default: return logs
        }
    }

    var body: some View {
        List {
            balanceCard
                .listRowInsets(EdgeInsets(top: 14, leading: 14, bottom: 12, trailing: 14))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            quickRow
                .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 14, trailing: 14))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            listHeader
                .akCardRow(top: true)
                .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if shownLogs.isEmpty {
                Text("暂无收支明细")
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.hint)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .akCardRow(bottom: true)
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 24, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(shownLogs.indices, id: \.self) { index in
                    logRow(shownLogs[index], last: index == shownLogs.count - 1)
                        .akCardRow(bottom: index == shownLogs.count - 1)
                        .listRowInsets(EdgeInsets(top: 0, leading: 14,
                                                  bottom: index == shownLogs.count - 1 ? 24 : 0,
                                                  trailing: 14))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }

            if let errorText {
                Text(errorText)
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.red)
                    .padding(.horizontal, 18)
                    .listRowInsets(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AKColor.bg.ignoresSafeArea())
        .reportsDetailPage()
        .navigationTitle("K币钱包")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showRecharge) {
            rechargeSheet
        }
        .sheet(isPresented: $showCs) {
            NavigationStack { CustomerServiceView() }
        }
        .alert("提示", isPresented: Binding(
            get: { tip != nil },
            set: { if !$0 { tip = nil } }
        )) {
            Button("好", role: .cancel) { tip = nil }
        } message: {
            Text(tip ?? "")
        }
    }

    // MARK: - 余额卡

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("◉ K币余额")
                .font(.system(size: 12.5))
                .foregroundColor(.white.opacity(0.85))
            HStack(alignment: .bottom, spacing: 6) {
                Text("\(info?.coin ?? 0)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                Text("K币")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.bottom, 6)
            }
            .padding(.top, 6)

            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 0.8)
                .padding(.top, 14)
                .padding(.bottom, 12)

            HStack(spacing: 0) {
                balanceCell(value: "↑ \(info?.income ?? 0)", label: "累计收入")
                balanceCell(value: "↓ \(info?.expense ?? 0)", label: "累计支出")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(hex: 0x4FB39B), Color(hex: 0x6C7BE8)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func balanceCell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 快捷入口

    private var quickRow: some View {
        HStack(spacing: 10) {
            Button {
                rechargeAmount = ""
                rechargeRemark = ""
                showRecharge = true
            } label: {
                quickAction("＋", "充值", Color(hex: 0x43C463))
            }
            .buttonStyle(.plain)

            Button {
                tip = "提现功能暂未开放，请使用网页版提交。"
            } label: {
                quickAction("↓", "提现", Color(hex: 0xFF8A3D))
            }
            .buttonStyle(.plain)

            Button {
                tip = "申请记录暂未开放，请使用网页版查看。"
            } label: {
                quickAction("▤", "我的申请", Color(hex: 0x6C8AE4))
            }
            .buttonStyle(.plain)

            Button {
                showCs = true
            } label: {
                quickAction("🎧", "客服", Color(hex: 0x2FA84F))
            }
            .buttonStyle(.plain)
        }
    }

    private func quickAction(_ icon: String, _ title: String, _ color: Color) -> some View {
        VStack(spacing: 7) {
            Text(icon)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            Text(title)
                .font(.system(size: 11.5))
                .foregroundColor(AKColor.sub)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 充值面板

    private var rechargeSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("充值K币")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AKColor.text)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 6) {
                            Text("🎧").font(.system(size: 14))
                            Text("联系客服完成付款")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AKColor.text)
                        }
                        HStack(spacing: 10) {
                            AvatarView(url: nil, name: "客服", size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("在线客服")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AKColor.text)
                                Text("请联系客服获取收款方式")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(AKColor.hint)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(AKColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.top, 10)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AKColor.blueSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if let u = usdt, u.enabled == 1, !u.address.isEmpty {
                        usdtEntry
                    }

                    Text("充值金额 *")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.sub)
                    TextField("请输入想要充值的K币数", text: $rechargeAmount)
                        .keyboardType(.numberPad)
                        .font(.system(size: 15))
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(AKColor.fill)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onChange(of: rechargeAmount) { value in
                            rechargeAmount = String(value.filter { $0.isNumber }.prefix(7))
                        }

                    HStack(spacing: 8) {
                        ForEach([100, 500, 1000, 5000], id: \.self) { v in
                            Button {
                                rechargeAmount = "\(v)"
                            } label: {
                                Text("\(v)")
                                    .font(.system(size: 13))
                                    .foregroundColor(rechargeAmount == "\(v)" ? Color(hex: 0x2FA84F) : AKColor.sub)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(rechargeAmount == "\(v)" ? AKColor.brandSoft : AKColor.fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 6) {
                        Text("备注").font(.system(size: 13)).foregroundColor(AKColor.sub)
                        Text("选填").font(.system(size: 11.5)).foregroundColor(AKColor.placeholder)
                    }
                    TextField("付款方式 / 转账单号等", text: $rechargeRemark)
                        .font(.system(size: 15))
                        .padding(.horizontal, 14)
                        .frame(height: 64, alignment: .topLeading)
                        .padding(.top, 12)
                        .background(AKColor.fill)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onChange(of: rechargeRemark) { value in
                            if value.count > 50 { rechargeRemark = String(value.prefix(50)) }
                        }

                    Button {
                        showRecharge = false
                        showCs = true
                    } label: {
                        Text("联系客服充值")
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
                    .disabled(Int64(rechargeAmount) ?? 0 <= 0)
                    .opacity((Int64(rechargeAmount) ?? 0) > 0 ? 1 : 0.6)

                    Text("当前版本由客服确认到账")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.placeholder)
                        .frame(maxWidth: .infinity)
                }
                .padding(18)
            }
            .background(AKColor.bg)
            .navigationTitle("充值K币")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showRecharge = false }
                }
            }
        }
    }

    // MARK: - USDT 充值入口

    private var usdtEntry: some View {
        NavigationLink {
            UsdtView()
        } label: {
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
                    Text(usdtSubtitle)
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.hint)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AKColor.placeholder)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(AKColor.brandSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var usdtSubtitle: String {
        guard let usdt, usdt.enabled == 1, usdt.rate > 0 else { return "自动识别到账，实时加K币" }
        return "自动识别到账 · 1 USDT ≈ \(Int(usdt.rate)) K币"
    }

    // MARK: - 明细头

    private var listHeader: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(hex: 0x43C463))
                .frame(width: 3, height: 14)
            Text("收支明细")
                .font(.system(size: 14.5, weight: .medium))
                .foregroundColor(AKColor.text)
                .padding(.leading, 6)
            Spacer(minLength: 8)
            HStack(spacing: 0) {
                ForEach(filterTitles.indices, id: \.self) { index in
                    Button {
                        filter = index
                    } label: {
                        Text(filterTitles[index])
                            .font(.system(size: 12, weight: filter == index ? .medium : .regular))
                            .foregroundColor(filter == index ? AKColor.text : AKColor.muted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(filter == index ? AKColor.card : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(AKColor.fill)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(14)
    }

    // MARK: - 明细行

    private func logRow(_ log: WalletLog, last: Bool) -> some View {
        let income = log.type == 1
        let title = (log.remark?.isEmpty == false ? log.remark! : (income ? "收入" : "支出"))
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(income ? "↑" : "↓")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(income ? Color(hex: 0x2FA84F) : AKColor.red)
                    .frame(width: 38, height: 38)
                    .background(income ? AKColor.brandSoft : AKColor.redSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14.5))
                        .foregroundColor(AKColor.text)
                        .lineLimit(1)
                    Text("\(Self.logTime(log.createdAt)) · 余额 \(log.balance)")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.hint)
                }
                Spacer(minLength: 8)
                Text((income ? "+" : "-") + "\(log.amount)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(income ? Color(hex: 0x2FA84F) : AKColor.red)
            }
            .padding(.horizontal, 14)
            .frame(height: 56)

            if !last {
                Rectangle()
                    .fill(AKColor.line)
                    .frame(height: 0.5)
                    .padding(.leading, 62)
            }
        }
    }

    private func load() async {
        do {
            info = try await APIClient.shared.walletInfo()
            logs = try await APIClient.shared.walletLogs().list
            usdt = try? await APIClient.shared.usdtConfig()
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    /// 安卓账单时间：MM-dd HH:mm
    private static func logTime(_ ts: Int64) -> String {
        guard ts > 0 else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)!
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }
}
