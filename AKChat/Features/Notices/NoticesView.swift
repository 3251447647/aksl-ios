import SwiftUI

/// 系统公告列表：标题 15 / 摘要 12.5 两行 / 日期 yyyy-MM-dd（对齐安卓 NoticeScreen）
struct NoticesView: View {
    @State private var list: [Notice] = []
    @State private var loading = true
    @State private var detailBox: NoticeDetailBox?
    @State private var readIds: Set<Int64> = []

    var body: some View {
        List {
            if loading && list.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowSeparator(.hidden)
            } else if list.isEmpty {
                Text("暂无公告")
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.placeholder)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(list) { notice in
                    Button {
                        Task { await openNotice(notice) }
                    } label: {
                        row(notice)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(AKColor.card)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 16 }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AKColor.bg)
        .reportsDetailPage()
        .navigationTitle("系统公告")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .navigationDestination(isPresented: Binding(
            get: { detailBox != nil },
            set: { if !$0 { detailBox = nil } }
        )) {
            if let box = detailBox {
                NoticeDetailView(detail: box.value,
                                 isRead: box.isRead,
                                 onConfirm: {
                                     markReadLocally(box.value.id)
                                 })
                    .restoresSwipeBack()
            }
        }
    }

    private func row(_ notice: Notice) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                if notice.isTop == 1 {
                    Text("置顶")
                        .font(.system(size: 9))
                        .foregroundColor(AKColor.red)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(AKColor.redSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                Text(notice.title ?? "公告")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(notice.read == 1 ? AKColor.muted : AKColor.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if notice.read != 1 {
                    Circle().fill(AKColor.red).frame(width: 6, height: 6)
                }
            }
            Text(notice.summary ?? notice.content ?? "")
                .font(.system(size: 12.5))
                .foregroundColor(AKColor.muted)
                .lineLimit(2)
                .padding(.top, 5)
            Text(Self.dayText(notice.createdAt))
                .font(.system(size: 11))
                .foregroundColor(AKColor.placeholder)
                .padding(.top, 6)
        }
        .padding(16)
        .contentShape(Rectangle())
    }

    private static func dayText(_ ts: Int64) -> String {
        guard ts > 0 else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)!
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }

    private func load() async {
        if let data: NoticeUnreadResp = try? await APIClient.shared.get("api/v1/notices") {
            list = data.list
        }
        loading = false
    }

    private func openNotice(_ notice: Notice) async {
        if let d = try? await APIClient.shared.notice(id: notice.id) {
            detailBox = NoticeDetailBox(value: d,
                                        isRead: notice.read == 1 || readIds.contains(notice.id))
        }
    }

    /// 详情里确认后同步列表行，否则返回列表还是未读小红点
    private func markReadLocally(_ id: Int64) {
        readIds.insert(id)
        guard let idx = list.firstIndex(where: { $0.id == id }) else { return }
        let n = list[idx]
        list[idx] = Notice(id: n.id, title: n.title, summary: n.summary, content: n.content,
                           images: n.images, read: 1, isTop: n.isTop, createdAt: n.createdAt)
    }
}

/// 公告详情：渐变头卡（圆角 22）+ 正文卡（18，含图片）+ 我已知晓
struct NoticeDetailView: View {
    let detail: NoticeDetail
    let isRead: Bool
    let onConfirm: () -> Void

    @State private var confirmed = false
    @State private var sending = false

    private var done: Bool { isRead || confirmed }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroCard
                contentCard.padding(.top, 12)
                confirmButton.padding(.top, 18)
                Spacer(minLength: 24)
            }
            .padding(14)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .reportsDetailPage()
        .navigationTitle("公告详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("告")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text("官方公告")
                    .font(.system(size: 11.5))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Spacer(minLength: 0)
                Text(Self.heroTime(detail.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.8))
            }
            Text((detail.title ?? "").isEmpty ? "系统公告" : (detail.title ?? "系统公告"))
                .font(.system(size: 21, weight: .bold))
                .foregroundColor(.white)
                .lineSpacing(6)
                .padding(.top, 14)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(hex: 0x2F6BFF), Color(hex: 0x5B8CFF), Color(hex: 0x9F7BFF)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            AKLinkText(
                text: (detail.content ?? "").isEmpty ? "暂无公告内容" : (detail.content ?? ""),
                color: AKColor.text,
                fontSize: 15,
                lineHeight: 24
            )
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)

            if !detail.images.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3),
                          spacing: 6) {
                    ForEach(Array(detail.images.prefix(9).enumerated()), id: \.element) { _, path in
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                AKImage(url: path, size: 120, placeholder: AKColor.fill)
                            )
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.top, 16)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var confirmButton: some View {
        Button {
            guard !done, !sending else { return }
            sending = true
            Task {
                await APIClient.shared.readNotice(id: detail.id)
                sending = false
                confirmed = true
                onConfirm()
            }
        } label: {
            Text(done ? "已确认" : (sending ? "提交中…" : "我已知晓"))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(done ? AKColor.muted : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(done ? AKColor.line : AKColor.brand)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(done || sending)
    }

    private static func heroTime(_ ts: Int64) -> String {
        guard ts > 0 else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)!
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }
}

/// sheet(item:) 需要 Identifiable 包装
struct NoticeDetailBox: Identifiable {
    let id = UUID()
    let value: NoticeDetail
    let isRead: Bool
}

/// 公告列表（只要 list）：老服务端不回 unread 时也不至于整页解码失败
struct NoticeUnreadResp: Decodable {
    let list: [Notice]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decode([Notice].self, forKey: .list)) ?? []
    }

    enum CodingKeys: String, CodingKey { case list }
}

/// 平台公告弹窗：对齐安卓 ConvListScreen 的 SystemNoticeDialog
/// 渐变头图（系统公告标 + 标题 + 时间）→ 可滚动正文与九宫格图片 → 稍后 / 查看详情 / 我已知晓
struct SystemNoticePopup: View {
    let notice: Notice
    let onLater: () -> Void
    let onDetail: () -> Void
    let onConfirm: () -> Void

    @State private var preview: PreviewImage? = nil

    private var text: String {
        let content = (notice.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !content.isEmpty { return content }
        return (notice.summary ?? "").ifBlank("暂无公告内容")
    }

    private var images: [String] { Array(notice.images.prefix(9)) }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AKLinkText(text: text, color: AKColor.text, fontSize: 14.5, lineHeight: 23)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !images.isEmpty {
                        imageGrid.padding(.top, 14)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(maxHeight: 340)

            HStack(spacing: 10) {
                Button(action: onLater) {
                    Text("稍后")
                        .font(.system(size: 14))
                        .foregroundColor(AKColor.muted)
                        .padding(.horizontal, 4)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                Button(action: onDetail) {
                    Text("查看详情")
                        .font(.system(size: 13.5))
                        .foregroundColor(AKColor.link)
                        .padding(.horizontal, 4)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button(action: onConfirm) {
                    Text("我已知晓")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .frame(minWidth: 120)
                        .frame(height: 44)
                        .background(
                            LinearGradient(colors: [Color(hex: 0x2F6BFF), Color(hex: 0x6C5CF0)],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: 360)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 22)
        .fullScreenCover(item: $preview) { item in
            MediaPagerView(items: item.items, index: item.index)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.2))
                    Image(systemName: "megaphone.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
                .frame(width: 30, height: 30)
                Text("系统公告")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Spacer(minLength: 0)
            }
            Text((notice.title ?? "").isEmpty ? "系统公告" : (notice.title ?? "系统公告"))
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.white)
                .lineSpacing(6)
                .padding(.top, 12)
            Text(Self.yearTime(notice.createdAt))
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, 6)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(hex: 0x2F6BFF), Color(hex: 0x5B8CFF), Color(hex: 0x9F7BFF)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }

    private var imageGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
            ForEach(Array(images.enumerated()), id: \.element) { index, path in
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        AKImage(url: path, size: 120, placeholder: AKColor.fill)
                    )
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { openPreview(at: index) }
            }
        }
    }

    private func openPreview(at index: Int) {
        let urls = images.compactMap { APIClient.fullURL($0) }
        guard !urls.isEmpty else { return }
        preview = PreviewImage(
            items: urls.map { PreviewMedia(url: $0, isVideo: false, message: nil) },
            index: min(index, urls.count - 1)
        )
    }

    private static func yearTime(_ ts: Int64) -> String {
        guard ts > 0 else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)!
        f.dateFormat = "yyyy年MM月dd日 HH:mm"
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }
}

private extension String {
    func ifBlank(_ fallback: String) -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : self
    }
}
