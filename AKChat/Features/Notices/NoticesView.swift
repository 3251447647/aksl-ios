import SwiftUI

/// 系统公告列表：标题 15 / 摘要 12 两行 / 时间 10 / 未读红点（对齐安卓 NoticeScreen）
struct NoticesView: View {
    @State private var list: [Notice] = []
    @State private var loading = true
    @State private var detailBox: NoticeDetailBox?

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
        .navigationTitle("系统公告")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .sheet(item: $detailBox) { box in
            NoticeDetailView(detail: box.value) { detailBox = nil }
        }
    }

    private func row(_ notice: Notice) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    if notice.isTop == 1 {
                        BadgeView(text: "置顶", color: AKColor.red, background: AKColor.redSoft)
                    }
                    Text(notice.title ?? "公告")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AKColor.text)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                Text(notice.summary ?? notice.content ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.muted)
                    .lineLimit(2)
                Text(TimeText.short(notice.createdAt))
                    .font(.system(size: 10))
                    .foregroundColor(AKColor.placeholder)
            }
            if notice.read == 0 {
                Circle()
                    .fill(AKColor.red)
                    .frame(width: 8, height: 8)
                    .padding(.top, 3)
            }
        }
        .padding(16)
        .contentShape(Rectangle())
    }

    private func load() async {
        if let data = try? await APIClient.shared.notices() {
            list = data.list
        }
        loading = false
    }

    private func openNotice(_ notice: Notice) async {
        if let d = try? await APIClient.shared.notice(id: notice.id) {
            detailBox = NoticeDetailBox(value: d)
        }
    }
}

/// 公告详情：标题/时间/正文卡片（圆角 14）+ 三列图片
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
            Text(TimeText.full(detail.createdAt))
                .font(.system(size: 11))
                .foregroundColor(AKColor.muted)
            Rectangle().fill(AKColor.line).frame(height: 0.5)
            Text(detail.content ?? "")
                .font(.system(size: 15))
                .foregroundColor(AKColor.text)
                .lineSpacing(5)
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
