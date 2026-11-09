import SwiftUI

/// 聊天消息正文：按服务端 type 渲染文本、图片、语音与全部卡片。
/// 卡片结构以 api_v1.php / im_push.php 的 extra 字段为准，与网页端保持同一口径。
struct MessageBody: View {
    let message: Message
    let mine: Bool
    var myUid: Int64 = 0
    var myName: String = "我"
    var playingVoice: Bool = false
    var onVoiceTap: () -> Void = {}
    /// 直播分享卡片点击：带入群 gid，由 ChatView 打开直播间
    var onOpenLive: (Int64) -> Void = { _ in }
    /// 群名片点击：带入群 gid，由 ChatView 打开群资料
    var onOpenGroup: (Int64) -> Void = { _ in }
    /// 个人名片点击
    var onOpenProfile: (Int64) -> Void = { _ in }
    /// 引用块点击：跳到被引用的原消息
    var onQuoteLocate: (Int64) -> Void = { _ in }
    /// 红包卡片点击：带入红包 id
    var onOpenRedPacket: (Int64) -> Void = { _ in }
    /// 转账 / 礼物卡片点击
    var onOpenPayCard: (Message) -> Void = { _ in }
    /// 通话卡片点击：1 语音 2 视频
    var onCallBack: (Int) -> Void = { _ in }
    /// 文件卡片点击：带入 url
    var onOpenFile: (String) -> Void = { _ in }
    /// 动态卡片点击：带入发布者 uid
    var onOpenMoment: (Int64) -> Void = { _ in }
    /// 聊天记录卡片点击：带入 content
    var onOpenRecord: (String) -> Void = { _ in }
    /// 多图相册点击：urls + 起点
    var onOpenAlbum: ([String], Int) -> Void = { _, _ in }

    private var ex: [String: JSONValue] { message.extraMap }
    private var rawText: String { message.text ?? message.content ?? "" }
    private var isGroup: Bool { message.convType == "group" }

    /* 服务端只给 7/8/9/12/13/14 补 extra；21/22/23/16/17/18/19 与相册只有 content。
       extra 优先，缺字段时回落到 content/text 里的 JSON。 */
    private var cardJSON: [String: Any] {
        MessageBody.jsonObject(message.content) ?? MessageBody.jsonObject(message.text) ?? [:]
    }

    private func cStr(_ key: String) -> String {
        if let v = ex[key]?.stringValue, !v.isEmpty, v != "null" { return v }
        if let v = cardJSON[key] as? String, !v.isEmpty, v != "null" { return v }
        if let v = cardJSON[key] as? NSNumber { return v.stringValue }
        if let v = cardJSON[key] as? Bool { return v ? "1" : "0" }
        return ""
    }

    private func cInt(_ key: String) -> Int {
        if let v = ex[key]?.intValue { return v }
        if let v = cardJSON[key] as? NSNumber { return v.intValue }
        if let v = cardJSON[key] as? String { return Int(v.trimmingCharacters(in: .whitespaces)) ?? 0 }
        return 0
    }

    private func cDbl(_ key: String) -> Double {
        if let v = ex[key]?.doubleValue { return v }
        if let v = cardJSON[key] as? NSNumber { return v.doubleValue }
        if let v = cardJSON[key] as? String { return Double(v.trimmingCharacters(in: .whitespaces)) ?? 0 }
        return 0
    }

    private func firstNonEmpty(_ values: String...) -> String {
        values.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""
    }

    private var recipientName: String {
        firstNonEmpty(cStr("to_name"), "对方")
    }

    var body: some View {
        switch message.type {
        case 11:
            systemRow
        case 2, 3, 20:
            noticeCard(title: "充值申请", detail: rawText, icon: "creditcard.fill",
                       tint: Color(UIColor(hex: 0xB07A18)), bg: Color(0xFFF7E6))
        case 7, 21:
            redPacket
        case 8, 22:
            transfer
        case 9, 23:
            gift
        case 10:
            quoteOrLocation
        case 12:
            userCard
        case 13:
            groupCard
        case 14:
            callCard
        case 15:
            videoBubble
        case 16:
            momentCard
        case 17:
            chatRecordCard
        case 18:
            fileCard
        case 19:
            liveCard
        case 30:
            Text("[该消息类型已下线]")
                .font(.system(size: 13))
                .foregroundColor(AKColor.muted)
        case 31:
            albumBubble
        case 5:
            imageBubble
        case 6:
            voiceBubble
        default:
            textBubble
        }
    }

    /* ---------------- 基础消息 ---------------- */

    private var textBubble: some View {
        Text(rawText)
            .font(.system(size: 15))
            .foregroundColor(mine ? .white : AKColor.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(mine ? AKColor.bubbleSelf : AKColor.bubbleOther)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(mine ? Color.clear : AKColor.line, lineWidth: 0.5)
            )
            .textSelection(.enabled)
    }

    private var imageBubble: some View {
        Group {
            if let url = APIClient.fullURL(VoiceService.cleanPath(message.text ?? message.content ?? "")) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: 10).fill(AKColor.fill)
                            .frame(width: 150, height: 150)
                    }
                }
                .frame(maxWidth: 190, maxHeight: 240)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Color.clear.frame(width: 1, height: 1)
            }
        }
    }

    /// 多图相册（type=31）：content 里是 {"imgs":[{"url":...}],"caption":...}
    private var albumBubble: some View {
        let urls: [String] = {
            guard let arr = cardJSON["imgs"] as? [Any] else { return [] }
            return arr.compactMap { item in
                if let o = item as? [String: Any], let u = o["url"] as? String, !u.isEmpty { return u }
                if let s = item as? String, !s.isEmpty { return s }
                return nil
            }
        }()
        let caption = cStr("caption")
        let n = urls.count
        let cols = n == 1 ? 1 : (n == 2 || n == 4 ? 2 : 3)
        let cell: CGFloat = n == 1 ? 200 : (cols == 2 ? 112 : 74)
        let gap: CGFloat = 3
        let width = cell * CGFloat(cols) + gap * CGFloat(cols - 1)
        return Group {
            if n > 0 {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(spacing: gap) {
                        ForEach(0..<((n + cols - 1) / cols), id: \.self) { row in
                            HStack(spacing: gap) {
                                ForEach(0..<cols, id: \.self) { col in
                                    let idx = row * cols + col
                                    if idx < n {
                                        AsyncImage(url: APIClient.fullURL(VoiceService.cleanPath(urls[idx]))) { phase in
                                            if let image = phase.image {
                                                image.resizable().scaledToFill()
                                            } else {
                                                AKColor.fill
                                            }
                                        }
                                        .frame(width: cell, height: cell)
                                        .clipped()
                                        .contentShape(Rectangle())
                                        .onTapGesture { onOpenAlbum(urls, idx) }
                                    } else {
                                        Color.clear.frame(width: cell, height: cell)
                                    }
                                }
                            }
                        }
                    }
                    if !caption.isEmpty {
                        Text(caption)
                            .font(.system(size: 14))
                            .foregroundColor(AKColor.text)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 7)
                    }
                }
                .frame(width: width)
                .background(AKColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var voiceSeconds: Int {
        let d = cInt("duration")
        if d > 0 { return d }
        let raw = message.content ?? ""
        guard let range = raw.range(of: "\"duration\":") else { return 0 }
        let tail = raw[range.upperBound...]
        return Int(tail.prefix { $0.isNumber }) ?? 0
    }

    private var voiceBubble: some View {
        Button(action: onVoiceTap) {
            HStack(spacing: 6) {
                Text(voiceSeconds > 0 ? "\(voiceSeconds)\"" : "语音")
                    .font(.system(size: 14))
                Image(systemName: playingVoice ? "stop.circle.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 15))
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .frame(minWidth: 64 + CGFloat(min(60, max(1, voiceSeconds))) * 3, alignment: .leading)
            .background(mine ? AKColor.bubbleSelf : AKColor.bubbleOther)
            .foregroundColor(mine ? .white : AKColor.text)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /* ---------------- 引用 ---------------- */

    private var quoteInfo: (id: Int64, name: String, content: String)? {
        let id = Int64(cInt("quote_id"))
        var name = cStr("quote_name")
        var content = cStr("quote_content")
        /* 本地刚发出/服务端未补 extra 时，从 content 的 JSON 前缀取 */
        if id <= 0, let raw = message.content, let sep = raw.range(of: "|#|") {
            let head = String(raw[raw.startIndex..<sep.lowerBound])
            if let o = MessageBody.jsonObject(head) {
                let qid = (o["quote_id"] as? NSNumber)?.int64Value ?? 0
                if qid > 0 {
                    if name.isEmpty { name = (o["quote_name"] as? String) ?? "" }
                    if content.isEmpty { content = (o["quote_content"] as? String) ?? "" }
                }
                return qid > 0 ? (qid, name, content) : nil
            }
        }
        return id > 0 ? (id, name, content) : nil
    }

    private var quoteBodyText: String {
        if let raw = message.content, let sep = raw.range(of: "|#|") {
            return String(raw[sep.upperBound...])
        }
        return rawText
    }

    @ViewBuilder
    private var quoteOrLocation: some View {
        if let quote = quoteInfo {
            quoteBubble(quote)
        } else if !cStr("lat").isEmpty || !cStr("lng").isEmpty || !cStr("address").isEmpty {
            locationCard
        } else {
            textBubble
        }
    }

    private func quoteBubble(_ quote: (id: Int64, name: String, content: String)) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Button {
                if quote.id > 0 { onQuoteLocate(quote.id) }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text((quote.name.isEmpty ? "对方" : quote.name) + "：")
                        .font(.system(size: 11.5))
                        .foregroundColor(mine ? Color.white.opacity(0.8) : AKColor.sub)
                        .lineLimit(1)
                    Text(quote.content.isEmpty ? "[消息]" : quote.content)
                        .font(.system(size: 12))
                        .foregroundColor(mine ? Color.white.opacity(0.9) : AKColor.sub)
                        .lineLimit(2)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(mine ? Color.white.opacity(0.2) : AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)

            Text(quoteBodyText)
                .font(.system(size: 14.5))
                .foregroundColor(mine ? .white : AKColor.text)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(mine ? AKColor.bubbleSelf : AKColor.bubbleOther)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(mine ? Color.clear : AKColor.line, lineWidth: 0.5)
        )
    }

    /* ---------------- 系统消息 ---------------- */

    private var systemText: String {
        let raw = rawText
        if raw.hasPrefix("{") {
            if let data = raw.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let t = obj["text"] as? String, !t.isEmpty { return t }
                if let t = obj["content"] as? String, !t.isEmpty { return t }
            }
        }
        return raw.isEmpty ? "消息已撤回" : raw
    }

    private var systemRow: some View {
        Text(systemText)
            .font(.system(size: 12))
            .foregroundColor(AKColor.muted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(AKColor.fill)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .frame(maxWidth: 280)
    }

    /* ---------------- 卡片 ---------------- */

    private func noticeCard(title: String, detail: String, icon: String, tint: Color, bg: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(AKColor.text)
                if !detail.isEmpty {
                    Text(detail).font(.system(size: 12)).foregroundColor(AKColor.sub).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 236, alignment: .leading)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var redPacketRid: Int64 {
        let rid = cInt("rp_id")
        return rid > 0 ? Int64(rid) : message.id
    }

    private var redPacket: some View {
        let amount = cInt("coin") > 0 ? cInt("coin") : (cInt("amount") > 0 ? cInt("amount") : cInt("total_coin"))
        let total = max(cInt("count"), 1)
        let grabbedCount = cInt("grabbed_count")
        let finished = cInt("finished") == 1 || grabbedCount >= total
        let claimed = cInt("status") != 0 || cInt("grabbed") == 1
        let mineGrabbed = cInt("i_grabbed") == 1
        let selfSent = mine || cInt("is_self") == 1
        let remark = firstNonEmpty(cStr("msg"), cStr("blessing"), "恭喜发财，大吉大利")
        let foot: String = {
            if selfSent && !isGroup { return claimed ? "已领取" : "点击查看红包" }
            if isGroup {
                if finished { return "已领完 · \(grabbedCount)/\(total)" }
                if mineGrabbed { return "已领取 · \(grabbedCount)/\(total)" }
                return "点击领取 · \(grabbedCount)/\(total)"
            }
            return (mineGrabbed || claimed) ? "已领取" : "点击领取"
        }()
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 9) {
                    Text("🧧").font(.system(size: 26))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selfSent ? "我发的红包" : "发了一个红包")
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(remark)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                Rectangle().fill(Color.white.opacity(0.2)).frame(height: 0.6)
                    .padding(.vertical, 10)
                HStack(spacing: 4) {
                    Text("¥\(amount) K币")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer(minLength: 0)
                    Text(foot)
                        .font(.system(size: 10.5))
                        .foregroundColor(Color(hex: 0xFFE9C7))
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            ZStack {
                Rectangle().fill(Color.white.opacity(0.13))
                Text("›").font(.system(size: 18)).foregroundColor(.white.opacity(0.8))
            }
            .frame(width: 26)
        }
        .frame(width: 232)
        .background(
            LinearGradient(colors: finished ? [Color(hex: 0xE59B8E), Color(hex: 0xCE8274)]
                                             : [AKColor.red, AKColor.red],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            let rid = redPacketRid
            if rid > 0 { onOpenRedPacket(rid) }
        }
    }

    private var transfer: some View {
        let amount = cInt("coin") > 0 ? cInt("coin") : Int(cDbl("amount"))
        let remark = firstNonEmpty(cStr("remark"), cStr("msg"))
        let done = cInt("status") != 0
        let toUid = cInt("to_uid") > 0 ? Int64(cInt("to_uid")) : message.toUid
        let isRcv = myUid > 0 && toUid == myUid
        let toName = firstNonEmpty(cStr("to_name"), isGroup ? "群成员" : recipientName)
        let title: String = {
            if isRcv { return "转账给你" }
            if mine { return "转账给 \(toName)" }
            return isGroup ? "转账给 \(toName)" : "转账给你"
        }()
        let foot: String = {
            if done { return (isRcv || !mine) ? "已被领取" : "对方已收款" }
            if isRcv { return "点击收款" }
            if mine { return "等待对方领取" }
            if isGroup { return "仅指定成员可领" }
            return "点击收款"
        }()
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0x6D7CFF), Color(hex: 0xB06BFF)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 28, height: 28)
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("\(amount) K币")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    if !remark.isEmpty {
                        Text(remark)
                            .font(.system(size: 10.5))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 13)

            HStack(spacing: 4) {
                Text(foot).font(.system(size: 10.5)).foregroundColor(.white.opacity(0.9))
                Spacer(minLength: 0)
                Text("›").font(.system(size: 15)).foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.12))
        }
        .frame(width: 226)
        .background(
            LinearGradient(colors: done ? [Color(hex: 0x9A8BE8), Color(hex: 0x7B6BCB)]
                                         : [Color(hex: 0x5B6BFF), Color(hex: 0x7C4DF5)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { onOpenPayCard(message) }
    }

    private var gift: some View {
        let giftName = firstNonEmpty(cStr("gift_name"), cStr("name"), "礼物")
        let count = max(cInt("count"), 1)
        let desc = firstNonEmpty(cStr("gift_desc"), giftName) + (count > 1 ? " ×\(count)" : "")
        let kind = firstNonEmpty(cStr("gift_type"), "mall")
        let level = max(cInt("level"), 1)
        let done = cInt("status") != 0
        let icon = kind == "vip" ? (level >= 2 ? "👑" : "💎") : "🎁"
        let toUid = cInt("to_uid") > 0 ? Int64(cInt("to_uid")) : message.toUid
        let isRcv = myUid > 0 && toUid == myUid
        let toName = firstNonEmpty(cStr("to_name"), recipientName)
        let title = isRcv ? "送给你的礼物" : "送给 \(toName) 的礼物"
        let foot: String = {
            if done { return "已领取" }
            if mine { return "等待对方领取" }
            if isRcv { return "点击领取" }
            return "仅指定成员可领"
        }()
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(icon)
                    .font(.system(size: 20))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(desc)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 13)

            HStack(spacing: 4) {
                Text(foot).font(.system(size: 10.5)).foregroundColor(.white.opacity(0.9))
                Spacer(minLength: 0)
                Text("›").font(.system(size: 15)).foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.12))
        }
        .frame(width: 226)
        .background(
            LinearGradient(colors: done ? [Color(hex: 0xEFC98D), Color(hex: 0xD9A75B)]
                                         : [AKColor.gold, Color(hex: 0xF09A17)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { onOpenPayCard(message) }
    }

    private var locationCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 20)).foregroundColor(AKColor.brand)
            VStack(alignment: .leading, spacing: 3) {
                Text(firstNonEmpty(cStr("address"), rawText, "位置"))
                    .font(.system(size: 13, weight: .medium)).foregroundColor(AKColor.text)
                    .lineLimit(2)
                Text("位置").font(.system(size: 11)).foregroundColor(AKColor.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 236, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var userCard: some View {
        let uid = Int64(cInt("uid"))
        let nickname = firstNonEmpty(cStr("nickname"), "用户")
        let number = firstNonEmpty(cStr("pretty_yxid"), cStr("yx_id"))
        let vip = cInt("vip_level")
        let pretty = cStr("pretty_yxid").isEmpty ? 0 : 1
        return HStack(spacing: 10) {
            AvatarView(url: cStr("avatar"), name: nickname, size: 42)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(nickname).font(.system(size: 14.5, weight: .medium))
                        .foregroundColor(akNameColor(vipLevel: vip, isPretty: pretty, isGroup: false))
                        .lineLimit(1)
                    if vip > 0 { VipBadge(level: vip) }
                }
                Text("AK号：\(number)").font(.system(size: 11)).foregroundColor(AKColor.muted)
            }
            Spacer(minLength: 0)
            Text("名片").font(.system(size: 11)).foregroundColor(AKColor.hint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(width: 232, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { if uid > 0 { onOpenProfile(uid) } }
    }

    private var groupCard: some View {
        let gid = Int64(cInt("gid"))
        let name = firstNonEmpty(cStr("name"), "群聊")
        let count = cInt("member_count")
        let pretty = cInt("is_pretty") == 1
        return HStack(spacing: 10) {
            AvatarView(url: cStr("avatar"), name: name, size: 42)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(name).font(.system(size: 14.5, weight: .medium))
                        .foregroundColor(pretty ? AKColor.gold : AKColor.text)
                        .lineLimit(1)
                    if pretty { PrettyBadge(number: cStr("pretty_no"), isGroup: true) }
                }
                Text(count > 0 ? "\(count) 人" : "群聊")
                    .font(.system(size: 11)).foregroundColor(AKColor.muted)
            }
            Spacer(minLength: 0)
            Text("群名片").font(.system(size: 11)).foregroundColor(AKColor.hint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(width: 232, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { if gid > 0 { onOpenGroup(gid) } }
    }

    /// 直播分享卡片（type=19）：gid/name/avatar/title/live_id，点击进直播间
    private var liveCard: some View {
        let name = firstNonEmpty(cStr("name"), "群直播")
        let title = firstNonEmpty(cStr("title"), name)
        let gid = Int64(cInt("gid"))
        return HStack(spacing: 10) {
            AvatarView(url: cStr("avatar"), name: name, size: 38)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AKColor.text)
                    .lineLimit(2)
                HStack(spacing: 5) {
                    Text("LIVE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color(hex: 0xFF3B30))
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    Text("群直播").font(.system(size: 11)).foregroundColor(AKColor.muted)
                }
            }
            Spacer(minLength: 0)
            Text(gid > 0 ? "进入 ›" : "已结束").font(.system(size: 11)).foregroundColor(AKColor.hint)
        }
        .padding(11)
        .frame(width: 236, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { if gid > 0 { onOpenLive(gid) } }
    }

    /// 通话记录：与 v1_call_digest 同一套文案（[群]视频/语音通话 + 状态）
    private var callCard: some View {
        let video = cInt("call_type") == 2
        let group = cInt("group") == 1 || isGroup
        let status = cInt("status")
        let duration = cInt("duration")
        let main: String = {
            switch status {
            case 2: return "通话时长 " + String(format: "%02d:%02d", duration / 60, duration % 60)
            case 3: return mine ? "对方已拒绝" : "已拒绝"
            case 4: return mine ? "对方无应答" : "未接来电"
            case 5: return group ? "通话已取消" : (mine ? "已取消" : "未接来电")
            case 6: return "通话已中断"
            default: return video ? "视频通话" : "语音通话"
            }
        }()
        let title = group ? (video ? "群视频通话" : "群语音通话") : (video ? "视频通话" : "语音通话")
        let missed = status >= 3 && status <= 6
        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(missed ? AKColor.redSoft : AKColor.blueSoft)
                    .frame(width: 34, height: 34)
                Image(systemName: video ? "video.fill" : "phone.fill")
                    .font(.system(size: 15))
                    .foregroundColor(missed ? AKColor.red : AKColor.link)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(main)
                    .font(.system(size: 13.5))
                    .foregroundColor(missed ? AKColor.red : AKColor.text)
                    .lineLimit(1)
                Text(title).font(.system(size: 10.5)).foregroundColor(AKColor.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(width: 210, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { onCallBack(video ? 2 : 1) }
    }

    private var videoBubble: some View {
        let cover = cStr("cover")
        let duration = cInt("duration")
        return ZStack {
            if let url = APIClient.fullURL(cover.isEmpty ? nil : cover) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color(hex: 0x1F2126)
                    }
                }
            } else {
                Color(hex: 0x1F2126)
            }
            Image(systemName: "play.circle.fill")
                .font(.system(size: 38))
                .foregroundColor(.white.opacity(0.92))
            if duration > 0 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(String(format: "%02d:%02d", duration / 60, duration % 60))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Capsule())
                    }
                }
                .padding(6)
            }
        }
        .frame(width: 190, height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = APIClient.fullURL(VoiceService.cleanPath(message.text ?? "")) {
                onOpenAlbum([url.absoluteString], 0)
            }
        }
    }

    private var momentCard: some View {
        let uid = Int64(cInt("uid"))
        let name = firstNonEmpty(cStr("name"), "用户")
        let avatar = cStr("avatar")
        let text = cStr("text")
        let vip = cInt("vip_level")
        let pretty = cStr("pretty_yxid").isEmpty ? 0 : 1
        var firstImage = ""
        if let arr = cardJSON["imgs"] as? [Any], let first = arr.first {
            if let s = first as? String { firstImage = s }
            if let o = first as? [String: Any], let s = o["url"] as? String { firstImage = s }
        }
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                AvatarView(url: avatar, name: name, size: 28)
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(akNameColor(vipLevel: vip, isPretty: pretty, isGroup: false))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("动态").font(.system(size: 10.5)).foregroundColor(AKColor.muted)
            }
            HStack(spacing: 10) {
                Text(text.isEmpty ? "分享了一条动态" : text)
                    .font(.system(size: 13))
                    .foregroundColor(text.isEmpty ? AKColor.muted : AKColor.text)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !firstImage.isEmpty {
                    AsyncImage(url: APIClient.fullURL(firstImage)) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            AKColor.fill
                        }
                    }
                    .frame(width: 96, height: 96)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            .padding(.top, 8)

            Rectangle().fill(AKColor.line).frame(height: 1).padding(.top, 10)
            HStack {
                Text("动态分享").font(.system(size: 10.5)).foregroundColor(AKColor.muted)
                Spacer(minLength: 0)
                Text("查看 ›").font(.system(size: 10.5)).foregroundColor(AKColor.muted)
            }
            .padding(.top, 8)
        }
        .padding(12)
        .frame(width: 240, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { onOpenMoment(uid > 0 ? uid : message.fromUid) }
    }

    private var chatRecordCard: some View {
        let parsed = MessageBody.jsonObject(message.content) ?? MessageBody.jsonObject(message.text)
        let title = (parsed?["title"] as? String) ?? "聊天记录"
        let lines: [String] = {
            guard let items = parsed?["items"] as? [Any] else { return [] }
            return items.prefix(4).compactMap { item in
                guard let o = item as? [String: Any] else { return nil }
                let u = (o["u"] as? String) ?? ""
                let c = (o["c"] as? String) ?? ""
                let line = (u.isEmpty ? "" : u + "：") + c
                return line.trimmingCharacters(in: .whitespaces).isEmpty ? nil : line
            }
        }()
        return VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 13.5, weight: .medium)).foregroundColor(AKColor.text)
                .lineLimit(2)
            if lines.isEmpty {
                Text("聊天记录").font(.system(size: 11.5)).foregroundColor(AKColor.sub)
                    .padding(.top, 6)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(lines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 11.5))
                            .foregroundColor(AKColor.sub)
                            .lineLimit(1)
                    }
                }
                .padding(.top, 6)
            }
            Rectangle().fill(AKColor.line).frame(height: 0.5).padding(.vertical, 6)
            Text("聊天记录").font(.system(size: 11)).foregroundColor(AKColor.muted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minWidth: 205, maxWidth: 250, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { onOpenRecord(message.content ?? message.text ?? "") }
    }

    private var fileCard: some View {
        let name = firstNonEmpty(cStr("name"), "文件")
        let size = cInt("size")
        let url = cStr("url")
        return HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AKColor.brandSoft)
                    .frame(width: 38, height: 38)
                Text("文件")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AKColor.brand)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 14, weight: .medium))
                    .foregroundColor(AKColor.text).lineLimit(2)
                Text(MessageBody.sizeText(size)).font(.system(size: 11)).foregroundColor(AKColor.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: 240, alignment: .leading)
        .background(mine ? AKColor.bubbleSelf : AKColor.bubbleOther)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { if !url.isEmpty { onOpenFile(url) } }
    }

    static func jsonObject(_ raw: String?) -> [String: Any]? {
        guard let raw, let data = raw.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    static func sizeText(_ bytes: Int) -> String {
        if bytes <= 0 { return "文件" }
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.0f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / 1024 / 1024)
    }
}
