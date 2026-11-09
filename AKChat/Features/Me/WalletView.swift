import SwiftUI

struct WalletView: View {
    @State private var info: WalletInfo?
    @State private var logs: [WalletLog] = []
    @State private var errorText: String?

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Text("K币余额").font(.system(size: 12)).foregroundColor(AKColor.sub)
                    Text("\(info?.coin ?? 0)").font(.system(size: 34, weight: .bold)).foregroundColor(AKColor.text)
                    HStack(spacing: 24) {
                        metric("累计收入", "\(info?.income ?? 0)")
                        metric("累计支出", "\(info?.expense ?? 0)")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            Section {
                NavigationLink("USDT 充值") { UsdtView() }
            }
            Section("账单") {
                ForEach(logs) { log in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.remark?.isEmpty == false ? log.remark! : "K币变动")
                                .font(.system(size: 14)).foregroundColor(AKColor.text)
                            Text(TimeText.short(log.createdAt))
                                .font(.system(size: 11)).foregroundColor(AKColor.muted)
                        }
                        Spacer()
                        Text((log.amount >= 0 ? "+" : "") + "\(log.amount)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(log.amount >= 0 ? AKColor.brand : AKColor.red)
                    }
                }
                if logs.isEmpty {
                    Text("暂无账单").font(.system(size: 12)).foregroundColor(AKColor.muted)
                }
            }
            if let errorText {
                Text(errorText).font(.system(size: 12)).foregroundColor(AKColor.red)
            }
        }
        .listStyle(.plain)
        .navigationTitle("钱包")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 15, weight: .semibold)).foregroundColor(AKColor.text)
            Text(title).font(.system(size: 11)).foregroundColor(AKColor.muted)
        }
    }

    private func load() async {
        do {
            info = try await APIClient.shared.walletInfo()
            logs = try await APIClient.shared.walletLogs().list
        } catch {
            errorText = error.localizedDescription
        }
    }
}
