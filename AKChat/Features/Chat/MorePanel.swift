import SwiftUI

/// 聊天「+」面板：安卓式 4 列图标网格（相册/拍摄/通话/直播间/红包/礼物/转账/背景）
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
    var onChatBg: () -> Void = {}

    private struct Item: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let action: () -> Void
    }

    private var items: [Item] {
        var list: [Item] = [
            Item(title: "相册", icon: "photo", action: onPhoto),
            Item(title: "拍摄", icon: "camera", action: onCamera)
        ]
        if isGroup {
            list.append(Item(title: "群通话", icon: "phone", action: { onGroupCall(2) }))
            list.append(Item(title: "直播间", icon: "dot.radiowaves.left.and.right", action: onGroupLive))
            list.append(Item(title: "语音通话", icon: "phone", action: { onGroupCall(1) }))
        } else {
            list.append(Item(title: "语音通话", icon: "phone", action: onVoiceCall))
            list.append(Item(title: "视频通话", icon: "video", action: onVideoCall))
        }
        list.append(Item(title: "红包", icon: "gift", action: onRedPacket))
        list.append(Item(title: "礼物", icon: "gift.fill", action: onGift))
        list.append(Item(title: "转账", icon: "arrow.left.arrow.right", action: onTransfer))
        list.append(Item(title: "背景", icon: "photo.on.rectangle", action: onChatBg))
        return list
    }

    var body: some View {
        VStack(spacing: 0) {
            let rows = stride(from: 0, to: items.count, by: 4).map { Array(items[$0..<min($0 + 4, items.count)]) }
            ForEach(rows.indices, id: \.self) { i in
                HStack(spacing: 0) {
                    ForEach(rows[i]) { item in
                        cell(item)
                    }
                    if rows[i].count < 4 {
                        ForEach(0..<(4 - rows[i].count), id: \.self) { _ in
                            Spacer().frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 18)
        .background(AKColor.fill)
    }

    private func cell(_ item: Item) -> some View {
        Button {
            item.action()
        } label: {
            VStack(spacing: 7) {
                Image(systemName: item.icon)
                    .font(.system(size: 22))
                    .foregroundColor(AKColor.sub)
                    .frame(width: 56, height: 56)
                    .background(AKColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(item.title)
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.sub)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
