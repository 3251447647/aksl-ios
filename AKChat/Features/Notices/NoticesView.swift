import SwiftUI

struct NoticesView: View {
    @EnvironmentObject private var app: AppState
    @State private var list: [Notice] = []
    @State private var detail: NoticeDetail?

    var body: some View {
        List {
            ForEach(list) { notice in
                Button {
                    Task { await openNotice(notice) }
                } label: {
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
                }
            }
            if list.isEmpty {
                Text("暂无公告").font(.system(size: 13)).foregroundColor(AKColor.muted)
            }
        }
        .navigationTitle("公告")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .sheet(item: Binding(
            get: { detail.map { NoticeDetailBox(value: $0) } },
            set: { if $0 == nil { detail = nil } }
        )) { box in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(box.value.title ?? "公告")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundColor(AKColor.text)
                            HStack(spacing: 8) {
                                if box.value.isTop == 1 {
                                    BadgeView(text: "置顶", color: AKColor.red, background: AKColor.redSoft)
                                }
                                Text(TimeText.full(box.value.createdAt))
                                    .font(.system(size: 11.5))
                                    .foregroundColor(AKColor.muted)
                            }
                            Rectangle().fill(AKColor.line).frame(height: 0.5)
                            Text(box.value.content ?? "")
                                .font(.system(size: 14.5))
                                .foregroundColor(AKColor.text)
                                .lineSpacing(4)
                                .textSelection(.enabled)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AKColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        if !box.value.images.isEmpty {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                                ForEach(box.value.images, id: \.self) { path in
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
                        Spacer()
                    }
                    .padding(12)
                }
                .background(AKColor.bg)
                .navigationTitle("公告详情")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("关闭") { detail = nil }
                    }
                }
            }
        }
    }

    private func load() async {
        if let data = try? await APIClient.shared.notices() {
            list = data.list
        }
    }

    private func openNotice(_ notice: Notice) async {
        if let d = try? await APIClient.shared.notice(id: notice.id) {
            detail = d
        }
        await APIClient.shared.readNotice(id: notice.id)
        if let idx = list.firstIndex(where: { $0.id == notice.id }) {
            list[idx] = Notice.copy(notice, read: 1)
        }
    }
}

private struct NoticeDetailBox: Identifiable {
    let value: NoticeDetail
    var id: Int64 { value.id }
}

private extension Notice {
    static func copy(_ n: Notice, read: Int) -> Notice {
        Notice(
            id: n.id, title: n.title, summary: n.summary, content: n.content,
            images: n.images, read: read, isTop: n.isTop, createdAt: n.createdAt
        )
    }
}
