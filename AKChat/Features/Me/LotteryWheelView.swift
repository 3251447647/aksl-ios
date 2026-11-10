import SwiftUI
import Foundation

/// 转盘配色与安卓 LotteryWheel.kt 一致：深浅绿扇面 + 金色外环
private enum WheelTone {
    static let faceDark = Color(hex: 0x0B6B3A)
    static let faceLight = Color(hex: 0x0E8A4A)
    static let ringGold = Color(hex: 0xFFD46E)
    static let ringGoldDeep = Color(hex: 0xE49312)
    static let ringGoldDark = Color(hex: 0x9C5E05)
    static let ringGoldLight = Color(hex: 0xFFF4D0)
    static let textGold = Color(hex: 0xFFD46E)
    static let buttonGreen = Color(hex: 0x0B6B3A)
    static let cardFill = Color(hex: 0x021C10, alpha: 0.25)
    static let cardBorder = Color(hex: 0xFFD46E, alpha: 0.20)
}

/// 扇区 / 卡片的几何口径，全部按盘面半径等比换算
private struct WheelMetrics {
    let side: CGFloat
    let sweep: Double
    let compact: Bool
    let shortTitle: Bool
    let titleSize: CGFloat
    let amountSize: CGFloat
    let iconSize: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let textRadius: CGFloat
    let iconRadius: CGFloat
    let outer: CGFloat
    let ring: CGFloat
    let face: CGFloat

    var center: CGPoint { CGPoint(x: side / 2, y: side / 2) }

    init(side: CGFloat, count: Int) {
        let total = max(count, 1)
        self.side = side
        outer = side / 2
        ring = outer * 0.072
        face = outer - ring * 1.12
        sweep = 360.0 / Double(total)
        compact = count > 8
        shortTitle = count >= 7
        titleSize = compact ? 11 : 13
        amountSize = compact ? 9.5 : 11
        iconSize = compact ? 22 : 24

        let vPad: CGFloat = compact ? 2.5 : 3
        let lineGap: CGFloat = compact ? 1 : 1.5
        cardHeight = titleSize * 1.2 + lineGap + amountSize * 1.2 + vPad * 2
        textRadius = face * (compact ? 0.66 : 0.60)
        let innerRadius = max(textRadius - cardHeight / 2, face * 0.18)
        let chord = 2 * innerRadius * CGFloat(sin(sweep * Double.pi / 360))
        cardWidth = min(max(chord * 0.95, 20), face * 0.72)
        iconRadius = min(textRadius + cardHeight / 2 + 4 + iconSize / 2, face * 0.93 - iconSize / 2)
    }
}

struct LotteryWheelView: View {
    let prizes: [LotteryPrize]
    let rotation: Double
    let spinning: Bool
    let onSpin: () -> Void

    var body: some View {
        GeometryReader { geo in
            let side = max(min(geo.size.width, geo.size.height), 1)
            let m = WheelMetrics(side: side, count: prizes.count)
            ZStack {
                /* 外发光：转动时更亮 */
                Circle()
                    .fill(WheelTone.ringGold.opacity(spinning ? 0.45 : 0.20))
                    .frame(width: m.outer * 2, height: m.outer * 2)
                    .blur(radius: m.outer * 0.09)
                    .animation(.easeInOut(duration: 0.35), value: spinning)

                Canvas { context, _ in
                    drawRim(context: &context, m: m)
                }

                ZStack {
                    Canvas { context, _ in
                        drawFace(context: &context, m: m)
                    }
                    ForEach(prizes.indices, id: \.self) { index in
                        cardLayer(index: index, m: m)
                    }
                }
                .rotationEffect(.degrees(rotation))

                /* 中心金托：露在白钮外的一圈金边 */
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(hex: 0xFFF2C6), WheelTone.ringGold, WheelTone.ringGoldDeep],
                        center: .center, startRadius: 0, endRadius: m.face * 0.385
                    ))
                    .frame(width: m.face * 0.77, height: m.face * 0.77)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.20), lineWidth: 1.4))

                centerButton
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                pointer.offset(y: -3)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - 扇区与卡片

    private func cardLayer(index: Int, m: WheelMetrics) -> some View {
        let prize = prizes[index]
        let layout = textLayout(index: index, m: m)
        return ZStack {
            prizeCard(prize, m: m)
                .offset(y: layout.flipped ? m.textRadius : -m.textRadius)
            PrizeIcon(type: prize.type, name: prize.name, size: m.iconSize, glyphScale: 0.92)
                .offset(y: layout.flipped ? m.iconRadius : -m.iconRadius)
        }
        .frame(width: m.side, height: m.side)
        .rotationEffect(.degrees(layout.drawAngle))
    }

    /// 卡片沿扇区中线摆放，文字随盘面转动；下半圈翻转 180°，保证不会倒着读
    private func textLayout(index: Int, m: WheelMetrics) -> (flipped: Bool, drawAngle: Double) {
        var textAngle = -90 + (Double(index) + 0.5) * m.sweep + 90
        while textAngle > 180 { textAngle -= 360 }
        while textAngle < -180 { textAngle += 360 }
        let flipped = abs(textAngle) > 90
        return (flipped, flipped ? textAngle + 180 : textAngle)
    }

    private func prizeCard(_ prize: LotteryPrize, m: WheelMetrics) -> some View {
        VStack(spacing: m.compact ? 1 : 1.5) {
            Text(clampWheelTitle(prize.wheelTitle(compact: m.shortTitle)))
                .font(.system(size: m.titleSize, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .shadow(color: .black.opacity(0.6), radius: 1.2, x: 0, y: 0.6)
            Text(prize.wheelAmount)
                .font(.system(size: m.amountSize))
                .foregroundColor(WheelTone.textGold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .shadow(color: .black.opacity(0.6), radius: 1.1, x: 0, y: 0.5)
        }
        .padding(.horizontal, 3)
        .frame(width: m.cardWidth, height: m.cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(WheelTone.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(WheelTone.cardBorder, lineWidth: 0.7)
        )
    }

    private func clampWheelTitle(_ text: String) -> String {
        text.count > 6 ? String(text.prefix(6)) : text
    }

    // MARK: - Canvas

    /// 外环、灯珠与描边：不随盘面转动
    private func drawRim(context: inout GraphicsContext, m: WheelMetrics) {
        let center = m.center
        let ringRadius = m.outer - m.ring / 2

        context.stroke(
            circlePath(center: center, radius: ringRadius),
            with: .conicGradient(
                Gradient(colors: [
                    WheelTone.ringGoldLight, WheelTone.ringGold, WheelTone.ringGoldDeep,
                    WheelTone.ringGoldDark, WheelTone.ringGold, WheelTone.ringGoldLight
                ]),
                center: center
            ),
            lineWidth: m.ring
        )

        context.stroke(
            circlePath(center: center, radius: m.face + m.ring * 0.06),
            with: .color(.black.opacity(0.24)),
            lineWidth: 1.4
        )
        context.stroke(
            circlePath(center: center, radius: m.outer - 0.8),
            with: .color(.white.opacity(0.52)),
            lineWidth: 1.2
        )

        let bead = max(m.ring * 0.19, 1.5)
        for k in 0..<12 {
            let rad = (-90.0 + Double(k) * 30.0) * Double.pi / 180
            let pos = CGPoint(
                x: center.x + CGFloat(cos(rad)) * ringRadius,
                y: center.y + CGFloat(sin(rad)) * ringRadius
            )
            context.fill(circlePath(center: pos, radius: bead * 2.4),
                         with: .color(WheelTone.ringGoldLight.opacity(spinning ? 0.32 : 0.18)))
            context.fill(circlePath(center: pos, radius: bead),
                         with: .color(Color(hex: 0xFFF8E2)))
            context.fill(circlePath(center: pos, radius: bead * 0.42),
                         with: .color(.white.opacity(0.90)))
        }
    }

    /// 盘面：左右交替的深浅绿扇区 + 径向高光
    private func drawFace(context: inout GraphicsContext, m: WheelMetrics) {
        let center = m.center
        let count = prizes.count
        guard count > 0 else { return }

        for i in 0..<count {
            let start = -90 + Double(i) * m.sweep
            let sector = sectorPath(center: center, radius: m.face, start: start, sweep: m.sweep)
            context.fill(sector, with: .color(i % 2 == 0 ? WheelTone.faceDark : WheelTone.faceLight))
        }

        for i in 0..<count {
            let rad = (-90.0 + Double(i) * m.sweep) * Double.pi / 180
            var line = Path()
            line.move(to: center)
            line.addLine(to: CGPoint(
                x: center.x + CGFloat(cos(rad)) * m.face,
                y: center.y + CGFloat(sin(rad)) * m.face
            ))
            context.stroke(line, with: .color(Color(hex: 0xFFE7A8).opacity(0.20)), lineWidth: 1)
        }

        let highlight = CGPoint(x: center.x, y: center.y - m.face * 0.18)
        context.fill(
            circlePath(center: center, radius: m.face),
            with: .radialGradient(
                Gradient(colors: [.white.opacity(0.20), .white.opacity(0.045), .black.opacity(0.22)]),
                center: highlight, startRadius: 0, endRadius: m.face * 1.22
            )
        )

        if spinning {
            context.fill(
                circlePath(center: center, radius: m.face),
                with: .conicGradient(Gradient(colors: [.clear, .white.opacity(0.14), .clear]), center: center)
            )
        }

        context.stroke(
            circlePath(center: center, radius: m.face - 0.5),
            with: .color(Color(hex: 0xFFE7A8).opacity(0.32)),
            lineWidth: 1
        )
    }

    /// 手写扇形：角度按屏幕坐标顺时针增长，与安卓 drawArc 口径一致
    private func sectorPath(center: CGPoint, radius: CGFloat, start: Double, sweep: Double) -> Path {
        var path = Path()
        path.move(to: center)
        let steps = max(Int(sweep / 4), 2)
        for step in 0...steps {
            let angle = (start + sweep * Double(step) / Double(steps)) * Double.pi / 180
            path.addLine(to: CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            ))
        }
        path.closeSubpath()
        return path
    }

    private func circlePath(center: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ))
    }

    // MARK: - 指针与中心按钮

    private var pointer: some View {
        ZStack {
            PointerTriangle()
                .fill(Color.black.opacity(0.24))
                .offset(y: 2)
            PointerTriangle()
                .fill(LinearGradient(
                    colors: [Color(hex: 0xFFF8DE), WheelTone.ringGold, WheelTone.ringGoldDeep],
                    startPoint: .top, endPoint: .bottom
                ))
            PointerTriangle()
                .stroke(Color.white.opacity(0.92), lineWidth: 1.5)
            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 3, height: 3)
                .offset(y: -7)
        }
        .frame(width: 28, height: 30)
    }

    private var centerButton: some View {
        Button(action: onSpin) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(hex: 0xFFF8E4), WheelTone.ringGold, WheelTone.ringGoldDeep],
                        center: .center, startRadius: 0, endRadius: 46
                    ))
                    .overlay(Circle().strokeBorder(WheelTone.ringGoldLight.opacity(0.85), lineWidth: 1))
                Circle()
                    .fill(LinearGradient(
                        colors: [.white, Color(hex: 0xFFFFFBF0)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay(
                        Circle().strokeBorder(
                            LinearGradient(
                                colors: [WheelTone.ringGoldLight, WheelTone.ringGold, WheelTone.ringGoldDeep],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    )
                    .padding(3)
                if spinning {
                    VStack(spacing: 3) {
                        ProgressView()
                            .tint(WheelTone.buttonGreen)
                            .scaleEffect(0.85)
                        Text("开奖中")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(WheelTone.buttonGreen)
                    }
                } else {
                    VStack(spacing: 1) {
                        Text("抽奖")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(WheelTone.buttonGreen)
                        Text("LUCKY")
                            .font(.system(size: 8, weight: .semibold))
                            .tracking(1.6)
                            .foregroundColor(WheelTone.ringGoldDeep)
                    }
                }
            }
            .frame(width: 92, height: 92)
            .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(spinning)
    }
}

private struct PointerTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.minY + rect.height * 0.12))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.90, y: rect.minY + rect.height * 0.12))
        path.closeSubpath()
        return path
    }
}

/// 奖品图标：coin→🪙 vip→👑 svip→💎 pretty→⭐ 无中奖画灰色笑脸
struct PrizeIcon: View {
    let type: String
    let name: String
    var size: CGFloat = 24
    /// 转盘上是 0.92（同安卓 Canvas），列表/弹窗是 0.70
    var glyphScale: CGFloat = 0.70

    var body: some View {
        Group {
            if emoji.isEmpty {
                Canvas { context, canvasSize in
                    drawSmiley(context: &context, size: canvasSize)
                }
                .frame(width: size * glyphScale, height: size * glyphScale)
            } else {
                Text(emoji)
                    .font(.system(size: size * glyphScale))
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
    }

    private var emoji: String {
        let lower = type.lowercased()
        switch lower {
        case "coin", "coins", "kcoin", "money": return "🪙"
        case "vip": return "👑"
        case "svip": return "💎"
        case "pretty": return "⭐"
        case "none", "empty", "thanks": return ""
        default:
            if name.contains("谢谢") || name.contains("感谢参与") { return "" }
            if name.contains("币") { return "🪙" }
            let upper = name.uppercased()
            if upper.contains("SVIP") { return "💎" }
            if upper.contains("VIP") || name.contains("会员") { return "👑" }
            if name.contains("靓号") || name.contains("号码") { return "⭐" }
            return "🎁"
        }
    }

    /// 灰色笑脸：只在无中奖时出现
    private func drawSmiley(context: inout GraphicsContext, size: CGSize) {
        let radius = min(size.width, size.height) / 2
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let face = Path(ellipseIn: CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ))
        context.fill(face, with: .color(Color(hex: 0x9AA3AB)))

        let eye = Color(hex: 0x59636B)
        let eyeRadius = radius * 0.12
        for dx in [-0.32, 0.32] {
            let pos = CGPoint(x: center.x + radius * CGFloat(dx), y: center.y - radius * 0.18)
            context.fill(circlePath(center: pos, radius: eyeRadius), with: .color(eye))
        }

        var mouth = Path()
        mouth.move(to: CGPoint(x: center.x - radius * 0.34, y: center.y + radius * 0.10))
        mouth.addQuadCurve(
            to: CGPoint(x: center.x + radius * 0.34, y: center.y + radius * 0.10),
            control: CGPoint(x: center.x, y: center.y + radius * 0.48)
        )
        context.stroke(
            mouth,
            with: .color(eye),
            style: StrokeStyle(lineWidth: max(radius * 0.13, 1), lineCap: .round)
        )
    }

    private func circlePath(center: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ))
    }
}

// MARK: - 奖品文案

extension LotteryPrize {
    /// 转盘名称：扇区多时用短名，避免卡片里挤成两行
    func wheelTitle(compact: Bool) -> String {
        let full: String
        switch type.lowercased() {
        case "coin", "coins", "kcoin", "money": full = "K币"
        case "vip": full = "VIP 会员"
        case "svip": full = "SVIP 会员"
        case "pretty": full = "靓号"
        case "none", "empty", "thanks": full = "谢谢惠顾"
        default:
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            full = trimmed.isEmpty ? "神秘奖品" : trimmed
        }
        guard compact else { return full }
        switch type.lowercased() {
        case "coin", "coins", "kcoin", "money": return "K币"
        case "vip": return "VIP"
        case "svip": return "SVIP"
        case "pretty": return "靓号"
        case "none", "empty", "thanks": return "谢谢"
        default: return full
        }
    }

    var wheelAmount: String {
        switch type.lowercased() {
        case "coin", "coins", "kcoin", "money": return "\(value) K币"
        case "vip", "svip": return "\(value) 天"
        case "pretty": return "奖励"
        case "none", "empty", "thanks": return "下次好运"
        case "loading": return "…"
        default:
            if name.contains("谢谢") { return "下次好运" }
            return value > 0 ? "×\(value)" : "奖励"
        }
    }

    /// 开奖弹窗与记录里的数量文案
    var amountText: String {
        switch type.lowercased() {
        case "coin", "coins", "kcoin", "money": return "+\(value) K币"
        case "vip": return "VIP \(value)天"
        case "svip": return "SVIP \(value)天"
        case "pretty":
            if let prettyNumber, !prettyNumber.isEmpty { return "靓号 \(prettyNumber)" }
            return "靓号奖励"
        case "none", "empty", "thanks": return "谢谢惠顾"
        default:
            if name.contains("谢谢") { return "谢谢惠顾" }
            return value > 0 ? "×\(value)" : ""
        }
    }

    var displayText: String {
        let base = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return lotteryTitleWithAmount(
            base: base.isEmpty ? "神秘奖品" : base,
            type: type, value: value, amount: amountText
        )
    }
}

/// 名称里没有数量时补上，已经有了就不重复
func lotteryTitleWithAmount(base: String, type: String, value: Int, amount: String) -> String {
    if amount.isEmpty { return base }
    if base.contains(amount) { return base }
    if value > 0 && base.contains("\(value)") { return base }
    switch type.lowercased() {
    case "coin", "coins", "kcoin", "money":
        return base.contains("币") ? "\(base) \(value)" : "\(base) \(amount)"
    case "vip", "svip":
        let upper = base.uppercased()
        if upper.contains("VIP") || base.contains("会员") {
            return "\(base) \(value) 天"
        }
        return "\(base) \(amount)"
    case "pretty", "none", "empty", "thanks":
        return base
    default:
        return "\(base) \(amount)"
    }
}

func lotteryGrantTypeLabel(_ type: String) -> String {
    switch type.lowercased() {
    case "vip": return "VIP"
    case "svip": return "SVIP"
    case "coin", "coins", "kcoin", "money": return "K币"
    case "pretty": return "靓号"
    case "none", "empty", "thanks": return "谢谢惠顾"
    default:
        let trimmed = type.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "奖励" : trimmed.uppercased()
    }
}
