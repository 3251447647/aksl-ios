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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .sheet(item: $detailBox) { box in
            NoticeDetailView(detail: box.value,
                             isRead: box.isRead,
                             onConfirm: {
                                 readIds.insert(box.value.id)
                             },
                             onClose: { detailBox = nil })
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
                    .foregroundColor(AKColor.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
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
        if let data = try? await APIClient.shared.notices() {
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
}

/// 公告详情：渐变头卡（圆角 22）+ 正文卡（18，含图片）+ 我已知晓
struct NoticeDetailView: View {
    let detail: NoticeDetail
    let isRead: Bool
    let onConfirm: () -> Void
    let onClose: () -> Void

    @State private var confirmed = false
    @State private var sending = false

    private var done: Bool { isRead || confirmed }

    var body: some View {
        NavigationStack {
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
            .navigationTitle("公告详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
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
            Text((detail.content ?? "").isEmpty ? "暂无公告内容" : (detail.content ?? ""))
                .font(.system(size: 15))
                .foregroundColor(AKColor.text)
                .lineSpacing(6)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !detail.images.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3),
                          spacing: 6) {
                    ForEach(Array(detail.images.prefix(9).enumerated()), id: \.offset) { _, path in
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
