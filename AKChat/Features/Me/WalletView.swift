import SwiftUI

/// K币钱包：余额卡 + 快捷入口 + 收支明细（对齐安卓 WalletScreen）
struct WalletView: View {
    @State private var info: WalletInfo?
    @State private var logs: [WalletLog] = []
    @State private var errorText: String?
    @State private var filter = 0

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
        .navigationTitle("K币钱包")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
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
            NavigationLink {
                UsdtView()
            } label: {
                quickAction("＋", "充值", Color(hex: 0x43C463))
            }
            .buttonStyle(.plain)

            Link(destination: URL(string: "https://www.aksliao.cn/service.php")!) {
                quickAction("🎧", "客服", Color(hex: 0x2FA84F))
            }
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
                    Text("\(TimeText.short(log.createdAt)) · 余额 \(log.balance)")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.hint)
                }
                Spacer(minLength: 8)
                Text((income ? "+" : "-") + "\(log.amount)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(income ? Color(hex: 0x2FA84F) : AKColor.red)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

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
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }
}
