import SwiftUI

/// 朋友圈消息：好友发新动态 / 赞我 / 评论我 / 回复我（对齐安卓 MomentNoticesScreen）
struct MomentNoticesView: View {
    @State private var items: [MomentNotice] = []
    @State private var page = 1
    @State private var hasMore = false
    @State private var loading = true
    @State private var loadingMore = false
    @State private var error: String?

    var body: some View {
        List {
            if loading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowSeparator(.hidden)
            } else if items.isEmpty {
                Text("还没有朋友圈消息")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.hint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(items) { item in
                    row(item)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(item.isRead == 0 ? AKColor.brandSoft.opacity(0.35) : AKColor.card)
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 69 }
                }
                if hasMore {
                    Button {
                        Task { await loadMore() }
                    } label: {
                        Text(loadingMore ? "加载中…" : "加载更多")
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.link)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .listRowBackground(AKColor.card)
                }
            }
            if let error {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.red)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AKColor.bg)
        .navigationTitle("朋友圈消息")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
        .refreshable { await load() }
        .task { await load() }
    }

    private func row(_ item: MomentNotice) -> some View {
        Button {
            if item.isRead == 0 {
                Task { await APIClient.shared.readMomentNotices(id: item.id) }
            }
        } label: {
            HStack(alignment: .top, spacing: 11) {
                ZStack(alignment: .topTrailing) {
                    AvatarView(url: item.fromAvatar, name: item.fromName, size: 42)
                    if item.isRead == 0 {
                        Circle().fill(AKColor.red).frame(width: 8, height: 8)
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Text(item.fromName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(akNameColor(vipLevel: item.vipLevel,
                                                         isPretty: item.isPretty,
                                                         isGroup: false))
                            .lineLimit(1)
                        if item.isPretty == 1, !item.prettyNo.isEmpty {
                            BadgeView(text: item.prettyNo, color: AKColor.gold, background: AKColor.goldSoft)
                        }
                        if item.vipLevel > 0 {
                            BadgeView(text: item.vipLevel >= 2 ? "SVIP" : "VIP")
                        }
                        Spacer(minLength: 0)
                    }
                    Text(Self.actionText(item.type))
                        .font(.system(size: 12.5))
                        .foregroundColor(AKColor.sub)
                        .padding(.top, 2)
                    if !item.content.isEmpty {
                        Text(item.content)
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.text)
                            .lineLimit(2)
                            .padding(.top, 3)
                    }
                    if !item.momentText.isEmpty {
                        Text(item.momentText)
                            .font(.system(size: 12))
                            .foregroundColor(AKColor.sub)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(AKColor.fill)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .padding(.top, 5)
                    }
                    Text(Self.timeText(item.createdAt))
                        .font(.system(size: 10.5))
                        .foregroundColor(AKColor.hint)
                        .padding(.top, 4)
                }
                if !item.momentThumb.isEmpty {
                    AsyncImage(url: APIClient.fullURL(item.momentThumb)) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFill()
                        } else {
                            AKColor.fill
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private static func actionText(_ type: String) -> String {
        switch type {
        case "new_post": return "发布了新动态"
        case "like": return "赞了你的动态"
        case "comment": return "评论了你的动态"
        case "reply": return "回复了你"
        default: return "有新动态"
        }
    }

    /// 刚刚 / N 分钟前 / 今天 HH:mm / 昨天 / MM-dd
    private static func timeText(_ ts: Int64) -> String {
        guard ts > 0 else { return "" }
        let diff = Date().timeIntervalSince1970 - TimeInterval(ts)
        if diff < 60 { return "刚刚" }
        if diff < 3600 { return "\(Int(diff / 60)) 分钟前" }
        return TimeText.short(ts)
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
        guard !loadingMore else { return }
        loadingMore = true
        defer { loadingMore = false }
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
