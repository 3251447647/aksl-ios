import SwiftUI
import UIKit

struct FavoritesView: View {
    @State private var items: [FavoriteItem] = []
    @State private var page = 1
    @State private var hasMore = false
    @State private var loading = true
    @State private var loadingMore = false
    @State private var error: String?

    var body: some View {
        List {
            if loading {
                ProgressView()
            } else if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "star")
                        .font(.system(size: 32))
                        .foregroundColor(AKColor.hint)
                    Text("还没有收藏内容，长按消息可收藏")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .listRowSeparator(.hidden)
            } else {
                ForEach(items) { item in
                    row(item)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await remove(item) }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
                if hasMore {
                    Button {
                        Task { await loadMore() }
                    } label: {
                        Text(loadingMore ? "加载中…" : "加载更多")
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.link)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            if let error {
                Text(error).font(.system(size: 12)).foregroundColor(AKColor.red)
            }
        }
        .listStyle(.plain)
        .navigationTitle("我的收藏")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func row(_ item: FavoriteItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon(for: item.type))
                .font(.system(size: 15))
                .foregroundColor(AKColor.brand)
                .frame(width: 30, height: 30)
                .background(AKColor.brandSoft)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(summary(item))
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.text)
                    .lineLimit(3)
                HStack(spacing: 6) {
                    if !item.fromName.isEmpty {
                        Text(item.fromName).font(.system(size: 11)).foregroundColor(AKColor.muted)
                    }
                    if !item.convName.isEmpty {
                        Text(item.convName).font(.system(size: 11)).foregroundColor(AKColor.hint)
                    }
                    Text(TimeText.short(item.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(AKColor.hint)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if item.type == 1 {
                UIPasteboard.general.string = item.content
            }
        }
    }

    private func icon(for type: Int) -> String {
        switch type {
        case 5: return "photo"
        case 6: return "waveform"
        case 7, 21: return "yensign.circle"
        case 8, 22: return "arrow.left.arrow.right"
        case 9, 23: return "gift"
        case 12, 13: return "person.crop.rectangle"
        case 15: return "video"
        case 18: return "doc"
        default: return "text.alignleft"
        }
    }

    private func summary(_ item: FavoriteItem) -> String {
        switch item.type {
        case 5: return "[图片]"
        case 6: return "[语音]"
        case 7, 21: return "[红包]"
        case 8, 22: return "[转账]"
        case 9, 23: return "[礼物]"
        case 12: return "[个人名片]"
        case 13: return "[群名片]"
        case 15: return "[视频]"
        case 18: return "[文件]"
        case 14: return "[通话]"
        case 17: return "[聊天记录]"
        default: return item.content
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let data = try await APIClient.shared.favorites(page: 1)
            items = data.list
            hasMore = data.hasMore == 1
            page = 1
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard !loadingMore, hasMore else { return }
        loadingMore = true
        defer { loadingMore = false }
        do {
            let next = page + 1
            let data = try await APIClient.shared.favorites(page: next)
            items.append(contentsOf: data.list)
            hasMore = data.hasMore == 1
            page = next
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func remove(_ item: FavoriteItem) async {
        items.removeAll { $0.id == item.id }
        await APIClient.shared.deleteFavorite(id: item.id)
    }
}
