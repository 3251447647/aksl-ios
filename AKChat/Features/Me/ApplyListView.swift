import SwiftUI
import Foundation

/// 充值/提现申请（GET /api/v1/wallet/recharge_logs、/withdraw_logs）
struct ApplyItem: Decodable, Identifiable {
    let id: Int64
    let amount: Int64
    let account: String
    let status: Int
    let remark: String
    let fee: Int64
    let createdAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, amount, account, status, remark, fee
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        amount = (try? c.decode(Int64.self, forKey: .amount)) ?? 0
        account = (try? c.decode(String.self, forKey: .account)) ?? ""
        status = (try? c.decode(Int.self, forKey: .status)) ?? 0
        remark = (try? c.decode(String.self, forKey: .remark)) ?? ""
        fee = (try? c.decode(Int64.self, forKey: .fee)) ?? 0
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
    }
}

struct ApplyListData: Decodable {
    let list: [ApplyItem]

    enum CodingKeys: String, CodingKey { case list }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decode([ApplyItem].self, forKey: .list)) ?? []
    }
}

extension APIClient {
    func rechargeLogs() async throws -> ApplyListData {
        try await get("api/v1/wallet/recharge_logs")
    }

    func withdrawLogs() async throws -> ApplyListData {
        try await get("api/v1/wallet/withdraw_logs")
    }
}

/// 我的申请：充值记录 / 提现记录（对齐安卓 WalletScreen 我的申请面板）
struct ApplyListView: View {
    @State private var tab = 0
    @State private var rechargeLogs: [ApplyItem] = []
    @State private var withdrawLogs: [ApplyItem] = []
    @State private var loading = false
    @State private var errorText: String?

    private let tabTitles = ["充值记录", "提现记录"]

    private var rows: [ApplyItem] {
        tab == 0 ? rechargeLogs : withdrawLogs
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    ForEach(tabTitles.indices, id: \.self) { index in
                        Button {
                            tab = index
                        } label: {
                            Text(tabTitles[index])
                                .font(.system(size: 14, weight: tab == index ? .medium : .regular))
                                .foregroundColor(tab == index ? .white : AKColor.muted)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(tab == index ? Color(hex: 0x43C463) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(AKColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if loading && rows.isEmpty {
                    ProgressView()
                        .padding(.top, 40)
                } else if rows.isEmpty {
                    HStack {
                        Spacer()
                        Text(tab == 0 ? "暂无充值记录" : "暂无提现记录")
                            .font(.system(size: 12.5))
                            .foregroundColor(AKColor.hint)
                        Spacer()
                    }
                    .frame(height: 110)
                    .background(AKColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    ForEach(rows) { item in
                        row(item)
                    }
                }

                if let errorText, !errorText.isEmpty {
                    Text(errorText)
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.red)
                }
            }
            .padding(14)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .reportsDetailPage()
        .navigationTitle("我的申请")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func row(_ item: ApplyItem) -> some View {
        let recharge = tab == 0
        let status = statusStyle(item.status)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.fullTime(item.createdAt))
                    .font(.system(size: 14.5))
                    .foregroundColor(AKColor.text)
                if !item.remark.isEmpty {
                    Text("备注：\(item.remark)")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.hint)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text((recharge ? "+" : "-") + "\(item.amount)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(recharge ? Color(hex: 0x2FA84F) : AKColor.red)
                Text(status.0)
                    .font(.system(size: 11))
                    .foregroundColor(status.1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 2)
                    .background(status.2)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func statusStyle(_ status: Int) -> (String, Color, Color) {
        switch status {
        case 1:
            return ("已完成", Color(hex: 0x2FA84F), AKColor.brandSoft)
        case 2:
            return ("已拒绝", AKColor.red, AKColor.redSoft)
        default:
            return ("待处理", AKColor.gold, AKColor.goldSoft)
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        var failed = false
        do {
            rechargeLogs = try await APIClient.shared.rechargeLogs().list
        } catch {
            failed = true
        }
        do {
            withdrawLogs = try await APIClient.shared.withdrawLogs().list
        } catch {
            failed = true
        }
        if failed && rechargeLogs.isEmpty && withdrawLogs.isEmpty {
            errorText = "加载失败，请下拉重试"
        } else {
            errorText = nil
        }
    }

    /// 安卓申请记录时间：MM月dd日 HH:mm
    private static func fullTime(_ ts: Int64) -> String {
        guard ts > 0 else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)!
        f.dateFormat = "MM月dd日 HH:mm"
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }
}
