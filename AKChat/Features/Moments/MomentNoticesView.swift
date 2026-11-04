import SwiftUI

struct MomentNoticesView: View {
    @State private var items: [MomentNotice] = []
    @State private var page = 1
    @State private var hasMore = false
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        List {
            if loading {
                ProgressView()
            } else if items.isEmpty {
                Text("还没有新的互动消息")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(items) { item in
                    row(item)
                        .listRowBackground(item.isRead == 0 ? AKColor.brandSoft.opacity(0.5) : AKColor.card)
                }
                if hasMore {
                    Button {
                        Task { await loadMore() }
                    } label: {
                        Text("加载更多").font(.system(size: 13)).foregroundColor(AKColor.link)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            if let error {
                Text(error).font(.system(size: 12)).foregroundColor(AKColor.red)
            }
        }
        .listStyle(.plain)
        .navigationTitle("互动消息")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func row(_ item: MomentNotice) -> some View {
        Button {
            if item.isRead == 0 {
                Task { await APIClient.shared.readMomentNotices(id: item.id) }
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                AvatarView(url: item.fromAvatar, name: item.fromName, size: 38)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(item.fromName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(akNameColor(vipLevel: item.vipLevel,
                                                         isPretty: item.isPretty,
                                                         isGroup: false))
                        Text(item.actionText)
                            .font(.system(size: 12))
                            .foregroundColor(AKColor.sub)
                        Spacer()
                        Text(TimeText.short(item.createdAt))
                            .font(.system(size: 11))
                            .foregroundColor(AKColor.hint)
                    }
                    if !item.content.isEmpty {
                        Text(item.content)
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.text)
                            .lineLimit(2)
                    }
                    if !item.momentText.isEmpty {
                        Text(item.momentText)
                            .font(.system(size: 12))
                            .foregroundColor(AKColor.muted)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let data = try await APIClient.shared.momentNotices(page: 1)
            items = data.list
            hasMore = data.hasMore == 1
            page = 1
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadMore() async {
        do {
            let next = page + 1
            let data = try await APIClient.shared.momentNotices(page: next)
            items.append(contentsOf: data.list)
            hasMore = data.hasMore == 1
            page = next
        } catch {
            self.error = error.localizedDescription
        }
    }
}
