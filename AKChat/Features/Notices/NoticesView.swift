import SwiftUI

struct NoticesView: View {
    @EnvironmentObject private var app: AppState
    @State private var list: [Notice] = []
    @State private var detail: NoticeDetail?
    @State private var detailBox: NoticeDetailBox?

    var body: some View {
        List {
            ForEach(list) { notice in
                Button {
                    Task { await openNotice(notice) }
                } label: {
                    row(notice)
                }
                .buttonStyle(.plain)
            }
            if list.isEmpty {
                Text("暂无公告").font(.system(size: 13)).foregroundColor(AKColor.muted)
            }
        }
        .navigationTitle("公告")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .sheet(item: $detailBox) { box in
            NoticeDetailView(detail: box.value) { detailBox = nil }
        }
    }

    private func row(_ notice: Notice) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                if notice.isTop == 1 {
                    BadgeView(text: "置顶", color: AKColor.red, background: AKColor.redSoft)
                }
                Text(notice.title ?? "公告")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AKColor.text)
                    .lineLimit(1)
                Spacer()
                if notice.read == 0 {
                    Circle().fill(AKColor.red).frame(width: 8, height: 8)
                }
            }
            Text(notice.summary ?? notice.content ?? "")
                .font(.system(size: 12))
                .foregroundColor(AKColor.muted)
                .lineLimit(2)
            Text(TimeText.short(notice.createdAt))
                .font(.system(size: 10))
                .foregroundColor(AKColor.hint)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func load() async {
        if let data = try? await APIClient.shared.notices() {
            list = data.list
        }
    }

    private func openNotice(_ notice: Notice) async {
        if let d = try? await APIClient.shared.notice(id: notice.id) {
            detail = d
            detailBox = NoticeDetailBox(value: d)
        }
    }
}

/// 公告详情：标题/时间/正文卡片 + 三列图片
struct NoticeDetailView: View {
    let detail: NoticeDetail
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    headerCard
                    if !detail.images.isEmpty {
                        imagesGrid
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
            }
            .background(AKColor.bg.ignoresSafeArea())
            .navigationTitle("公告详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { onClose() }
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(detail.title ?? "公告")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(AKColor.text)
            HStack(spacing: 8) {
                if detail.isTop == 1 {
                    BadgeView(text: "置顶", color: AKColor.red, background: AKColor.redSoft)
                }
                Text(TimeText.full(detail.createdAt))
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.muted)
            }
            Rectangle().fill(AKColor.line).frame(height: 0.5)
            Text(detail.content ?? "")
                .font(.system(size: 14.5))
                .foregroundColor(AKColor.text)
                .lineSpacing(4)
                .textSelection(.enabled)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var imagesGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 6),
                            GridItem(.flexible(), spacing: 6),
                            GridItem(.flexible(), spacing: 6)], spacing: 6) {
            ForEach(detail.images, id: \.self) { path in
                AsyncImage(url: APIClient.fullURL(path)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        AKColor.fill
                    }
                }
                .aspectRatio(1, contentMode: .fill)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

/// sheet(item:) 需要 Identifiable 包装
struct NoticeDetailBox: Identifiable {
    let id = UUID()
    let value: NoticeDetail
}
