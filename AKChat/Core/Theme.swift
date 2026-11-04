import SwiftUI

/// 与安卓 Design.kt 的浅色调色板保持一致
enum AKColor {
    static let bg = Color(hex: 0xF6F7F9)
    static let card = Color.white
    static let cardAlt = Color(hex: 0xFBFBFC)
    static let text = Color(hex: 0x111827)
    static let sub = Color(hex: 0x6B7280)
    static let muted = Color(hex: 0x9AA0AC)
    static let hint = Color(hex: 0x9CA3AF)
    static let placeholder = Color(hex: 0xC8CDD6)
    static let line = Color(hex: 0xF0F1F3)
    static let fill = Color(hex: 0xF4F5F7)
    static let brand = Color(hex: 0x07C160)
    static let brandDark = Color(hex: 0x059E4F)
    static let brandSoft = Color(hex: 0xE8F8EF)
    static let red = Color(hex: 0xFF3B30)
    static let redSoft = Color(hex: 0xFFECEC)
    static let gold = Color(hex: 0xFFB020)
    static let goldSoft = Color(hex: 0xFFF3DC)
    static let blueSoft = Color(hex: 0xE8F2FF)
    static let link = Color(hex: 0x3B6BFF)
    static let bubbleSelf = Color(hex: 0x07C160)
    static let bubbleOther = Color.white
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
