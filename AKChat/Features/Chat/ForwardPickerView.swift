import SwiftUI

/// 选择转发目标：本地会话（置顶优先/时间倒序）+ 服务端「我的好友/我的群」搜索，
/// 与安卓 ForwardPickerScreen 同一口径：多选、显示将合并为聊天记录、底部发送按钮常驻。
struct ForwardPickerView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    let messages: [Message]
    var title: String = "聊天记录"
    var screenTitle: String = "选择会话"
    var subtitleOverride: String? = nil
    /// 每成功发往一个会话回调一次：服务端推送会排除发送者，调用方用它把消息即时补进当前会话
    var onSent: (String, Int64, Message?) -> Void = { _, _, _ in }

    @State private var picked: Set<String> = []
    /// 选中项的快照：搜索词变化后 rows 会被过滤，已选目标仍要能发出去
    @State private var pickedRows: [String: ForwardRow] = [:]
    @State private var keyword = ""
    @State private var searchResults: [ForwardRow] = []
    @State private var searching = false
    @State private var submitting = false
    @State private var hint = ""
    @State private var done = false

    private struct ForwardRow: Identifiable {
        let key: String
        let name: String
        let avatar: String?
        let isPretty: Int
        let prettyNo: String
        let vipLevel: Int
        let isGroup: Bool
        let isTop: Int
        let lastTime: Int64

        var id: String { key }
    }

    private var base: [ForwardRow] {
        app.conversations
            .filter { $0.convId > 0 }
            .map { c in
                ForwardRow(
                    key: "\(c.convType):\(c.convId)",
                    name: (c.name ?? "").isEmpty ? (c.convType == "group" ? "群聊" : "聊天") : (c.name ?? ""),
                    avatar: c.avatar,
                    isPretty: c.isPretty,
                    prettyNo: c.prettyNo ?? "",
                    vipLevel: c.vipLevel,
                    isGroup: c.convType == "group",
                    isTop: c.isTop,
                    lastTime: c.lastTime
                )
            }
            .sorted { a, b in
                if a.isTop != b.isTop { return a.isTop > b.isTop }
                if a.lastTime != b.lastTime { return a.lastTime > b.lastTime }
                return a.key < b.key
            }
    }

    private var localRows: [ForwardRow] {
        let q = keyword.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.prettyNo.contains(q) }
    }

    private var rows: [ForwardRow] {
        let localKeys = Set(localRows.map { $0.key } + base.map { $0.key })
        let extra = searchResults
            .filter { !localKeys.contains($0.key) }
            .sorted { a, b in
                if a.isTop != b.isTop { return a.isTop > b.isTop }
                if a.lastTime != b.lastTime { return a.lastTime > b.lastTime }
                return a.key < b.key
            }
        return localRows + extra
    }

    /// 可选目标从全量候选取：搜索关键字过滤后，选中项可能已不在 rows 里
    private var sendableRows: [ForwardRow] {
        var seen = Set<String>()
        var out: [ForwardRow] = []
        for row in base + searchResults where !seen.contains(row.key) {
            seen.insert(row.key)
            out.append(row)
        }
        return out
    }

    private var subtitle: String {
        messages.count > 1 ? "将合并为聊天记录转发" : "转发 1 条消息"
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            searchBar
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { row in
                        rowView(row)
                        Rectangle().fill(AKColor.line)
                            .frame(height: 0.5)
                            .padding(.leading, 67)
                    }
                    if rows.isEmpty {
                        Text(searching ? "搜索中…" : "没有匹配的好友或群聊")
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.hint)
                            .padding(.top, 60)
                    }
                }
            }
            .background(AKColor.card)
            bottomBar
        }
        .background(AKColor.card)
        .reportsDetailPage()
        .task {
            if app.conversations.isEmpty {
                await app.refreshConversations()
            }
        }
        .task(id: keyword) {
            let q = keyword.trimmingCharacters(in: .whitespaces)
            if q.isEmpty {
                searchResults = []
                searching = false
                return
            }
            searching = true
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            let resp = try? await APIClient.shared.shareTargets(keyword: q)
            guard !Task.isCancelled else { return }
            var out: [ForwardRow] = []
            for f in resp?.friends ?? [] {
                out.append(ForwardRow(key: "private:\(f.id)", name: f.displayName,
                                      avatar: f.avatar, isPretty: f.isPretty,
                                      prettyNo: f.prettyNo, vipLevel: f.vipLevel,
                                      isGroup: false, isTop: 0, lastTime: 0))
            }
            for g in resp?.groups ?? [] {
                out.append(ForwardRow(key: "group:\(g.id)", name: g.displayName,
                                      avatar: g.avatar, isPretty: g.isPretty,
                                      prettyNo: g.prettyNo, vipLevel: g.vipLevel,
                                      isGroup: true, isTop: 0, lastTime: 0))
            }
            searchResults = out
            searching = false
        }
        .alert("已转发", isPresented: $done) {
            Button("好") { dismiss() }
        }
    }

    private var topBar: some View {
        HStack(spacing: 0) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AKColor.text)
                    .frame(width: 44, height: 40)
            }
            VStack(spacing: 1) {
                Text(screenTitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AKColor.text)
                Text(subtitleOverride ?? subtitle)
                    .font(.system(size: 10.5))
                    .foregroundColor(AKColor.hint)
            }
            .frame(maxWidth: .infinity)
            Spacer().frame(width: 48)
        }
        .padding(.vertical, 4)
        .background(AKColor.card)
    }

    private var searchBar: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundColor(AKColor.muted)
            ZStack(alignment: .leading) {
                if keyword.isEmpty {
                    Text("搜索昵称 / AK号 / 群号")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.placeholder)
                }
                TextField("", text: $keyword)
                    .font(.system(size: 13.5))
                    .foregroundColor(AKColor.text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            if searching {
                Text("搜索中…")
                    .font(.system(size: 10.5))
                    .foregroundColor(AKColor.hint)
            } else if !keyword.isEmpty {
                Button {
                    keyword = ""
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AKColor.card)
    }

    private func rowView(_ row: ForwardRow) -> some View {
        let on = picked.contains(row.key)
        return Button {
            if on {
                picked.remove(row.key)
                pickedRows[row.key] = nil
            } else {
                picked.insert(row.key)
                pickedRows[row.key] = row
            }
        } label: {
            HStack(spacing: 11) {
                AvatarView(url: row.avatar, name: row.name, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(row.name)
                            .font(.system(size: 15))
                            .foregroundColor(AKColor.text)
                            .lineLimit(1)
                        if row.isPretty == 1 && !row.prettyNo.isEmpty {
                            PrettyBadge(number: row.prettyNo, isGroup: row.isGroup)
                        }
                        if row.vipLevel > 0 {
                            VipBadge(level: row.vipLevel)
                        }
                    }
                    Text(row.isGroup ? "群聊" : "好友")
                        .font(.system(size: 11))
                        .foregroundColor(AKColor.hint)
                }
                Spacer(minLength: 0)
                Image(systemName: on ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundColor(on ? AKColor.brand : AKColor.hint)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            if !hint.isEmpty {
                Text(hint)
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
            }
            Button {
                Task { await submit() }
            } label: {
                Text(submitting ? "发送中…" : (picked.isEmpty ? "发送" : "发送给 \(picked.count) 个会话"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(picked.isEmpty || submitting ? AKColor.placeholder : AKColor.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(picked.isEmpty || submitting)
            .padding(12)
        }
        .background(AKColor.card)
    }

    /* ---------------- 发送 ---------------- */

    private func submit() async {
        guard !submitting else { return }
        let targets = picked.compactMap { key -> ForwardRow? in
            if let row = pickedRows[key] { return row }
            return sendableRows.first { $0.key == key }
        }
        guard !targets.isEmpty else {
            hint = "请选择会话"
            return
        }
        submitting = true
        hint = ""
        defer { submitting = false }

        let payload = messages.count > 1 ? recordPayload(title: title) : nil
        var failed = 0
        for target in targets {
            let parts = target.key.split(separator: ":")
            guard parts.count == 2, let cid = Int64(parts[1]) else { continue }
            let ctype = String(parts[0])
            do {
                if let payload {
                    let res = try await APIClient.shared.sendTypedMessage(
                        convType: ctype, convId: cid, type: 17, content: payload,
                        clientId: "ios_fwd_\(UUID().uuidString)"
                    )
                    onSent(ctype, cid, res.message)
                } else if let first = messages.first {
                    if let sent = try await forwardOne(first, convType: ctype, convId: cid) {
                        onSent(ctype, cid, sent)
                    }
                }
            } catch {
                failed += 1
            }
        }
        if failed > 0 {
            hint = "有 \(failed) 条转发失败，请重试"
        } else {
            await app.refreshConversations()
            done = true
        }
    }

    /// 单条转发：与安卓 forwardOne 一致（文本原样、记录重发、媒体重发、其余 [消息]）
    private func forwardOne(_ m: Message, convType: String, convId: Int64) async throws -> Message? {
        let text = m.text ?? ""
        switch m.type {
        case 1, 10:
            guard !text.isEmpty else { return nil }
            let res = try await APIClient.shared.sendTypedMessage(
                convType: convType, convId: convId, type: m.type, content: text,
                clientId: "ios_fwd_\(UUID().uuidString)"
            )
            return res.message
        case 16:
            let res = try await APIClient.shared.sendTypedMessage(
                convType: convType, convId: convId, type: 1, content: "[动态分享]",
                clientId: "ios_fwd_\(UUID().uuidString)"
            )
            return res.message
        case 17:
            let raw = (m.content ?? "").isEmpty ? text : (m.content ?? "")
            guard !raw.isEmpty else { return nil }
            let res = try await APIClient.shared.sendTypedMessage(
                convType: convType, convId: convId, type: 17, content: raw,
                clientId: "ios_fwd_\(UUID().uuidString)"
            )
            return res.message
        case 5, 6, 15:
            guard !text.isEmpty else { return nil }
            let prefix = m.type == 5 && isSticker(m) ? "sticker_" : "ios_fwd_"
            let res = try await APIClient.shared.sendTypedMessage(
                convType: convType, convId: convId, type: m.type, content: text,
                clientId: prefix + UUID().uuidString
            )
            return res.message
        default:
            let res = try await APIClient.shared.sendTypedMessage(
                convType: convType, convId: convId, type: 1, content: "[消息]",
                clientId: "ios_fwd_\(UUID().uuidString)"
            )
            return res.message
        }
    }

    private func isSticker(_ m: Message) -> Bool {
        if (m.clientId ?? "").hasPrefix("sticker_") { return true }
        let t = m.text ?? ""
        return t.contains("/emoji/") || t.contains("uploads/emoji")
    }

    /// 合并转发内容：title/sub/items[{u,a,c,t,ty,p}]，最多 50 条
    private func recordPayload(title: String) -> String {
        var items: [[String: Any]] = []
        var first: Int64 = 0
        var last: Int64 = 0
        for m in messages.prefix(50) where m.type != 11 {
            let name = (m.fromName ?? "").isEmpty ? "成员" : (m.fromName ?? "")
            let body: String = {
                switch m.type {
                case 5: return isSticker(m) ? "[表情]" : "[图片]"
                case 6: return "[语音]"
                case 7, 21: return "[红包]"
                case 8, 22: return "[转账]"
                case 9, 23: return "[礼物]"
                case 12: return "[名片]"
                case 13: return "[群名片]"
                case 14: return "[通话]"
                case 15: return "[视频]"
                case 16: return "[动态]"
                case 17: return "[聊天记录]"
                case 18: return "[文件]"
                case 19: return "[直播]"
                default: return m.text ?? ""
                }
            }()
            items.append([
                "u": name,
                "a": m.fromAvatar ?? "",
                "c": String(body.prefix(200)),
                "t": m.createdAt,
                "ty": m.type,
                "p": m.type == 5 ? (m.text ?? "") : ""
            ])
            if first == 0 { first = m.createdAt }
            last = m.createdAt
        }
        if first == 0 { first = Int64(Date().timeIntervalSince1970) }
        let sub = "\(recordDay(first)) 至 \(recordDay(last))"
        let obj: [String: Any] = [
            "title": title.isEmpty ? "聊天记录" : title,
            "sub": sub,
            "items": items
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: obj),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    private func recordDay(_ ts: Int64) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)
        f.dateFormat = "M月d日"
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }
}

/* 服务端发送目标（/share/targets）：好友与群分开返回 */
struct ShareTarget: Decodable {
    let id: Int64
    let name: String
    let nickname: String
    let avatar: String?
    let yxId: String
    let isPretty: Int
    let prettyNo: String
    let vipLevel: Int
    let groupNo: String
    let memberCount: Int

    var displayName: String {
        let n = name.isEmpty ? nickname : name
        return n.isEmpty ? (groupNo.isEmpty ? "会话" : groupNo) : n
    }

    enum CodingKeys: String, CodingKey {
        case id, name, nickname, avatar
        case yxId = "yx_id"
        case isPretty = "is_pretty"
        case prettyNo = "pretty_no"
        case vipLevel = "vip_level"
        case groupNo = "group_no"
        case memberCount = "member_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        nickname = (try? c.decode(String.self, forKey: .nickname)) ?? ""
        avatar = try? c.decode(String.self, forKey: .avatar)
        yxId = (try? c.decode(String.self, forKey: .yxId)) ?? ""
        isPretty = (try? c.decode(Int.self, forKey: .isPretty)) ?? 0
        prettyNo = (try? c.decode(String.self, forKey: .prettyNo)) ?? ""
        vipLevel = (try? c.decode(Int.self, forKey: .vipLevel)) ?? 0
        groupNo = (try? c.decode(String.self, forKey: .groupNo)) ?? ""
        memberCount = (try? c.decode(Int.self, forKey: .memberCount)) ?? 0
    }
}

struct ShareTargetsResp: Decodable {
    let friends: [ShareTarget]
    let groups: [ShareTarget]

    enum CodingKeys: String, CodingKey { case friends, groups }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        friends = (try? c.decode([ShareTarget].self, forKey: .friends)) ?? []
        groups = (try? c.decode([ShareTarget].self, forKey: .groups)) ?? []
    }
}

extension APIClient {
    func shareTargets(keyword: String) async throws -> ShareTargetsResp {
        try await get("api/v1/share/targets", query: ["keyword": keyword])
    }
}

/// 名片分享选择器：左列群聊、右列好友，选中后 POST /share/card
/// （kind=group → 服务端发 type 13 群名片，kind=user → type 12 好友名片）。
/// 群最多选 5 个，好友不限。与安卓 CardSharePickerScreen 同一口径。
struct CardSharePickerView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    /// "group" 分享群名片 / "user" 分享好友名片
    let kind: String
    let cardId: Int64
    let cardName: String
    var onDone: (String) -> Void = { _ in }

    @State private var picked: [CardRow] = []
    @State private var keyword = ""
    @State private var serverGroups: [CardRow] = []
    @State private var serverFriends: [CardRow] = []
    @State private var busy = false
    @State private var hint = ""

    private static let maxGroups = 5

    private struct CardRow: Identifiable {
        let key: String
        let name: String
        let avatar: String?
        let number: String
        let isGroup: Bool

        var id: String { key }

        var ref: [String: Any] {
            let parts = key.split(separator: ":")
            let cid = parts.count == 2 ? (Int64(parts[1]) ?? 0) : 0
            return ["type": isGroup ? "group" : "private", "id": cid]
        }
    }

    private var sourceKey: String { "\(kind == "group" ? "group" : "private"):\(cardId)" }
    private var searchText: String { keyword.trimmingCharacters(in: .whitespaces) }
    private var pickedGroupCount: Int { picked.filter { $0.isGroup }.count }
    private var pickedFriendCount: Int { picked.count - pickedGroupCount }

    private var groupRows: [CardRow] { merge(serverGroups, localRows(isGroup: true)) }
    private var friendRows: [CardRow] { merge(serverFriends, localRows(isGroup: false)) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            searchBar
            HStack(spacing: 0) {
                column(title: "群聊", count: "已选 \(pickedGroupCount)/\(Self.maxGroups)",
                       rows: groupRows, empty: "暂无群聊")
                Rectangle().fill(AKColor.line).frame(width: 0.5)
                column(title: "好友", count: "已选 \(pickedFriendCount)",
                       rows: friendRows, empty: "暂无好友")
            }
            .frame(maxHeight: .infinity)
            bottomBar
        }
        .background(AKColor.bg)
        .task {
            if app.conversations.isEmpty { await app.refreshConversations() }
        }
        .task(id: keyword) {
            let q = searchText
            if !q.isEmpty {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
            }
            let resp = try? await APIClient.shared.shareTargets(keyword: q)
            guard !Task.isCancelled else { return }
            serverGroups = (resp?.groups ?? []).map { row(from: $0, isGroup: true) }
            serverFriends = (resp?.friends ?? []).map { row(from: $0, isGroup: false) }
        }
    }

    private var topBar: some View {
        HStack(spacing: 0) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AKColor.text)
                    .frame(width: 44, height: 40)
            }
            VStack(spacing: 1) {
                Text(kind == "group" ? "分享群名片" : "分享好友名片")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AKColor.text)
                Text(cardName)
                    .font(.system(size: 10.5))
                    .foregroundColor(AKColor.hint)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            Spacer().frame(width: 44)
        }
        .padding(.vertical, 4)
        .background(AKColor.card)
    }

    private var searchBar: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundColor(AKColor.muted)
            ZStack(alignment: .leading) {
                if keyword.isEmpty {
                    Text("搜索昵称 / AK号 / 群号")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.placeholder)
                }
                TextField("", text: $keyword)
                    .font(.system(size: 13.5))
                    .foregroundColor(AKColor.text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            if !keyword.isEmpty {
                Button {
                    keyword = ""
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AKColor.card)
    }

    private func column(title: String, count: String, rows: [CardRow], empty: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(AKColor.text)
                Spacer(minLength: 0)
                Text(count)
                    .font(.system(size: 10.5))
                    .foregroundColor(AKColor.hint)
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(AKColor.fill)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { row in
                        rowView(row)
                        Rectangle().fill(AKColor.line)
                            .frame(height: 0.5)
                            .padding(.leading, 47)
                    }
                    if rows.isEmpty {
                        Text(empty)
                            .font(.system(size: 12))
                            .foregroundColor(AKColor.hint)
                            .padding(.top, 40)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func rowView(_ row: CardRow) -> some View {
        let on = picked.contains { $0.key == row.key }
        return Button {
            toggle(row)
        } label: {
            HStack(spacing: 7) {
                AvatarView(url: row.avatar, name: row.name, size: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.name)
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.text)
                        .lineLimit(1)
                    if !row.number.isEmpty {
                        Text(row.number)
                            .font(.system(size: 10))
                            .foregroundColor(AKColor.hint)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17))
                    .foregroundColor(on ? AKColor.brand : AKColor.hint)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            if !hint.isEmpty {
                Text(hint)
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
            }
            Button {
                Task { await submit() }
            } label: {
                Text(busy ? "发送中…" : (picked.isEmpty ? "发送" : "发送给 \(picked.count) 个会话"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(picked.isEmpty || busy ? AKColor.placeholder : AKColor.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(picked.isEmpty || busy)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(AKColor.card)
    }

    private func row(from t: ShareTarget, isGroup: Bool) -> CardRow {
        CardRow(
            key: "\(isGroup ? "group" : "private"):\(t.id)",
            name: t.displayName,
            avatar: t.avatar,
            number: t.prettyNo.isEmpty ? (isGroup ? t.groupNo : t.yxId) : t.prettyNo,
            isGroup: isGroup
        )
    }

    private func localRows(isGroup: Bool) -> [CardRow] {
        let want = isGroup ? "group" : "private"
        let q = searchText
        return app.conversations
            .filter { conv in
                guard conv.convType == want, conv.convId > 0 else { return false }
                guard "\(conv.convType):\(conv.convId)" != sourceKey else { return false }
                guard !q.isEmpty else { return true }
                return (conv.name ?? "").localizedCaseInsensitiveContains(q)
                    || (conv.prettyNo ?? "").contains(q)
            }
            .map { conv in
                let name = conv.name ?? ""
                return CardRow(
                    key: "\(conv.convType):\(conv.convId)",
                    name: name.isEmpty ? (isGroup ? "群聊" : "好友") : name,
                    avatar: conv.avatar,
                    number: conv.prettyNo ?? "",
                    isGroup: isGroup
                )
            }
    }

    /// 服务端列表带 AK号/群号，排前面；本地会话只补服务端没返回的（新会话、已删好友等）
    private func merge(_ primary: [CardRow], _ extra: [CardRow]) -> [CardRow] {
        var seen = Set<String>()
        var out: [CardRow] = []
        for row in primary + extra where !seen.contains(row.key) {
            seen.insert(row.key)
            out.append(row)
        }
        return out.filter { $0.key != sourceKey }
    }

    private func toggle(_ row: CardRow) {
        if picked.contains(where: { $0.key == row.key }) {
            picked.removeAll { $0.key == row.key }
            hint = ""
            return
        }
        if row.isGroup && pickedGroupCount >= Self.maxGroups {
            hint = "最多只能选 \(Self.maxGroups) 个群"
            return
        }
        picked.append(row)
        hint = ""
    }

    private func submit() async {
        guard !busy else { return }
        guard !picked.isEmpty else {
            hint = "请选择会话"
            return
        }
        busy = true
        hint = ""
        defer { busy = false }
        do {
            let msg = try await APIClient.shared.postRaw("api/v1/share/card", body: [
                "kind": kind,
                "id": cardId,
                "targets": picked.map { $0.ref },
            ])
            await app.refreshConversations()
            dismiss()
            onDone(msg.isEmpty ? "名片已发送「\(cardName)」" : msg)
        } catch {
            hint = error.localizedDescription
        }
    }
}
