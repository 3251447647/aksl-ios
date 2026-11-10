import SwiftUI

/// 每日免费抽奖：顶部次数卡 + 幸运大转盘 + 中奖记录（对齐安卓 LotteryScreen）
struct LotteryView: View {
    @EnvironmentObject private var app: AppState

    @State private var info: LotteryInfo?
    @State private var loading = true
    @State private var loadFailed = false
    @State private var spinning = false
    @State private var drawMode = "free"
    @State private var rotation: Double = 0
    @State private var won: WonPrize?
    @State private var toastText: String?
    @State private var toastToken = 0
    @State private var spinTask: Task<Void, Never>?

    private struct WonPrize: Identifiable {
        let id = UUID()
        let prize: LotteryPrize
        let grant: LotteryGrant?
    }

    private static let recordTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }()

    private var prizes: [LotteryPrize] {
        if let list = info?.prizes, !list.isEmpty { return list }
        return LotteryPrize.placeholders
    }

    private var ready: Bool {
        guard let info else { return false }
        return !info.prizes.isEmpty
    }

    private var freeLeft: Int { info?.freeLeft ?? 0 }
    private var cost: Int { info?.cost ?? 0 }
    private var balance: Int64 { info?.balance ?? 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                wheelCard
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                recordsCard
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                Spacer().frame(height: 24)
            }
        }
        .background(AKColor.bg.ignoresSafeArea())
        .reportsDetailPage()
        .restoresSwipeBack()
        .navigationTitle("每日免费抽奖")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
        .task { await load() }
        .onDisappear { spinTask?.cancel() }
        .overlay(alignment: .bottom) { toastView }
        .overlay {
            if let won {
                PrizeResultCard(prize: won.prize, grant: won.grant) {
                    dismissResult()
                }
            }
        }
    }

    // MARK: - 顶部次数卡

    private var hero: some View {
        let freeTotal = info?.freeTotal ?? 0
        let fraction: Double = freeTotal > 0
            ? min(max(Double(freeLeft) / Double(freeTotal), 0), 1)
            : 0
        return ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [Color(hex: 0x0CBF68), Color(hex: 0x059E4F), Color(hex: 0x047A3F)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Circle()
                .fill(RadialGradient(
                    colors: [Color(hex: 0xFFD37A).opacity(0.42), .clear],
                    center: .center, startRadius: 0, endRadius: 66
                ))
                .frame(width: 132, height: 132)
                .offset(x: 44, y: -46)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text("今日免费抽奖")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text("天天有奖")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color(hex: 0xF0A51E))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Spacer(minLength: 0)
                    Text("🎁").font(.system(size: 20))
                }

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(info == nil ? "…" : "\(freeLeft)")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.white)
                    Text(" / \(freeTotal) 次")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.leading, 2)
                }
                .padding(.top, 12)

                Text("今日剩余免费次数")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.72))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.16))
                        Capsule()
                            .fill(LinearGradient(
                                colors: [Color(hex: 0xFFD37A), Color(hex: 0xF0A51E)],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * CGFloat(fraction))
                    }
                }
                .frame(height: 5)
                .padding(.top, 10)

                HStack(spacing: 10) {
                    heroStat(label: "单次消耗",
                             value: info == nil ? "—" : "\(cost) K币",
                             color: Color(hex: 0xFFD37A))
                    heroStat(label: "当前余额",
                             value: info == nil ? "—" : "\(balance) K币",
                             color: .white)
                }
                .padding(.top, 14)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func heroStat(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10.5))
                .foregroundColor(.white.opacity(0.66))
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    // MARK: - 转盘

    private var wheelCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("幸运大转盘")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AKColor.text)
                Text("转一转，好运来")
                    .font(.system(size: 11))
                    .foregroundColor(AKColor.muted)
                Spacer(minLength: 0)
                Text(statusBadge)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(AKColor.brand)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(AKColor.brand.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            LotteryWheelView(prizes: prizes, rotation: rotation, spinning: spinning) {
                startDraw(freeLeft > 0 ? "free" : "coin")
            }
            .frame(maxWidth: 320)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            if info == nil && loadFailed {
                Button {
                    Task { await retry() }
                } label: {
                    Text("加载失败，点击重试")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AKColor.brand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Text(wheelHint)
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.muted)
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: 10) {
                drawButton(
                    title: "免费抽一次",
                    subtitle: freeLeft > 0 ? "剩余 \(freeLeft) 次" : "今日已用完",
                    enabled: ready && !spinning && freeLeft > 0,
                    loading: spinning && drawMode == "free",
                    primary: true
                ) {
                    startDraw("free")
                }
                drawButton(
                    title: "K币抽一次",
                    subtitle: ready ? "\(cost) K币/次" : "加载中…",
                    enabled: ready && !spinning && balance >= Int64(cost),
                    loading: spinning && drawMode == "coin",
                    primary: false
                ) {
                    startDraw("coin")
                }
            }
            .padding(.top, 12)

            if let limitHint {
                Text(limitHint)
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
        }
        .padding(12)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var statusBadge: String {
        if info == nil && loading { return "加载中" }
        if !ready { return "待开放" }
        return "\(info?.prizes.count ?? 0) 个奖项"
    }

    private var wheelHint: String {
        if spinning { return "正在开奖…" }
        if info == nil { return "奖品加载中，请稍候" }
        if !ready { return "奖品正在准备中，敬请期待" }
        return "点击中央按钮开始抽奖，奖品必中"
    }

    private var limitHint: String? {
        guard ready else { return nil }
        if freeLeft <= 0 && balance < Int64(cost) {
            return "今日免费次数已用完，K币余额不足，请先到钱包充值"
        }
        if freeLeft <= 0 { return "今日免费次数已用完，可用 K币继续抽奖" }
        if balance < Int64(cost) { return "K币余额不足，请先到钱包充值" }
        return nil
    }

    private func drawButton(
        title: String,
        subtitle: String,
        enabled: Bool,
        loading: Bool,
        primary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let textColor: Color = (!enabled && !loading)
            ? AKColor.placeholder
            : (primary ? .white : Color(hex: 0x3A2A08))
        return Button(action: action) {
            VStack(spacing: 2) {
                if loading {
                    ProgressView()
                        .tint(textColor)
                        .scaleEffect(0.8)
                    Text("抽奖中…")
                        .font(.system(size: 10.5))
                        .foregroundColor(textColor)
                } else {
                    Text(title)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundColor(textColor)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(textColor.opacity(0.72))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(buttonBackground(enabled: enabled, loading: loading, primary: primary))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    @ViewBuilder
    private func buttonBackground(enabled: Bool, loading: Bool, primary: Bool) -> some View {
        if !enabled && !loading {
            AKColor.fill
        } else if primary {
            LinearGradient(
                colors: [Color(hex: 0x0CBF68), Color(hex: 0x059E4F)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                colors: [Color(hex: 0xFFD37A), Color(hex: 0xF0A51E)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - 中奖记录

    private var recordsCard: some View {
        let records = info?.records ?? []
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("中奖记录")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AKColor.text)
                Text("好运连连")
                    .font(.system(size: 11))
                    .foregroundColor(AKColor.muted)
                Spacer(minLength: 0)
                Text("最近 \(records.count) 次")
                    .font(.system(size: 11))
                    .foregroundColor(AKColor.muted)
            }

            if records.isEmpty {
                Text("还没有中奖记录，快来试试手气")
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            } else {
                ForEach(Array(records.prefix(10)).indices, id: \.self) { index in
                    if index > 0 {
                        Rectangle()
                            .fill(AKColor.line)
                            .frame(height: 0.6)
                            .padding(.leading, 48)
                    }
                    recordRow(records[index])
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func recordRow(_ record: LotteryRecord) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(recordIconGradient(record.type))
                PrizeIcon(type: record.type, name: record.name, size: 24)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(recordTitle(record))
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(AKColor.text)
                    .lineLimit(1)
                HStack(alignment: .top, spacing: 6) {
                    Text(recordSubtitle(record))
                        .font(.system(size: 11.5))
                        .foregroundColor(record.grant != nil ? AKColor.brand : AKColor.muted)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(formatRecordTime(record.createdAt))
                        .font(.system(size: 10.5))
                        .foregroundColor(AKColor.placeholder)
                        .padding(.top, 1)
                }
            }
        }
        .padding(.vertical, 10)
    }

    private func recordTitle(_ record: LotteryRecord) -> String {
        let base = record.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return lotteryTitleWithAmount(
            base: base.isEmpty ? "神秘奖品" : base,
            type: record.type, value: record.value, amount: recordAmountShort(record)
        )
    }

    private func recordAmountShort(_ record: LotteryRecord) -> String {
        switch record.type.lowercased() {
        case "coin", "coins", "kcoin", "money": return "\(record.value) K币"
        case "vip", "svip": return "\(record.value) 天"
        case "pretty": return "靓号"
        case "none", "empty", "thanks": return ""
        default: return record.value > 0 ? "×\(record.value)" : ""
        }
    }

    /// 实际发放以服务端 grant 为准；没有 grant 时只描述奖品本体，不臆造折算
    private func recordSubtitle(_ record: LotteryRecord) -> String {
        var actual: String
        let note = record.grant?.note.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !note.isEmpty {
            actual = note
        } else if let grant = record.grant {
            actual = "实际发放：\(grantAmountText(record, grant))"
        } else {
            actual = "奖品：\(recordActualFallback(record))"
        }
        let costText: String
        if record.cost > 0 {
            costText = "消耗 \(record.cost) K币"
        } else if record.mode.lowercased() == "free" {
            costText = "免费"
        } else {
            costText = ""
        }
        return costText.isEmpty ? actual : "\(actual) · \(costText)"
    }

    /// grant.days 缺失时用奖品天数兜底，避免出现「+0 天」
    private func grantAmountText(_ record: LotteryRecord, _ grant: LotteryGrant) -> String {
        let days = grant.days > 0 ? grant.days : record.value
        switch grant.type.lowercased() {
        case "vip", "svip": return "\(lotteryGrantTypeLabel(grant.type)) +\(days) 天"
        case "coin", "coins", "kcoin", "money": return "K币 +\(record.value)"
        case "pretty": return "靓号"
        case "none", "empty", "thanks": return "谢谢惠顾"
        default:
            return days > 0 ? "\(lotteryGrantTypeLabel(grant.type)) +\(days) 天" : lotteryGrantTypeLabel(grant.type)
        }
    }

    private func recordActualFallback(_ record: LotteryRecord) -> String {
        switch record.type.lowercased() {
        case "coin", "coins", "kcoin", "money": return "K币 +\(record.value)"
        case "vip": return "VIP +\(record.value) 天"
        case "svip": return "SVIP +\(record.value) 天"
        case "pretty": return "靓号"
        case "none", "empty", "thanks": return "谢谢惠顾"
        default:
            if record.name.contains("谢谢") { return "谢谢惠顾" }
            return record.value > 0 ? "×\(record.value)" : "奖励"
        }
    }

    private func recordIconGradient(_ type: String) -> LinearGradient {
        switch type.lowercased() {
        case "coin", "coins", "kcoin", "money":
            return LinearGradient(colors: [Color(hex: 0xFFE7AE), Color(hex: 0xF5B024)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case "vip":
            return LinearGradient(colors: [Color(hex: 0xFFE9C0), Color(hex: 0xE9A015)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case "svip":
            return LinearGradient(colors: [Color(hex: 0xE9DAFF), Color(hex: 0xA375FF)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case "pretty":
            return LinearGradient(colors: [Color(hex: 0xD9F8E7), Color(hex: 0x27B673)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [Color(hex: 0xEFF2F5), Color(hex: 0xB9C2CA)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func formatRecordTime(_ ts: Int64) -> String {
        guard ts > 0 else { return "" }
        let seconds = ts < 10_000_000_000 ? Double(ts) : Double(ts) / 1000
        return Self.recordTimeFormatter.string(from: Date(timeIntervalSince1970: seconds))
    }

    // MARK: - 数据

    private func load(silent: Bool = false) async {
        if !silent && info == nil { loading = true }
        do {
            info = try await APIClient.shared.lotteryInfo()
            loadFailed = false
        } catch {
            if info == nil { loadFailed = true }
            if !silent { showToast(error.localizedDescription) }
        }
        loading = false
    }

    private func retry() async {
        loadFailed = false
        loading = true
        await load()
    }

    private func startDraw(_ mode: String) {
        guard !spinning else { return }
        guard let data = info, !data.prizes.isEmpty else {
            showToast(loadFailed ? "抽奖信息加载失败，请重试" : "奖品正在准备中，请稍后再试")
            return
        }
        if mode == "free" && data.freeLeft <= 0 {
            showToast("今日免费次数已用完")
            return
        }
        if mode == "coin" && data.balance < Int64(data.cost) {
            showToast("K币余额不足，请先充值")
            return
        }

        spinning = true
        drawMode = mode
        let prizes = data.prizes
        spinTask?.cancel()
        spinTask = Task { @MainActor in
            /* 等接口期间匀速空转，结果回来后再减速落点 */
            let pending = Task { @MainActor in
                while !Task.isCancelled {
                    withAnimation(.linear(duration: 1)) {
                        rotation += 1080
                    }
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
            defer { pending.cancel() }

            do {
                let result = try await APIClient.shared.lotteryDraw(mode: mode)
                pending.cancel()
                if var current = info {
                    current.balance = result.balance
                    current.freeLeft = result.freeLeft
                    info = current
                }
                if let prize = result.prize {
                    await land(on: prize, prizes: prizes)
                    spinning = false
                    won = WonPrize(prize: prize, grant: result.grant)
                } else {
                    spinning = false
                    showToast("抽奖成功，奖励已发放")
                    await load(silent: true)
                }
                if let me = try? await APIClient.shared.me() {
                    app.user = me
                }
            } catch {
                pending.cancel()
                spinning = false
                showToast(error.localizedDescription)
            }
        }
    }

    /// 指针在正上方：让命中的扇区中心停在 -90°，再补 5 圈
    private func land(on prize: LotteryPrize, prizes: [LotteryPrize]) async {
        let count = max(prizes.count, 1)
        let sweep = 360.0 / Double(count)
        var index = prizes.firstIndex { $0.id == prize.id } ?? -1
        if index < 0 {
            index = prizes.firstIndex { $0.name == prize.name } ?? 0
        }
        let target = normalize360(-(Double(index) + 0.5) * sweep)
        var delta = normalize360(target - normalize360(rotation))
        if delta < 10 { delta += 360 }
        withAnimation(.timingCurve(0.12, 0.66, 0.04, 1, duration: 3.0)) {
            rotation += 360 * 5 + delta
        }
        try? await Task.sleep(nanoseconds: 3_000_000_000)
    }

    private func normalize360(_ value: Double) -> Double {
        var result = value.truncatingRemainder(dividingBy: 360)
        if result < 0 { result += 360 }
        return result
    }

    private func dismissResult() {
        won = nil
        Task {
            await load(silent: true)
            if let me = try? await APIClient.shared.me() {
                app.user = me
            }
        }
    }

    // MARK: - Toast

    private var toastView: some View {
        Group {
            if let toastText {
                Text(toastText)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.bottom, 40)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toastText)
    }

    private func showToast(_ text: String) {
        toastText = text
        toastToken += 1
        let token = toastToken
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                if token == toastToken { toastText = nil }
            }
        }
    }
}

// MARK: - 开奖弹窗

private struct PrizeResultCard: View {
    let prize: LotteryPrize
    let grant: LotteryGrant?
    let onClose: () -> Void

    @State private var shown = false

    private var actualText: String {
        let note = grant?.note.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !note.isEmpty { return note }
        guard let grant else {
            return prize.amountText.isEmpty
                ? (prize.name.isEmpty ? "神秘奖品" : prize.name)
                : prize.amountText
        }
        switch grant.type.lowercased() {
        case "vip", "svip": return "\(lotteryGrantTypeLabel(grant.type)) +\(grant.days) 天"
        case "coin", "coins", "kcoin", "money": return "K币 +\(prize.value)"
        case "pretty":
            if let number = prize.prettyNumber, !number.isEmpty { return "靓号 \(number)" }
            return "靓号奖励"
        case "none", "empty", "thanks": return "谢谢惠顾"
        default:
            if grant.days > 0 {
                return "\(lotteryGrantTypeLabel(grant.type)) +\(grant.days) 天"
            }
            return prize.amountText.isEmpty ? prize.displayText : prize.amountText
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            VStack(spacing: 0) {
                Text("恭喜中奖")
                    .font(.system(size: 13, weight: .medium))
                    .tracking(2)
                    .foregroundColor(Color(hex: 0xB07A12))

                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color(hex: 0xFFD98A).opacity(0.55),
                                     Color(hex: 0xFFC24A).opacity(0.20), .clear],
                            center: .center, startRadius: 0, endRadius: 66
                        ))
                        .frame(width: 132, height: 132)
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color(hex: 0xFFF3D2), Color(hex: 0xFFC24A)],
                            center: .center, startRadius: 0, endRadius: 48
                        ))
                        .frame(width: 96, height: 96)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.75), lineWidth: 2))
                    PrizeIcon(type: prize.type, name: prize.name, size: 50)
                }
                .frame(width: 132, height: 132)
                .padding(.top, 12)

                Text(prize.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                     ? "神秘奖品" : prize.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: 0x3A2A08))
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)

                VStack(spacing: 5) {
                    PrizeInfoRow(label: "奖品", value: prize.displayText)
                    PrizeInfoRow(label: "实际到账", value: actualText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.58))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .padding(.top, 10)

                Button(action: onClose) {
                    Text("开心收下")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(LinearGradient(
                            colors: [Color(hex: 0x0CBF68), Color(hex: 0x059E4F)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 20)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
            .background(LinearGradient(
                colors: [Color(hex: 0xFFF7E3), Color(hex: 0xFFE1A4)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(.horizontal, 38)
            .scaleEffect(shown ? 1 : 0.68)
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                shown = true
            }
        }
    }
}

private struct PrizeInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundColor(Color(hex: 0x9A6A0B).opacity(0.82))
                .frame(width: 62, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: 0x3A2A08))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
