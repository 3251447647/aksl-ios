import SwiftUI
import AVFoundation
import UIKit

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
    /// 图片/视频/表情缩略图点击：原始地址 + 是否视频，由 ChatView 组装会话预览列表
    var onOpenMedia: (String, Bool) -> Void = { _, _ in }
    /// 会话对方名称：转账/礼物卡片收款人兜底（对齐安卓 peerName）
    var peerName: String = "对方"
    /// 群聊 @ 名字 → uid（0 表示 @全体成员，-1 表示成员信息关闭）
    var mentionMap: [String: Int64] = [:]
    var onMention: (Int64) -> Void = { _ in }
    /// 语音是否已播放过：对方发来的语音没播过显示红点
    var voicePlayed: Bool = true

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
        firstNonEmpty(cStr("to_name"), peerName)
    }

    var body: some View {
        switch message.type {
        case 11:
            systemRow
        case 2, 3, 20:
            rechargeCard
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
            if let line = groupCallLine {
                systemCapsule(line)
            } else if isGroupCallRecord {
                EmptyView()
            } else {
                callCard
            }
        case 15:
            // 15 正常是视频；内容是带 items 的聊天记录 JSON 时按记录卡片渲染
            if isForwardedRecord {
                chatRecordCard
            } else {
                videoBubble
            }
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
            if isSticker {
                stickerBubble
            } else if (message.text ?? "").isEmpty {
                localPendingImage
            } else {
                imageBubble
            }
        case 6:
            voiceBubble
        default:
            textBubble
        }
    }

    /* ---------------- 基础消息 ---------------- */

    private var textColor: Color { mine ? .white : AKColor.text }

    private var textBubble: some View {
        AKLinkText(text: rawText, color: textColor, fontSize: 14.5, lineHeight: 20,
                   mentionMap: isGroup ? mentionMap : [:], onMention: onMention)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(mine ? AKColor.bubbleSelf : AKColor.bubbleOther)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(mine ? Color.clear : AKColor.line, lineWidth: 0.5)
            )
    }

    private var isSticker: Bool {
        if (message.clientId ?? "").hasPrefix("sticker_") { return true }
        let t = message.text ?? ""
        return t.contains("/emoji/") || t.contains("uploads/emoji")
    }

    /// 合并转发内容是 {title, sub, items} JSON；视频消息是 URL|#|JSON，不会互相误判
    private var isForwardedRecord: Bool {
        guard let o = MessageBody.jsonObject(message.content) ?? MessageBody.jsonObject(message.text),
              (o["items"] as? [Any]) != nil else {
            return false
        }
        return true
    }

    /// 图片宽高比：优先 content 里的 w/h（0.4–2.5），老图按 4:3
    private var imageMeta: (ratio: CGFloat, caption: String) {
        let raw = message.content ?? ""
        let parts = raw.components(separatedBy: "|#|")
        if parts.count > 1, let o = MessageBody.jsonObject(parts.dropFirst().joined(separator: "|#|")) {
            let w = (o["w"] as? NSNumber)?.doubleValue ?? 0
            let h = (o["h"] as? NSNumber)?.doubleValue ?? 0
            let cap = (o["caption"] as? String) ?? ""
            if w > 0, h > 0 { return (CGFloat(min(max(w / h, 0.4), 2.5)), cap) }
            return (4.0 / 3.0, cap)
        }
        return (4.0 / 3.0, "")
    }

    /// 本地上传中/失败的图片：先占位，避免出现 1×1 的空白
    private var localPendingImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AKColor.fill)
            if message.status == 2 {
                Text("发送失败")
                    .font(.system(size: 11))
                    .foregroundColor(AKColor.sub)
            } else {
                ProgressView().scaleEffect(0.8)
            }
        }
        .frame(width: 150, height: 150)
    }

    private var imageBubble: some View {
        let meta = imageMeta
        let boxW = min(200, 260 * meta.ratio)
        let boxH = boxW / meta.ratio
        return Group {
            if let url = APIClient.fullURL(VoiceService.cleanPath(message.text ?? message.content ?? "")) {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear
                        .frame(width: boxW, height: boxH)
                        .overlay {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFit()
                                } else {
                                    AKColor.fill
                                }
                            }
                        }
                        .clipped()
                    if !meta.caption.isEmpty {
                        Text(meta.caption)
                            .font(.system(size: 14))
                            .foregroundColor(AKColor.text)
                            .lineSpacing(2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                    }
                }
                .background(meta.caption.isEmpty ? Color.clear : AKColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture { onOpenMedia(rawText, false) }
            } else {
                Color.clear.frame(width: 1, height: 1)
            }
        }
    }

    /// 表情：96×96、等比、无气泡；视频表情循环静音播放
    private var stickerBubble: some View {
        Group {
            let raw = (message.text ?? message.content ?? "").lowercased()
            if raw.hasSuffix(".mp4") || raw.hasSuffix(".mov") || raw.hasSuffix(".webm") || raw.hasSuffix(".m4v") {
                if let url = APIClient.fullURL(VoiceService.cleanPath(message.text ?? "")) {
                    LoopingVideo(url: url)
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            } else if let url = APIClient.fullURL(VoiceService.cleanPath(message.text ?? "")) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        AKColor.fill
                    }
                }
                .frame(width: 96, height: 96)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            let lower = (message.text ?? message.content ?? "").lowercased()
            let isVideo = lower.hasSuffix(".mp4") || lower.hasSuffix(".mov")
                || lower.hasSuffix(".webm") || lower.hasSuffix(".m4v")
            onOpenMedia(rawText, isVideo)
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

    @State private var voiceFill: CGFloat = 0

    private var voiceBubble: some View {
        Button(action: onVoiceTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(voiceSeconds > 0 ? "\(voiceSeconds)\"" : "语音")
                        .font(.system(size: 14))
                    Image(systemName: playingVoice ? "stop.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 16))
                    if !mine && !voicePlayed {
                        Circle().fill(AKColor.red).frame(width: 7, height: 7)
                    }
                }
                if playingVoice {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AKColor.line).frame(height: 2)
                            Capsule().fill(AKColor.brand)
                                .frame(width: max(0, geo.size.width * voiceFill), height: 2)
                        }
                    }
                    .frame(height: 2)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .frame(minWidth: min(244, 64 + CGFloat(min(60, max(1, voiceSeconds))) * 3), alignment: .leading)
            .background(mine ? AKColor.bubbleSelf : AKColor.bubbleOther)
            .foregroundColor(textColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(mine ? Color.clear : AKColor.line, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onChange(of: playingVoice) { on in
            if on {
                voiceFill = 0
                withAnimation(.linear(duration: Double(max(1, voiceSeconds)))) { voiceFill = 1 }
            } else {
                voiceFill = 0
            }
        }
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

            AKLinkText(text: quoteBodyText, color: textColor, fontSize: 14.5, lineHeight: 20,
                       mentionMap: isGroup ? mentionMap : [:], onMention: onMention)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(mine ? AKColor.bubbleSelf : AKColor.bubbleOther)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
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

    @Environment(\.colorScheme) private var colorScheme

    private var systemRow: some View {
        VStack(spacing: 0) {
            Text(systemText)
                .font(.system(size: 11.5))
                .foregroundColor(AKColor.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private var callRaw: String {
        let c = message.content ?? ""
        return c.isEmpty ? (message.text ?? "") : c
    }

    /// 群通话记录：已有配对系统消息时不再重复展示
    private var isGroupCallRecord: Bool {
        guard let o = MessageBody.jsonObject(callRaw) else { return false }
        return (o["group"] as? NSNumber)?.intValue == 1
    }

    private var groupCallLine: String? {
        guard isGroup,
              let o = MessageBody.jsonObject(callRaw),
              (o["group"] as? NSNumber)?.intValue == 1 else { return nil }
        if (o["sys_written"] as? NSNumber)?.intValue == 1 { return nil }
        let callerRaw = (o["caller_name"] as? String) ?? ""
        let caller = (!callerRaw.isEmpty && callerRaw != "null") ? callerRaw
            : firstNonEmpty(message.fromName ?? "", "群成员")
        let dur = (o["duration"] as? NSNumber)?.intValue ?? 0
        if (o["status"] as? NSNumber)?.intValue == 5 {
            return "\(caller) 发起了群通话，已取消"
        }
        return "\(caller) 发起了群通话 " + String(format: "%02d:%02d", dur / 60, dur % 60)
    }

    private func systemCapsule(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundColor(AKColor.muted)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }

    /* ---------------- 卡片 ---------------- */

    /// 充值申请（type 2/3/20）：238 宽卡片，头部图标 + 状态胶囊 + 大号金额 + 提交时间
    private var rechargeCard: some View {
        let amount = cInt("amount") > 0 ? cInt("amount") : Int(cDbl("amount"))
        var remark = firstNonEmpty(cStr("remark"), cStr("msg"))
        /* 网页端 type=2 的正文就是备注，不是 JSON */
        if remark.isEmpty, message.type == 2, MessageBody.jsonObject(rawText) == nil {
            remark = rawText
        }
        let status = cInt("status")
        let reason = cStr("reject_reason")
        let statusText: String = {
            switch status {
            case 1: return "已完成"
            case 2: return "已取消"
            default: return "待处理"
            }
        }()
        let statusColor: Color = {
            switch status {
            case 1: return Color(hex: 0x0FB67A)
            case 2: return AKColor.sub
            default: return Color(hex: 0xE68600)
            }
        }()
        let statusBg: Color = {
            switch status {
            case 1: return AKColor.brandSoft
            case 2: return AKColor.fill
            default: return AKColor.goldSoft
            }
        }()
        let timeText = MessageBody.shortDateTime(message.createdAt)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(AKColor.brandSoft)
                        .frame(width: 28, height: 28)
                    Text("¥")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: 0x0FB67A))
                }
                Text("充值申请")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(AKColor.text)
                Spacer(minLength: 0)
                Text(statusText)
                    .font(.system(size: 10))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(statusBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(amount)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AKColor.text)
                Text("K币")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.sub)
                    .padding(.bottom, 3)
            }
            .padding(.top, 10)
            if !remark.isEmpty {
                Text("备注：\(remark)")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.sub)
                    .lineLimit(2)
                    .padding(.top, 5)
            }
            if status == 2 && !reason.isEmpty {
                Text("拒绝理由：\(reason)")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.red)
                    .lineLimit(2)
                    .padding(.top, 5)
            }
            Rectangle().fill(AKColor.fill).frame(height: 0.6).padding(.top, 10)
            HStack(spacing: 0) {
                Text("提交时间 \(timeText)")
                    .font(.system(size: 10.5))
                    .foregroundColor(AKColor.hint)
                Spacer(minLength: 0)
                Text("查看详情 ›")
                    .font(.system(size: 10.5))
                    .foregroundColor(AKColor.link)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 238, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AKColor.fill, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onOpenPayCard(message) }
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
        let toName = firstNonEmpty(cStr("to_name"), peerName)
        let title = isRcv ? "送给你的礼物" : "送给 \(toName) 的礼物"
        let foot: String = {
            if done { return "已领取" }
            if mine { return "等待对方领取" }
            if isRcv { return "点击领取" }
            return "仅指定成员可领"
        }()
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Text(icon).font(.system(size: 20))
                }
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
            HStack(spacing: 0) {
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
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AKColor.brandSoft)
                    .frame(width: 36, height: 36)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 17))
                    .foregroundColor(AKColor.brand)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(firstNonEmpty(cStr("address"), rawText, "位置"))
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(AKColor.text)
                    .lineLimit(2)
                Text("位置").font(.system(size: 11)).foregroundColor(AKColor.muted)
            }
            Spacer(minLength: 0)
        }
        .akCardSurface()
        .contentShape(Rectangle())
        .onTapGesture { openLocation() }
    }

    /// 位置卡片：有坐标带坐标，只有地址就按地址搜，交给系统地图
    private func openLocation() {
        let lat = cDbl("lat")
        let lng = cDbl("lng")
        let address = firstNonEmpty(cStr("address"), rawText)
        var comps = URLComponents(string: "https://maps.apple.com/")
        var query: [URLQueryItem] = []
        if lat != 0 || lng != 0 {
            query.append(URLQueryItem(name: "ll", value: "\(lat),\(lng)"))
        }
        if !address.isEmpty {
            query.append(URLQueryItem(name: "q", value: address))
        }
        comps?.queryItems = query.isEmpty ? nil : query
        guard let url = comps?.url else { return }
        UIApplication.shared.open(url)
    }

    private var userCard: some View {
        let uid = Int64(cInt("uid"))
        let nickname = firstNonEmpty(cStr("nickname"), "用户")
        let vip = cInt("vip_level")
        let vipExpire = Int64(cInt("vip_expire"))
        let now = Int64(Date().timeIntervalSince1970)
        let vipShown = vipExpire > now ? vip : 0
        let prettyNo = cStr("pretty_yxid")
        let isPretty = prettyNo.isEmpty ? 0 : 1
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                AvatarView(url: cStr("avatar"), name: nickname, size: 42)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(nickname)
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundColor(isPretty == 1 ? AKColor.red : AKColor.text)
                            .lineLimit(1)
                        if isPretty == 1 { PrettyBadge(number: prettyNo) }
                        if vipShown > 0 { VipBadge(level: vipShown) }
                    }
                    Text("AK号：\(cStr("yx_id"))")
                        .font(.system(size: 11))
                        .foregroundColor(AKColor.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            Rectangle().fill(AKColor.line).frame(height: 0.5).padding(.top, 10)
            HStack(spacing: 0) {
                Text("推荐好友").font(.system(size: 10.5)).foregroundColor(AKColor.muted)
                Spacer(minLength: 0)
                Text("查看 ›").font(.system(size: 10.5)).foregroundColor(AKColor.muted)
            }
            .padding(.top, 7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(width: 232, alignment: .leading)
        .background(AKColor.card)
        .contentShape(Rectangle())
        .onTapGesture { if uid > 0 { onOpenProfile(uid) } }
    }

    private var groupCard: some View {
        let gid = Int64(cInt("gid"))
        let name = firstNonEmpty(cStr("name"), "群聊")
        let count = cInt("member_count")
        let prettyNo = cStr("pretty_no")
        let isPretty = cInt("is_pretty") == 1
        let groupNo = (isPretty && !prettyNo.isEmpty) ? prettyNo : cStr("group_no")
        let intro = cStr("intro").trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                AvatarView(url: cStr("avatar"), name: name, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(name)
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundColor(isPretty ? AKColor.gold : AKColor.text)
                            .lineLimit(1)
                        if isPretty && !prettyNo.isEmpty { PrettyBadge(number: prettyNo, isGroup: true) }
                    }
                    Text("群号 \(groupNo)" + (count > 0 ? " · \(count) 人" : ""))
                        .font(.system(size: 11))
                        .foregroundColor(isPretty ? AKColor.gold : AKColor.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            if !intro.isEmpty {
                Text(intro)
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.sub)
                    .lineLimit(2)
                    .lineSpacing(2)
                    .padding(.top, 9)
            }
            Rectangle().fill(AKColor.line).frame(height: 0.5).padding(.top, 10)
            HStack(spacing: 0) {
                Text("群邀请").font(.system(size: 10.5)).foregroundColor(AKColor.muted)
                Spacer(minLength: 0)
                Text(gid > 0 ? "查看 ›" : "群名片已失效")
                    .font(.system(size: 10.5))
                    .foregroundColor(AKColor.muted)
            }
            .padding(.top, 7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(width: 242, alignment: .leading)
        .background(AKColor.card)
        .contentShape(Rectangle())
        .onTapGesture { if gid > 0 { onOpenGroup(gid) } }
    }

    /// 直播分享卡片（type=19）：gid/name/avatar/title/live_id，点击进直播间
    private var liveCard: some View {
        let name = firstNonEmpty(cStr("name"), "群直播")
        let title = firstNonEmpty(cStr("title"), name)
        let gid = Int64(cInt("gid"))
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                AvatarView(url: cStr("avatar"), name: name, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundColor(AKColor.text)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Text("LIVE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(AKColor.red)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        Text("群直播").font(.system(size: 11)).foregroundColor(AKColor.muted)
                    }
                }
                Spacer(minLength: 0)
            }
            Rectangle().fill(AKColor.line).frame(height: 0.5).padding(.top, 10)
            HStack(spacing: 0) {
                Text("AK商聊直播").font(.system(size: 10.5)).foregroundColor(AKColor.muted)
                Spacer(minLength: 0)
                Text("进入直播间 ›").font(.system(size: 10.5)).foregroundColor(AKColor.muted)
            }
            .padding(.top, 7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(width: 242, alignment: .leading)
        .background(AKColor.card)
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
                Text(video ? "📹" : "📞").font(.system(size: 16))
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
        let ratio: CGFloat = {
            let parts = (message.content ?? "").components(separatedBy: "|#|")
            let json = parts.count > 1 ? parts.dropFirst().joined(separator: "|#|") : ""
            if let o = MessageBody.jsonObject(json) {
                let w = (o["w"] as? NSNumber)?.doubleValue ?? 0
                let h = (o["h"] as? NSNumber)?.doubleValue ?? 0
                if w > 0, h > 0 { return CGFloat(min(max(w / h, 0.4), 2.4)) }
            }
            return 3.0 / 4.0
        }()
        let boxW: CGFloat = ratio >= 1 ? 210 : 300 * ratio
        let boxH: CGFloat = ratio >= 1 ? 210 / ratio : 300
        return ZStack(alignment: .topLeading) {
            if let url = APIClient.fullURL(cover.isEmpty ? nil : cover) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color(hex: 0x202329)
                    }
                }
            } else {
                Color(hex: 0x202329)
            }
            if duration > 0 {
                Text(String(format: "%02d:%02d", duration / 60, duration % 60))
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Color.black.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .padding(6)
            }
            HStack {
                Spacer(minLength: 0)
                Image(systemName: "speaker.slash.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .padding(2)
                    .background(Color.black.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(6)
            }
        }
        .frame(width: boxW, height: boxH)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { onOpenMedia(message.text ?? message.content ?? "", true) }
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
        .onTapGesture {
            let raw = (message.content?.isEmpty == false ? message.content : message.text) ?? ""
            onOpenRecord(raw)
        }
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

    static func shortDateTime(_ ts: Int64) -> String {
        guard ts > 0 else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
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

private enum CardMetrics {
    static let width: CGFloat = 236
    static let radius: CGFloat = 12
    static let padding: CGFloat = 11
}

private extension View {
    /// 卡片统一外观：白底、圆角 12、内边距 11、宽 236，卡片下留 2
    func akCardSurface() -> some View {
        padding(CardMetrics.padding)
            .frame(width: CardMetrics.width, alignment: .leading)
            .background(AKColor.card)
            .clipShape(RoundedRectangle(cornerRadius: CardMetrics.radius, style: .continuous))
            .padding(.bottom, 2)
    }
}

/* ---------------- 文本链接 / @提醒 ---------------- */

/// 对齐安卓 LinkifiedText：URL 与 @名字 蓝色可点，数字串只在传入 onNumberTap 时识别
struct AKLinkText: View {
    let text: String
    var color: Color = AKColor.text
    var fontSize: CGFloat = 14.5
    var lineHeight: CGFloat = 20
    var mentionMap: [String: Int64] = [:]
    var onMention: (Int64) -> Void = { _ in }
    var onNumberTap: ((String) -> Void)? = nil

    private enum HitKind {
        case url(URL)
        case mention(Int64)
        case number(String)
    }

    private struct Hit {
        let range: NSRange
        let kind: HitKind
    }

    private var hits: [Hit] {
        let ns = text as NSString
        guard ns.length > 0 else { return [] }
        var out: [Hit] = []
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            detector.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) { match, _, _ in
                guard let match, let found = match.url else { return }
                var url = found
                if url.scheme == nil, let fixed = URL(string: "http://" + ns.substring(with: match.range)) {
                    url = fixed
                }
                out.append(Hit(range: match.range, kind: .url(url)))
            }
        }
        if !mentionMap.isEmpty, let re = try? NSRegularExpression(pattern: "@([^\\s@，,。：:]{1,24})") {
            re.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) { match, _, _ in
                guard let match else { return }
                let name = ns.substring(with: match.range(at: 1))
                guard let uid = mentionMap[name] ?? mentionMap["*"] else { return }
                out.append(Hit(range: match.range, kind: .mention(uid)))
            }
        }
        if onNumberTap != nil, let re = try? NSRegularExpression(pattern: "(?<![0-9A-Za-z])[0-9]{5,}(?![0-9A-Za-z])") {
            re.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) { match, _, _ in
                guard let match else { return }
                out.append(Hit(range: match.range, kind: .number(ns.substring(with: match.range))))
            }
        }
        return out.sorted { $0.range.location < $1.range.location }
    }

    private var attributed: AttributedString {
        let ns = text as NSString
        var out = AttributedString()
        var cursor = 0
        for hit in hits {
            if hit.range.location < cursor { continue }
            if hit.range.location > cursor {
                var plain = AttributedString(ns.substring(with: NSRange(location: cursor, length: hit.range.location - cursor)))
                plain.foregroundColor = color
                out += plain
            }
            let raw = ns.substring(with: hit.range)
            var piece = AttributedString(raw)
            switch hit.kind {
            case .url(let url):
                piece.link = url
                piece.foregroundColor = AKColor.link
            case .mention(let uid):
                piece.foregroundColor = AKColor.link
                if uid > 0, let url = URL(string: "akmention://\(uid)") { piece.link = url }
            case .number(let no):
                piece.foregroundColor = AKColor.link
                if let url = URL(string: "aknumber://\(no)") { piece.link = url }
            }
            out += piece
            cursor = NSMaxRange(hit.range)
        }
        if cursor < ns.length {
            var tail = AttributedString(ns.substring(from: cursor))
            tail.foregroundColor = color
            out += tail
        }
        return out
    }

    var body: some View {
        Text(attributed)
            .font(.system(size: fontSize))
            .lineSpacing(max(0, lineHeight - fontSize * 1.2))
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "akmention" {
                    if let uid = Int64(url.host ?? "") { onMention(uid) }
                    return .handled
                }
                if url.scheme == "aknumber" {
                    if let no = url.host { onNumberTap?(no) }
                    return .handled
                }
                AppLinkRouter.open(url)
                return .handled
            })
    }
}

/* ---------------- 视频表情 ---------------- */

/// 96dp 循环静音播放，无控制条（对齐安卓 StickerVideo）
struct LoopingVideo: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> LoopingVideoView {
        let view = LoopingVideoView()
        view.load(url)
        return view
    }

    func updateUIView(_ uiView: LoopingVideoView, context: Context) {}
}

final class LoopingVideoView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    override init(frame: CGRect) {
        super.init(frame: frame)
        /* 纯展示视图：不能吞掉气泡的点击（表情点开预览）与长按菜单 */
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = false
    }

    func load(_ url: URL) {
        let p = AVQueuePlayer()
        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: p, templateItem: item)
        p.isMuted = true
        p.play()
        if let layer = layer as? AVPlayerLayer {
            layer.player = p
            layer.videoGravity = .resizeAspect
        }
        player = p
    }

    deinit {
        player?.pause()
    }
}

/* ---------------- 充值申请详情 ---------------- */

/// 充值申请卡（type 2/3/20）点击后的详情页：对齐安卓 RechargeCard 的详情弹层，
/// 客服账号可直接同意/拒绝（POST /api/v1/recharge/handle，rid + pass + reason）。
struct RechargeDetailSheet: View {
    let message: Message
    var myId: Int64 = 0
    var onHandled: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    @State private var tip: String?
    @State private var showReject = false
    @State private var rejectReason = ""
    /// 本页处理成功后立即反映最新状态（服务端卡片要等下一次刷新才更新）
    @State private var handledStatus: Int?

    private var raw: [String: Any] {
        MessageBody.jsonObject(message.content)
            ?? MessageBody.jsonObject(message.text)
            ?? [:]
    }

    /* 服务端给 type 20 补过 extra（rid/amount/status/reject_reason），优先级高于正文 */
    private var ex: [String: JSONValue] { message.extraMap }

    private func rawInt(_ key: String) -> Int {
        if let n = ex[key]?.intValue { return n }
        if let n = raw[key] as? NSNumber { return n.intValue }
        if let s = raw[key] as? String { return Int(s.trimmingCharacters(in: .whitespaces)) ?? 0 }
        return 0
    }

    private func rawStr(_ key: String) -> String {
        if let s = ex[key]?.stringValue, !s.isEmpty, s != "null" { return s }
        if let s = raw[key] as? String { return s == "null" ? "" : s }
        if let n = raw[key] as? NSNumber { return n.stringValue }
        return ""
    }

    private var rid: Int64 { Int64(rawInt("rid")) }
    private var amount: Int { rawInt("amount") }
    private var status: Int { handledStatus ?? rawInt("status") }
    private var rejectReasonText: String { rawStr("reject_reason") }
    private var remark: String {
        let r = rawStr("remark")
        if !r.isEmpty { return r }
        /* 网页端旧版 type=2 的正文就是备注 */
        if message.type == 2, MessageBody.jsonObject(message.text) == nil {
            return (message.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }
    private var mine: Bool { myId > 0 && message.fromUid == myId }
    private var canHandle: Bool { !mine && status == 0 && rid > 0 }

    private var statusText: String {
        switch status {
        case 1: return "已完成"
        case 2: return "已取消"
        default: return "待处理"
        }
    }

    private var statusColor: Color {
        switch status {
        case 1: return Color(hex: 0x0FB67A)
        case 2: return AKColor.sub
        default: return Color(hex: 0xE68600)
        }
    }

    private var statusBg: Color {
        switch status {
        case 1: return AKColor.brandSoft
        case 2: return AKColor.fill
        default: return AKColor.goldSoft
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(AKColor.brandSoft)
                                .frame(width: 28, height: 28)
                            Text("¥")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(hex: 0x0FB67A))
                        }
                        Text(message.type == 3 ? "提现申请" : "充值申请")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AKColor.text)
                        Spacer(minLength: 0)
                        Text(statusText)
                            .font(.system(size: 10.5))
                            .foregroundColor(statusColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(statusBg)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(amount)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AKColor.text)
                        Text("K币")
                            .font(.system(size: 12))
                            .foregroundColor(AKColor.sub)
                            .padding(.bottom, 3)
                    }
                    .padding(.top, 12)

                    divider.padding(.top, 12)
                    infoRow("备注", remark.isEmpty ? "无" : remark)
                    infoRow("提交时间", MessageBody.shortDateTime(message.createdAt))
                    if status == 2 && !rejectReasonText.isEmpty {
                        infoRow("拒绝理由", rejectReasonText, color: AKColor.red)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AKColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if canHandle {
                    HStack(spacing: 10) {
                        Button {
                            rejectReason = ""
                            showReject = true
                        } label: {
                            Text("拒绝")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AKColor.red)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(AKColor.redSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(busy)

                        Button {
                            Task { await handle(pass: true, reason: "") }
                        } label: {
                            Text(busy ? "处理中…" : "同意")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color(hex: 0x0FB67A))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(busy)
                    }
                    .padding(.top, 4)

                    Text("同意后立即为对方到账 \(amount) K币")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.hint)
                }

                if let tip {
                    Text(tip)
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.sub)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .navigationTitle("充值申请详情")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
        .alert("拒绝原因", isPresented: $showReject) {
            TextField("选填，最多 50 字", text: $rejectReason)
            Button("取消", role: .cancel) {}
            Button("确认拒绝", role: .destructive) {
                Task { await handle(pass: false, reason: rejectReason) }
            }
        } message: {
            Text("填写原因会同步给对方。")
        }
    }

    private var divider: some View {
        Rectangle().fill(AKColor.fill).frame(height: 0.6)
    }

    private func infoRow(_ title: String, _ value: String, color: Color = AKColor.sub) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.system(size: 12.5))
                .foregroundColor(AKColor.muted)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.system(size: 12.5))
                .foregroundColor(color)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 10)
    }

    private func handle(pass: Bool, reason: String) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let msg = try await APIClient.shared.postRaw("api/v1/recharge/handle", body: [
                "rid": rid,
                "pass": pass ? 1 : 0,
                "reason": String(reason.prefix(50)),
            ])
            tip = msg.isEmpty ? (pass ? "已确认到账" : "已拒绝") : msg
            handledStatus = pass ? 1 : 2
            onHandled()
        } catch {
            tip = error.localizedDescription
        }
    }
}
