import SwiftUI

/// 聊天「+」面板：安卓式图标网格（相册/拍摄/通话/直播间/红包/礼物/转账）
struct MorePanel: View {
    var isGroup: Bool
    var onPhoto: () -> Void
    var onCamera: () -> Void
    var onRedPacket: () -> Void
    var onTransfer: () -> Void
    var onGift: () -> Void
    var onVoiceCall: () -> Void = {}
    var onVideoCall: () -> Void = {}
    var onGroupCall: (Int) -> Void = { _ in }
    var onGroupLive: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    private struct Item {
        let title: String
        let icon: String
        let color: Color
        let action: () -> Void
    }

    private var items: [Item] {
        var list: [Item] = [
            Item(title: "相册", icon: "photo.on.rectangle", color: Color(hex: 0x4C8DFF), action: onPhoto),
            Item(title: "拍摄", icon: "camera.fill", color: Color(hex: 0x34C759), action: onCamera)
        ]
        if isGroup {
            list.append(Item(title: "群通话", icon: "phone.fill", color: AKColor.brand, action: { onGroupCall(2) }))
            list.append(Item(title: "直播间", icon: "video.fill", color: Color(hex: 0xFF4D6D), action: onGroupLive))
            list.append(Item(title: "语音通话", icon: "phone.fill", color: AKColor.brand, action: { onGroupCall(1) }))
        } else {
            list.append(Item(title: "语音通话", icon: "phone.fill", color: AKColor.brand, action: onVoiceCall))
            list.append(Item(title: "视频通话", icon: "video.fill", color: AKColor.brand, action: onVideoCall))
        }
        list.append(Item(title: "红包", icon: "envelope.fill", color: Color(hex: 0xE8603C), action: onRedPacket))
        list.append(Item(title: "礼物", icon: "gift.fill", color: Color(hex: 0x8B7BF6), action: onGift))
        list.append(Item(title: "转账", icon: "arrow.left.arrow.right", color: Color(hex: 0xF0B429), action: onTransfer))
        return list
    }

    var body: some View {
        VStack(spacing: 0) {
            let rows = stride(from: 0, to: items.count, by: 4).map { Array(items[$0..<min($0 + 4, items.count)]) }
            ForEach(rows.indices, id: \.self) { i in
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { j in
                        if j < rows[i].count {
                            let item = rows[i][j]
                            grid(title: item.title, icon: item.icon, color: item.color, action: item.action)
                        } else {
                            Spacer().frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.top, i == 0 ? 16 : 12)
            }

            Spacer(minLength: 0)

            Button {
                dismiss()
            } label: {
                Text("取消")
                    .font(.system(size: 15))
                    .foregroundColor(AKColor.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(AKColor.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(AKColor.bg)
        .presentationDragIndicator(.visible)
    }

    private func grid(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
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
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
