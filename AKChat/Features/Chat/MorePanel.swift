import SwiftUI

/// 聊天「+」面板：相册、通话、群通话、直播、红包、礼物与转账。
struct MorePanel: View {
    var isGroup: Bool
    var onPhoto: () -> Void
    /// 私聊通话：点开后再选视频通话 / 电话通话
    var onCall: () -> Void = {}
    var onRedPacket: () -> Void
    var onTransfer: () -> Void
    var onGift: () -> Void
    var onGroupCall: (Int) -> Void = { _ in }
    var onGroupLive: () -> Void = {}

    private enum Icon {
        case symbol(String)
        case redPacket
    }

    private struct Item: Identifiable {
        let id = UUID()
        let title: String
        let icon: Icon
        let action: () -> Void
    }

    private var items: [Item] {
        var list: [Item] = [Item(title: "相册", icon: .symbol("photo"), action: onPhoto)]
        if isGroup {
            list.append(Item(title: "群通话", icon: .symbol("phone"), action: { onGroupCall(2) }))
            list.append(Item(title: "直播间", icon: .symbol("dot.radiowaves.left.and.right"), action: onGroupLive))
        } else {
            list.append(Item(title: "通话", icon: .symbol("phone.arrow.up.right"), action: onCall))
        }
        list.append(Item(title: "红包", icon: .redPacket, action: onRedPacket))
        list.append(Item(title: "礼物", icon: .symbol("gift.fill"), action: onGift))
        list.append(Item(title: "转账", icon: .symbol("arrow.left.arrow.right"), action: onTransfer))
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
                iconView(item.icon)
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

    @ViewBuilder
    private func iconView(_ icon: Icon) -> some View {
        switch icon {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 22))
                .foregroundColor(AKColor.sub)
        case .redPacket:
            RedPacketMark()
        }
    }
}

/// 红包图标的红色信封 + 金色封口，与礼物盒图标区分开
private struct RedPacketMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xF0524A), Color(hex: 0xC92B25)],
                                     startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                .fill(Color.white.opacity(0.16))
                .frame(height: 7)
                .frame(maxHeight: .infinity, alignment: .top)
            Circle()
                .fill(Color(hex: 0xF6CE7A))
                .frame(width: 7, height: 7)
        }
        .frame(width: 21, height: 25)
        .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
    }
}
