import SwiftUI

/// 聊天记录搜索：全局或指定会话内搜索，按日期分组 + 关键字高亮（对齐安卓 MessageSearchScreen）
struct MessageSearchView: View {
    /// 传空字符串表示全局搜索
    var scopeType: String = ""
    var scopeId: Int64 = 0
    var scopeTitle: String = ""
    /// 从全局搜索页带过来的关键词，进页即搜
    var initialKeyword: String = ""

    @State private var keyword = ""
    @State private var kind = "all"
    @State private var hits: [SearchMsgHit] = []
    @State private var searching = false
    @State private var searched = false
    @State private var hasMore = false
    @State private var page = 1
    @State private var nextBeforeId: Int64 = 0
    @State private var nextBeforeTs: Int64 = 0
    @State private var errorText: String?

    private struct KindOption: Identifiable {
        let key: String
        let label: String
        var id: String { key }
    }

    private let kinds: [KindOption] = [
        KindOption(key: "all", label: "全部"),
        KindOption(key: "image", label: "图片"),
        KindOption(key: "video", label: "视频"),
        KindOption(key: "file", label: "文件")
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            kindBar
            Color.clear.frame(height: 6)
            if hits.isEmpty {
                Text(emptyText)
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.hint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 48)
            } else {
                resultList
            }
        }
        .background(AKColor.bg)
        .reportsDetailPage()
        .restoresSwipeBack()
        .toolbar(.hidden, for: .navigationBar)
        .task {
            let seed = initialKeyword.trimmingCharacters(in: .whitespaces)
            if !seed.isEmpty && keyword.isEmpty {
                keyword = seed
                await search(reset: true)
            }
        }
        .onChange(of: kind) { _ in
            guard !keyword.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            hits = []
            searched = false
            Task { await search(reset: true) }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            BackButton()
                .frame(width: 44, height: 40)
            Text(scopeType.isEmpty ? "搜索全部聊天记录" : "查找聊天记录")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AKColor.text)
                .frame(maxWidth: .infinity)
            Spacer().frame(width: 44)
        }
        .padding(.vertical, 4)
        .background(AKColor.card)
    }

    private var emptyText: String {
        if searching { return "搜索中…" }
        if errorText != nil { return errorText ?? "" }
        if !searched { return "输入关键词后回车搜索" }
        return "没有找到相关记录"
    }

    private var searchBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.muted)
                TextField("搜索聊天记录", text: $keyword)
                    .font(.system(size: 13.5))
                    .submitLabel(.search)
                    .onSubmit { Task { await search(reset: true) } }
                if !keyword.isEmpty {
                    Button {
                        keyword = ""
                        hits = []
                        searched = false
                        errorText = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(AKColor.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(AKColor.fill)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AKColor.card)
    }

    private var kindBar: some View {
        HStack(spacing: 8) {
            ForEach(kinds) { item in
                Button {
                    kind = item.key
                } label: {
                    Text(item.label)
                        .font(.system(size: 12.5, weight: kind == item.key ? .medium : .regular))
                        .foregroundColor(kind == item.key ? AKColor.brand : AKColor.sub)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 5)
                        .background(kind == item.key ? AKColor.brandSoft : AKColor.fill)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AKColor.card)
    }

    private var resultList: some View {
        List {
            ForEach(resultRows) { row in
                rowView(row)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(AKColor.card)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AKColor.bg)
    }

    @ViewBuilder
    private func rowView(_ row: MessageRow) -> some View {
        switch row {
        case .day(let day):
            Text(day)
                .font(.system(size: 11.5))
                .foregroundColor(AKColor.hint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)
                .background(AKColor.bg)
        case .hit(let hit, let isLast):
            hitRow(hit, isLast: isLast)
        case .more:
            Button {
                Task { await search(reset: false) }
            } label: {
                Text(searching ? "加载中…" : "加载更多")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.brand)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 46)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(searching)
        }
    }

    private func hitRow(_ hit: SearchMsgHit, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                AvatarView(url: hit.convAvatar, name: senderName(hit), size: 40)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(senderName(hit))
                            .font(.system(size: 13.5))
                            .foregroundColor(AKColor.text)
                            .lineLimit(1)
                        if scopeType.isEmpty && !hit.convName.isEmpty {
                            Text(hit.convName)
                                .font(.system(size: 10.5))
                                .foregroundColor(AKColor.muted)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Text(clockText(hit.createdAt))
                            .font(.system(size: 10.5))
                            .foregroundColor(AKColor.muted)
                    }
                    if hit.recalled == 1 {
                        Text("该消息已撤回")
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.hint)
                    } else {
                        highlighted(hit.digest, keyword: keyword)
                            .font(.system(size: 13.5))
                            .foregroundColor(AKColor.text)
                            .lineLimit(2)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            if !isLast {
                Rectangle().fill(AKColor.line).frame(height: 0.6).padding(.leading, 65)
            }
        }
    }

    // MARK: - 行数据

    private enum MessageRow: Identifiable {
        case day(String)
        case hit(SearchMsgHit, Bool)
        case more

        var id: String {
            switch self {
            case .day(let d): return "day-\(d)"
            case .hit(let h, _): return "\(h.convType):\(h.convId):\(h.id)"
            case .more: return "more"
            }
        }
    }

    private var resultRows: [MessageRow] {
        var rows: [MessageRow] = []
        var dayOrder: [String] = []
        var buckets: [String: [SearchMsgHit]] = [:]
        for hit in hits {
            let day = dayKey(hit.createdAt)
            if buckets[day] == nil {
                dayOrder.append(day)
                buckets[day] = []
            }
            buckets[day]?.append(hit)
        }
        for day in dayOrder {
            let list = buckets[day] ?? []
            rows.append(.day(day))
            for (idx, hit) in list.enumerated() {
                rows.append(.hit(hit, idx == list.count - 1 && !hasMore))
            }
        }
        if hasMore {
            rows.append(.more)
        }
        return rows
    }

    private func senderName(_ hit: SearchMsgHit) -> String {
        hit.fromName.isEmpty ? "成员" : hit.fromName
    }

    // MARK: - 搜索

    private func search(reset: Bool) async {
        let text = keyword.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        if searching { return }
        searching = true
        if reset { searched = false }
        defer { searching = false }
        do {
            let data = try await APIClient.shared.searchMessages(
                keyword: text,
                convType: scopeType,
                convId: scopeId,
                kind: kind,
                page: reset ? 1 : page,
                beforeId: reset ? 0 : nextBeforeId,
                beforeTs: reset ? 0 : nextBeforeTs
            )
            if reset {
                hits = data.list
                page = data.page
            } else {
                let exists = Set(hits.map { "\($0.convType):\($0.convId):\($0.id)" })
                hits += data.list.filter { !exists.contains("\($0.convType):\($0.convId):\($0.id)") }
            }
            hasMore = data.hasMore == 1
            nextBeforeId = data.nextBeforeId
            nextBeforeTs = data.nextBeforeTs
            searched = true
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    // MARK: - 展示辅助

    private func highlighted(_ text: String, keyword: String) -> Text {
        let key = keyword.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return Text(text) }
        let ns = text as NSString
        guard ns.length > 0 else { return Text(text) }
        var result = Text("")
        var cursor = 0
        while cursor < ns.length {
            let range = ns.range(
                of: key,
                options: [.caseInsensitive],
                range: NSRange(location: cursor, length: ns.length - cursor)
            )
            if range.location == NSNotFound { break }
            if range.location > cursor {
                result = result + Text(ns.substring(with: NSRange(location: cursor, length: range.location - cursor)))
            }
            result = result + Text(ns.substring(with: range)).foregroundColor(AKColor.brand).bold()
            cursor = range.location + range.length
        }
        if cursor < ns.length {
            result = result + Text(ns.substring(from: cursor))
        }
        return result
    }

    private func clockText(_ ts: Int64) -> String {
        guard ts > 0 else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600) ?? .current
        f.dateFormat = "HH:mm"
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }

    private func dayKey(_ ts: Int64) -> String {
        guard ts > 0 else { return "更早" }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600) ?? .current
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        if cal.isDateInToday(date) { return "今天" }
        if cal.isDateInYesterday(date) { return "昨天" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = cal.timeZone
        if cal.component(.year, from: date) == cal.component(.year, from: Date()) {
            f.dateFormat = "M月d日"
        } else {
            f.dateFormat = "yyyy年M月d日"
        }
        return f.string(from: date)
    }
}
