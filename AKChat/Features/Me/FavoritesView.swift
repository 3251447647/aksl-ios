import SwiftUI
import UIKit

/// 我的收藏：搜索 + 整屏列表 + 收藏详情（对齐安卓 FavoritesScreen）
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
    /// FavoriteItem 是 Core 的只读模型：编辑后的正文按 id 覆盖，避免整页重拉
    @State private var editedContent: [Int64: String] = [:]

    private var shown: [FavoriteItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return items }
        return items.filter {
            content($0).localizedCaseInsensitiveContains(q)
                || $0.fromName.localizedCaseInsensitiveContains(q)
                || $0.convName.localizedCaseInsensitiveContains(q)
        }
    }

    private func content(_ item: FavoriteItem) -> String {
        editedContent[item.id] ?? item.content
    }

    var body: some View {
        List {
            if !items.isEmpty {
                searchBar
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
                    .listRowInsets(EdgeInsets())
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
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                    row(item, last: index == shown.count - 1)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(AKColor.card)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteTarget = item
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
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
        .navigationDestination(isPresented: Binding(
            get: { detailItem != nil },
            set: { if !$0 { detailItem = nil } }
        )) {
            if let item = detailItem {
                FavoriteDetailView(
                    item: item,
                    content: content(item),
                    onSave: { text in await saveEdit(item, text) },
                    onDelete: { await remove(item) }
                )
            }
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

    private var searchBar: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
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
                HStack(alignment: .top, spacing: 10) {
                    AvatarView(url: nil, name: item.fromName.isEmpty ? "未知" : item.fromName, size: 42)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 6) {
                            Text(item.fromName.isEmpty ? "未知" : item.fromName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AKColor.text)
                                .lineLimit(1)
                            if !item.convName.isEmpty {
                                Text("· \(item.convName)")
                                    .font(.system(size: 10))
                                    .foregroundColor(AKColor.muted)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.bottom, 5)

                        summary(item)

                        Text(Self.timeText(item.createdAt))
                            .font(.system(size: 10.5))
                            .foregroundColor(AKColor.placeholder)
                            .padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { detailItem = item }

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

            if !last {
                Rectangle()
                    .fill(AKColor.fill)
                    .frame(height: 0.6)
                    .padding(.leading, 62)
            }
        }
    }

    @ViewBuilder
    private func summary(_ item: FavoriteItem) -> some View {
        switch item.type {
        case 5:
            AKImage(url: Self.mediaURL(content(item))?.absoluteString, size: 110, placeholder: AKColor.fill)
                .frame(width: 110, height: 110)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        case 6:
            Text("语音消息")
                .font(.system(size: 13))
                .foregroundColor(AKColor.sub)
        case 10:
            Text(Self.favoriteText(content(item)))
                .font(.system(size: 13))
                .foregroundColor(AKColor.sub)
                .lineLimit(3)
        default:
            Text(content(item))
                .font(.system(size: 13))
                .foregroundColor(AKColor.sub)
                .lineLimit(3)
        }
    }

    static func favoriteText(_ raw: String) -> String {
        if let r = raw.range(of: "|#|", options: .backwards) {
            return String(raw[r.upperBound...])
        }
        return raw
    }

    static func mediaURL(_ raw: String) -> URL? {
        let path = raw.components(separatedBy: "|#|").first ?? raw
        return APIClient.fullURL(path.trimmingCharacters(in: .whitespacesAndNewlines))
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
            editedContent = [:]
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

    private func saveEdit(_ item: FavoriteItem, _ text: String) async -> String? {
        let value = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(5000))
        guard !value.isEmpty else { return "内容不能为空" }
        do {
            _ = try await APIClient.shared.postRaw(
                "api/v1/favorites/update",
                body: ["id": item.id, "content": value]
            )
            editedContent[item.id] = value
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func remove(_ item: FavoriteItem) async {
        items.removeAll { $0.id == item.id }
        editedContent.removeValue(forKey: item.id)
        await APIClient.shared.deleteFavorite(id: item.id)
    }
}

/// 收藏详情整页：内容 + 编辑 / 转发 / 复制 / 删除（对齐安卓 FavoriteDetail）
private struct FavoriteDetailView: View {
    let item: FavoriteItem
    let onSave: (String) async -> String?
    let onDelete: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var editing = false
    @State private var draft: String
    @State private var preview = false
    @State private var confirmDelete = false
    @State private var showForward = false
    @State private var saving = false
    @State private var toastText: String?

    init(item: FavoriteItem,
         content: String,
         onSave: @escaping (String) async -> String?,
         onDelete: @escaping () async -> Void) {
        self.item = item
        self.onSave = onSave
        self.onDelete = onDelete
        _text = State(initialValue: content)
        _draft = State(initialValue: content)
    }

    private var name: String { item.fromName.isEmpty ? "未知" : item.fromName }
    private var isMedia: Bool { item.type == 5 || item.type == 6 || item.type == 15 }
    private var editable: Bool { !isMedia }
    /// 引用消息的正文取 |#| 之后；媒体保持原始地址
    private var displayText: String {
        isMedia ? text : FavoritesView.favoriteText(text)
    }

    private var sourceLine: String {
        var parts: [String] = []
        if !item.convName.isEmpty { parts.append(item.convName) }
        parts.append(FavoritesView.typeLabel(item.type))
        return parts.joined(separator: " · ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    AvatarView(url: nil, name: name, size: 36)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AKColor.text)
                        Text(sourceLine)
                            .font(.system(size: 11))
                            .foregroundColor(AKColor.muted)
                    }
                    Spacer(minLength: 0)
                }

                Rectangle()
                    .fill(AKColor.line)
                    .frame(height: 0.5)
                    .padding(.vertical, 12)

                if item.type == 5 {
                    AKImage(url: FavoritesView.mediaURL(text)?.absoluteString,
                            size: CGSize(width: UIScreen.main.bounds.width, height: 260),
                            contentMode: .fit, placeholder: AKColor.fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .contentShape(Rectangle())
                        .onTapGesture { preview = true }
                } else if item.type == 6 {
                    Text("语音消息")
                        .font(.system(size: 14))
                        .foregroundColor(AKColor.sub)
                } else if item.type == 15 {
                    Text("视频消息")
                        .font(.system(size: 14))
                        .foregroundColor(AKColor.sub)
                } else {
                    Text(displayText)
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
        .reportsDetailPage()
        .navigationTitle("收藏详情")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    confirmDelete = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(AKColor.red)
                }
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .overlay(alignment: .bottom) { toastView }
        .fullScreenCover(isPresented: $preview) { previewView }
        .sheet(isPresented: $showForward) {
            ForwardPickerView(
                messages: [Self.forwardMessage(item, content: text)],
                screenTitle: "转发收藏",
                subtitleOverride: "选择会话，把这条收藏发过去"
            )
        }
        .alert("编辑收藏", isPresented: $editing) {
            TextField("收藏内容", text: $draft)
            Button("保存") { Task { await saveEdit() } }
            Button("取消", role: .cancel) { draft = displayText }
        } message: {
            Text("文字类收藏可编辑，最多 5000 字")
        }
        .alert("删除这条收藏？", isPresented: $confirmDelete) {
            Button("删除", role: .destructive) {
                Task {
                    await onDelete()
                    dismiss()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复。")
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            action("编辑", enabled: editable) {
                draft = displayText
                editing = true
            }
            action("转发") {
                showForward = true
            }
            action("复制", enabled: !isMedia) {
                UIPasteboard.general.string = displayText
                showToast("已复制")
            }
            action("删除", danger: true) {
                confirmDelete = true
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AKColor.card)
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

    private var previewView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AsyncImage(url: FavoritesView.mediaURL(text)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
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

    private var toastView: some View {
        Group {
            if let toastText {
                Text(toastText)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color(hex: 0x1A1D26).opacity(0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 40)
                    .padding(.bottom, 76)
            }
        }
    }

    private func saveEdit() async {
        guard !saving else { return }
        let value = String(draft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(5000))
        guard !value.isEmpty else {
            showToast("内容不能为空")
            return
        }
        saving = true
        defer { saving = false }
        if let error = await onSave(value) {
            showToast(error)
        } else {
            text = value
            editing = false
            showToast("已保存")
        }
    }

    private func showToast(_ message: String) {
        toastText = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if toastText == message { toastText = nil }
        }
    }

    private static func forwardMessage(_ item: FavoriteItem, content: String) -> Message {
        Message(local: "private", convId: 0, fromUid: 0,
                type: item.type, content: content, localId: -1)
    }
}
