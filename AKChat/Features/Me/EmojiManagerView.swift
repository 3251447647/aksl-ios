import SwiftUI

/// 我的表情：列表 + 单张删除（对齐安卓表情收藏管理）
struct EmojiManagerView: View {
    @EnvironmentObject private var app: AppState
    @State private var confirmURL: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        ScrollView {
            if app.emojis.isEmpty {
                Text("还没有收藏表情，长按聊天里的图片即可添加")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.hint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                    .padding(.horizontal, 30)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(app.emojis) { e in
                        AsyncImage(url: APIClient.fullURL(e.url)) { phase in
                            if let img = phase.image {
                                img.resizable().scaledToFill()
                            } else {
                                AKColor.fill
                            }
                        }
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .onLongPressGesture {
                            confirmURL = e.url
                        }
                    }
                }
                .padding(12)
                Text("长按表情可删除")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.hint)
                    .padding(.bottom, 16)
            }
        }
        .background(AKColor.bg.ignoresSafeArea())
        .navigationTitle("我的表情")
        .navigationBarTitleDisplayMode(.inline)
        .task { await app.loadEmojis() }
        .confirmationDialog("删除这个表情？", isPresented: Binding(
            get: { confirmURL != nil },
            set: { if !$0 { confirmURL = nil } }
        ), titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let url = confirmURL {
                    Task {
                        await APIClient.shared.deleteEmoji(url: url)
                        await app.loadEmojis()
                    }
                }
                confirmURL = nil
            }
            Button("取消", role: .cancel) { confirmURL = nil }
        }
    }
}
