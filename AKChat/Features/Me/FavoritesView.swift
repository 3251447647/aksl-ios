import SwiftUI
import UIKit

/// 我的收藏：搜索 + 整屏白底列表 + 详情页（对齐安卓 FavoritesScreen）
struct FavoritesView: View {
    @State private var items: [FavoriteItem] = []
    @State private var page = 1
    @State private var hasMore = false
    @State private var loading = true
    @State private var loadingMore = false
    @State private var error: String?
    @State private var query = ""
    @State private var detailItem: FavoriteItem?
    @State private var deleteTarget: FavoriteItem?

    private var shown: [FavoriteItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return items }
        return items.filter {
            $0.content.localizedCaseInsensitiveContains(q)
                || $0.fromName.localizedCaseInsensitiveContains(q)
                || $0.convName.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        List {
            if !items.isEmpty {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(AKColor.hint)
                    TextField("搜索收藏内容 / 来源", text: $query)
                        .font(.system(size: 13.5))
                        .foregroundColor(AKColor.text)
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundColor(AKColor.hint)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if loading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else if items.isEmpty {
                emptyState
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else if shown.isEmpty {
                Text("没有匹配的收藏")
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(shown.indices, id: \.self) { index in
                    row(shown[index], last: index == shown.count - 1)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(AKColor.card)
                }
                if hasMore {
                    Button {
                        Task { await loadMore() }
                    } label: {
                        Text(loadingMore ? "加载中…" : "加载更多")
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.link)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowBackground(AKColor.card)
                }
            }

            if let error {
                Text(error)
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.red)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AKColor.bg.ignoresSafeArea())
        .reportsDetailPage()
        .navigationTitle("我的收藏")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Text("我的收藏")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AKColor.text)
                    if !items.isEmpty {
                        Text("\(items.count) 条")
                            .font(.system(size: 12))
                            .foregroundColor(AKColor.muted)
                    }
                }
            }
        }
        .task { await load() }
        .sheet(item: $detailItem) { item in
            FavoriteDetailView(item: item,
                               onCopy: {
                                   UIPasteboard.general.string = Self.favoriteText(item)
                               },
                               onDelete: {
                                   detailItem = nil
                                   deleteTarget = item
                               })
        }
        .alert("删除这条收藏？", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("删除", role: .destructive) {
                guard let target = deleteTarget else { return }
                deleteTarget = nil
                Task { await remove(target) }
            }
            Button("取消", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("删除后无法恢复。")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Image(systemName: "star")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(AKColor.placeholder)
            Text("还没有收藏")
                .font(.system(size: 15))
                .foregroundColor(AKColor.muted)
                .padding(.top, 12)
            Text("在聊天里长按消息收藏，会出现在这里")
                .font(.system(size: 12))
                .foregroundColor(AKColor.placeholder)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 140)
    }

    private func row(_ item: FavoriteItem, last: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon(for: item.type))
                    .font(.system(size: 16))
                    .foregroundColor(AKColor.brand)
                    .frame(width: 42, height: 42)
                    .background(AKColor.brandSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(item.fromName.isEmpty ? "未知" : item.fromName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AKColor.text)
                            .lineLimit(1)
                        Text(Self.typeLabel(item.type))
                            .font(.system(size: 10))
                            .foregroundColor(AKColor.brandDark)
                        if !item.convName.isEmpty {
                            Text("· \(item.convName)")
                                .font(.system(size: 10))
                                .foregroundColor(AKColor.muted)
                                .lineLimit(1)
                        }
                    }
                    Text(summary(item))
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.sub)
                        .lineLimit(3)
                    Text(Self.timeText(item.createdAt))
                        .font(.system(size: 10.5))
                        .foregroundColor(AKColor.placeholder)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    deleteTarget = item
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 15))
                        .foregroundColor(AKColor.placeholder)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture { detailItem = item }

            if !last {
                Rectangle()
                    .fill(AKColor.fill)
                    .frame(height: 0.6)
                    .padding(.leading, 62)
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
        default: return Self.favoriteText(item)
        }
    }

    static func favoriteText(_ item: FavoriteItem) -> String {
        let raw = item.content
        if let r = raw.range(of: "|#|", options: .backwards) {
            return String(raw[r.upperBound...])
        }
        return raw
    }

    static func typeLabel(_ type: Int) -> String {
        switch type {
        case 5: return "图片"
        case 6: return "语音"
        case 15: return "视频"
        case 10: return "引用消息"
        default: return "文字"
        }
    }

    static func timeText(_ ts: Int64) -> String {
        guard ts > 0 else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)!
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
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

/// 收藏详情整页：内容 + 复制 / 删除
private struct FavoriteDetailView: View {
    let item: FavoriteItem
    let onCopy: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var preview = false

    private var text: String { FavoritesView.favoriteText(item) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundColor(AKColor.brand)
                            .frame(width: 36, height: 36)
                            .background(AKColor.brandSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.fromName.isEmpty ? "未知" : item.fromName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AKColor.text)
                            Text(sourceLine)
                                .font(.system(size: 11))
                                .foregroundColor(AKColor.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    Rectangle().fill(AKColor.line).frame(height: 0.5).padding(.vertical, 12)

                    if item.type == 5 {
                        AsyncImage(url: APIClient.fullURL(item.content)) { phase in
                            if let img = phase.image {
                                img.resizable().scaledToFit()
                            } else {
                                AKColor.fill
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .onTapGesture { preview = true }
                    } else if item.type == 6 {
                        Text("语音消息").font(.system(size: 14)).foregroundColor(AKColor.sub)
                    } else if item.type == 15 {
                        Text("视频消息").font(.system(size: 14)).foregroundColor(AKColor.sub)
                    } else {
                        Text(text)
                            .font(.system(size: 15))
                            .foregroundColor(AKColor.text)
                            .lineSpacing(7)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text(FavoritesView.timeText(item.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(AKColor.placeholder)
                        .padding(.top, 14)
                }
                .padding(14)
            }
            .background(AKColor.bg)
            .navigationTitle("收藏详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash").foregroundColor(AKColor.red)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    action("复制", enabled: item.type != 5 && item.type != 6 && item.type != 15) {
                        onCopy()
                    }
                    action("删除", danger: true) {
                        onDelete()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AKColor.card)
            }
            .fullScreenCover(isPresented: $preview) {
                ZStack {
                    Color.black.ignoresSafeArea()
                    AsyncImage(url: APIClient.fullURL(item.content)) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFit()
                        } else {
                            ProgressView().tint(.white)
                        }
                    }
                    VStack {
                        HStack {
                            Spacer()
                            Button("关闭") { preview = false }
                                .foregroundColor(.white)
                        }
                        .padding()
                        Spacer()
                    }
                }
            }
        }
    }

    private var icon: String {
        switch item.type {
        case 5: return "photo"
        case 6: return "waveform"
        case 15: return "video"
        default: return "text.alignleft"
        }
    }

    private var sourceLine: String {
        var parts: [String] = []
        if !item.convName.isEmpty { parts.append("来源 \(item.convName)") }
        parts.append(FavoritesView.typeLabel(item.type))
        return parts.joined(separator: " · ")
    }

    private func action(_ title: String, enabled: Bool = true, danger: Bool = false,
                        onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(!enabled ? AKColor.placeholder : (danger ? AKColor.red : AKColor.text))
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(danger ? AKColor.redSoft : AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
