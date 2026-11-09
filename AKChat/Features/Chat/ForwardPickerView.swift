import SwiftUI

/// 选择转发目标：本地会话（置顶优先/时间倒序）+ 服务端「我的好友/我的群」搜索，
/// 与安卓 ForwardPickerScreen 同一口径：多选、显示将合并为聊天记录、底部发送按钮常驻。
struct ForwardPickerView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    let messages: [Message]
    var title: String = "聊天记录"

    @State private var picked: Set<String> = []
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
                Text("选择会话")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AKColor.text)
                Text(subtitle)
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
            if on { picked.remove(row.key) } else { picked.insert(row.key) }
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
        let targets = rows.filter { picked.contains($0.key) }
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
                    _ = try await APIClient.shared.sendTypedMessage(
                        convType: ctype, convId: cid, type: 17, content: payload,
                        clientId: "ios_fwd_\(UUID().uuidString)"
                    )
                } else if let first = messages.first {
                    try await forwardOne(first, convType: ctype, convId: cid)
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
    private func forwardOne(_ m: Message, convType: String, convId: Int64) async throws {
        let text = m.text ?? ""
        switch m.type {
        case 1, 10:
            guard !text.isEmpty else { return }
            _ = try await APIClient.shared.sendTypedMessage(
                convType: convType, convId: convId, type: m.type, content: text,
                clientId: "ios_fwd_\(UUID().uuidString)"
            )
        case 16:
            _ = try await APIClient.shared.sendTypedMessage(
                convType: convType, convId: convId, type: 1, content: "[动态分享]",
                clientId: "ios_fwd_\(UUID().uuidString)"
            )
        case 17:
            let raw = (m.content ?? "").isEmpty ? text : (m.content ?? "")
            guard !raw.isEmpty else { return }
            _ = try await APIClient.shared.sendTypedMessage(
                convType: convType, convId: convId, type: 17, content: raw,
                clientId: "ios_fwd_\(UUID().uuidString)"
            )
        case 5, 6, 15:
            guard !text.isEmpty else { return }
            let prefix = m.type == 5 && isSticker(m) ? "sticker_" : "ios_fwd_"
            _ = try await APIClient.shared.sendTypedMessage(
                convType: convType, convId: convId, type: m.type, content: text,
                clientId: prefix + UUID().uuidString
            )
        default:
            _ = try await APIClient.shared.sendTypedMessage(
                convType: convType, convId: convId, type: 1, content: "[消息]",
                clientId: "ios_fwd_\(UUID().uuidString)"
            )
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
