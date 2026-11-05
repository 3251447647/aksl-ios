import SwiftUI
import UIKit

/// 与安卓 Design.kt 的色板一致；同一组颜色跟随系统深浅色自动切换
enum AKColor {
    static let bg = dynamic(0xF6F7F9, 0x121417)
    static let card = dynamic(0xFFFFFF, 0x1C1F24)
    static let cardAlt = dynamic(0xFBFBFC, 0x20242A)
    static let text = dynamic(0x111827, 0xE8EAED)
    static let sub = dynamic(0x6B7280, 0x9CA3B0)
    static let muted = dynamic(0x9AA0AC, 0x7C838F)
    static let hint = dynamic(0x9CA3AF, 0x7C838F)
    static let placeholder = dynamic(0xC8CDD6, 0x565D68)
    static let line = dynamic(0xF0F1F3, 0x2A2E35)
    static let fill = dynamic(0xF4F5F7, 0x24282F)
    static let brand = dynamic(0x07C160, 0x07C160)
    static let brandDark = dynamic(0x059E4F, 0x06B457)
    static let brandSoft = dynamic(0xE8F8EF, 0x12291D)
    static let red = dynamic(0xFF3B30, 0xFF453A)
    static let redSoft = dynamic(0xFFECEC, 0x2C1A1A)
    static let gold = dynamic(0xFFB020, 0xFFB020)
    static let goldSoft = dynamic(0xFFF3DC, 0x2C2415)
    static let blueSoft = dynamic(0xE8F2FF, 0x16233A)
    static let link = dynamic(0x3B6BFF, 0x6E96FF)
    static let bubbleSelf = dynamic(0x07C160, 0x07C160)
    static let bubbleOther = dynamic(0xFFFFFF, 0x24282F)

    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { trait in
            UIColor(hex: trait.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension View {
    func cardStyle() -> some View {
        self.background(AKColor.card)
    }
}
