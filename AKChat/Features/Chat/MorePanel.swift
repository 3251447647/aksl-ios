import SwiftUI

/// 聊天「+」面板：安卓式四宫格（相册/红包/转账/礼物）
struct MorePanel: View {
    var onPhoto: () -> Void
    var onRedPacket: () -> Void
    var onTransfer: () -> Void
    var onGift: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let items: [(title: String, icon: String, color: Color)] = [
        ("相册", "photo.on.rectangle", Color(hex: 0x4C8DFF)),
        ("红包", "envelope.fill", Color(hex: 0xE8603C)),
        ("转账", "arrow.left.arrow.right.circle.fill", Color(hex: 0xF0B429)),
        ("礼物", "gift.fill", Color(hex: 0x8B7BF6))
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                grid(title: items[0].title, icon: items[0].icon, color: items[0].color, action: onPhoto)
                grid(title: items[1].title, icon: items[1].icon, color: items[1].color, action: onRedPacket)
                grid(title: items[2].title, icon: items[2].icon, color: items[2].color, action: onTransfer)
                grid(title: items[3].title, icon: items[3].icon, color: items[3].color, action: onGift)
            }
            .padding(.top, 22)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("取消")
                    .font(.system(size: 15))
                    .foregroundColor(AKColor.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(AKColor.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        .background(AKColor.bg)
        .presentationDragIndicator(.visible)
    }

    private func grid(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 21))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(title)
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.sub)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
