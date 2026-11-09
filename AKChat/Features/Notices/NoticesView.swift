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

/// 公告详情：渐变头卡（圆角 22）+ 正文卡（18）+ 三列图片
struct NoticeDetailView: View {
    let detail: NoticeDetail
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    heroCard
                    contentCard
                    if !detail.images.isEmpty {
                        imagesGrid
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
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
                Text(TimeText.full(detail.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.8))
            }
            Text(detail.title ?? "系统公告")
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
        Text(detail.content ?? "")
            .font(.system(size: 15))
            .foregroundColor(AKColor.text)
            .lineSpacing(6)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(AKColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var imagesGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
            ForEach(detail.images, id: \.self) { path in
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        AsyncImage(url: APIClient.fullURL(path)) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                AKColor.fill
                            }
                        }
                    )
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(10)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// sheet(item:) 需要 Identifiable 包装
struct NoticeDetailBox: Identifiable {
    let id = UUID()
    let value: NoticeDetail
}
