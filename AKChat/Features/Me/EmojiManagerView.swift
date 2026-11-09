import SwiftUI
import PhotosUI

/// 我的表情：6 列表情网格 + 首格「＋」从相册添加 + 长按删除（对齐安卓表情网格）
struct EmojiManagerView: View {
    @EnvironmentObject private var app: AppState
    @State private var confirmURL: String?
    @State private var pickerItem: PhotosPickerItem?

    private let columns = 6

    /// 首格固定为「＋ 添加」，其余是已收藏表情
    private var cells: [EmojiItem?] {
        [nil] + app.emojis.map { Optional($0) }
    }

    private var rows: [[EmojiItem?]] {
        stride(from: 0, to: cells.count, by: columns).map { start in
            Array(cells[start..<min(start + columns, cells.count)])
        }
    }

    var body: some View {
        List {
            ForEach(rows.indices, id: \.self) { index in
                HStack(spacing: 4) {
                    ForEach(rows[index].indices, id: \.self) { i in
                        cell(rows[index][i])
                    }
                    ForEach(0..<(columns - rows[index].count), id: \.self) { _ in
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
                .padding(.horizontal, 6)
                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 0, trailing: 4))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            Text(app.emojis.isEmpty ? "点＋从相册添加表情" : "长按表情可删除")
                .font(.system(size: 11.5))
                .foregroundColor(AKColor.hint)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 20)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AKColor.bg.ignoresSafeArea())
        .navigationTitle("我的表情")
        .navigationBarTitleDisplayMode(.inline)
        .task { await app.loadEmojis() }
        .onChange(of: pickerItem) { item in
            guard let item else { return }
            Task { await add(item) }
        }
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

    @ViewBuilder
    private func cell(_ emoji: EmojiItem?) -> some View {
        if let emoji {
            AsyncImage(url: APIClient.fullURL(emoji.url)) { phase in
                if let img = phase.image {
                    img.resizable().scaledToFill()
                } else {
                    AKColor.fill
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .background(AKColor.fill)
            .padding(3)
            .contentShape(Rectangle())
            .onLongPressGesture {
                confirmURL = emoji.url
            }
        } else {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text("＋")
                    .font(.system(size: 26))
                    .foregroundColor(AKColor.muted)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background(AKColor.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(3)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func add(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        guard let up = try? await app.uploadImage(data) else { return }
        await app.addEmoji(url: up.url)
    }
}
