import SwiftUI

/// 表情面板：仅「常用」与「我的表情」两个标签，292 高（对齐安卓 StickerAlbumPanel）
struct StickerAlbumView: View {
    let emojis: [EmojiItem]
    var onPickEmoji: (String) -> Void
    var onSticker: (String) -> Void
    var onAdd: () -> Void
    var onDelete: (String) -> Void

    @State private var tab = 1

    /// 与安卓 COMMON_EMOJI 同一份列表
    static let commonEmoji: [String] = [
        "😀", "😁", "😂", "🤣", "😊", "😍", "🥰", "😘", "😎", "🤔", "😅", "😉", "😴", "😭", "😢",
        "😡", "😱", "🤗", "🙄", "😏", "🤩", "🥳", "😋", "🤤", "😜", "🤪", "😇", "🥺", "😳", "😗",
        "😙", "😚", "😺", "😸", "😹", "😻", "😼", "😽", "🙀", "😿", "😾", "👏", "👍", "👎", "🙏",
        "💪", "🤝", "👋", "🤚", "🖐️", "✋", "🖖", "👐", "🤲", "🙌", "🤞", "🫰", "🤟", "🤘", "👌",
        "🤌", "✌️", "🤙", "👈", "👉", "👆", "👇", "🌹", "🌷", "🌸", "🌺", "🌻", "🌼", "💐", "🍀",
        "🌈", "⭐", "🌟", "✨", "⚡", "☀️", "🌙", "🍎", "🍊", "🍋", "🍉", "🍇", "🍓", "🍒", "🍑",
        "🥭", "🍍", "🥥", "🍕", "🍔", "🍟", "🍰", "🍦", "🍭", "🍫", "🍿", "☕", "🍺", "⚽", "🏀",
        "🏈", "⚾", "🎾", "🏐", "🎱", "🏓", "🏸", "🥊", "🎯", "🎮", "🕹️", "🎲", "🎳", "🚗", "🚕",
        "🚙", "🚌", "🚎", "🏎️", "🚓", "🚑", "🚒", "🚐", "✈️", "🚀", "🚁", "⛵", "💎", "👑", "🏆",
        "🥇", "🎖️", "🎁", "🎉", "🎊", "💰", "💯", "🔥", "❤️", "💔", "💕", "💖", "💘"
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            if tab == 0 {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 8), spacing: 0) {
                        ForEach(Self.commonEmoji.indices, id: \.self) { i in
                            Button {
                                onPickEmoji(Self.commonEmoji[i])
                            } label: {
                                Text(Self.commonEmoji[i])
                                    .font(.system(size: 22))
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 4) {
                        Button(action: onAdd) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AKColor.fill)
                                Text("＋").font(.system(size: 26)).foregroundColor(AKColor.muted)
                            }
                            .aspectRatio(1, contentMode: .fit)
                        }
                        .buttonStyle(.plain)

                        ForEach(emojis) { emoji in
                            stickerCell(emoji)
                        }

                        if emojis.isEmpty {
                            ZStack {
                                Text("点＋添加")
                                    .font(.system(size: 11))
                                    .foregroundColor(AKColor.muted)
                            }
                            .aspectRatio(1, contentMode: .fit)
                        }
                    }
                    .padding(.horizontal, 6)
                }
            }
        }
        .frame(height: 292)
        .background(AKColor.card)
    }

    private var header: some View {
        HStack(spacing: 4) {
            tabButton("常用", index: 0)
            tabButton("我的表情", index: 1)
            Spacer(minLength: 0)
            if tab == 1 {
                Button(action: onAdd) {
                    Text("＋")
                        .font(.system(size: 16))
                        .foregroundColor(AKColor.sub)
                        .frame(width: 26, height: 26)
                        .background(AKColor.fill)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func tabButton(_ title: String, index: Int) -> some View {
        Button {
            tab = index
        } label: {
            Text(title)
                .font(.system(size: 12.5, weight: tab == index ? .medium : .regular))
                .foregroundColor(tab == index ? AKColor.brand : AKColor.sub)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(tab == index ? AKColor.brandSoft : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.trailing, 4)
    }

    private func stickerCell(_ emoji: EmojiItem) -> some View {
        let url = emoji.url
        return Button {
            onSticker(url)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(AKColor.fill)
                AsyncImage(url: APIClient.fullURL(url)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.clear
                    }
                }
                .padding(3)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("发送") { onSticker(url) }
            Button(role: .destructive) { onDelete(url) } label: {
                Text("删除")
            }
        }
    }
}
