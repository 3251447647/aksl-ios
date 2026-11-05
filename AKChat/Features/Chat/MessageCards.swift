import SwiftUI

/// 聊天消息正文：按服务端 type 渲染文本、图片、语音与全部卡片。
/// 卡片结构以 api_v1.php / im_push.php 的 extra 字段为准，与网页端保持同一口径。
struct MessageBody: View {
    let message: Message
    let mine: Bool
    var myName: String = "我"
    var playingVoice: Bool = false
    var onVoiceTap: () -> Void = {}
    /// 直播分享卡片点击：带入群 gid，由 ChatView 打开直播间
    var onOpenLive: (Int64) -> Void = { _ in }

    private var ex: [String: JSONValue] { message.extraMap }
    private var rawText: String { message.text ?? message.content ?? "" }

    private var recipientName: String {
        let n = ex.str("to_name")
        return n.isEmpty ? "对方" : n
    }

    var body: some View {
        switch message.type {
        case 11:
            systemRow
        case 2, 3, 20:
            noticeCard(title: "充值申请", detail: rawText, icon: "creditcard.fill",
                       tint: Color(hex: 0xB07A18), bg: Color(hex: 0xFFF7E6))
        case 7, 21:
            redPacket
        case 8, 22:
            transfer
        case 9, 23:
            gift
        case 10:
            locationCard
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
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    private var voiceSeconds: Int {
        let d = ex.int("duration")
        if d > 0 { return d }
        let raw = message.content ?? ""
        guard let range = raw.range(of: "\"duration\":") else { return 0 }
        let tail = raw[range.upperBound...]
        return Int(tail.prefix { $0.isNumber }) ?? 0
    }

    private var voiceBubble: some View {
        Button(action: onVoiceTap) {
            HStack(spacing: 6) {
                Image(systemName: playingVoice ? "waveform.circle.fill" : "waveform")
                Text("语音")
                if voiceSeconds > 0 {
                    Text(" \(voiceSeconds)\"")
                        .font(.system(size: 11))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(mine ? AKColor.bubbleSelf : AKColor.bubbleOther)
            .foregroundColor(mine ? .white : AKColor.text)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
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

    private var redPacket: some View {
        let done = ex.int("status") != 0
        let remark = ex.str("msg").isEmpty ? "恭喜发财，大吉大利~" : ex.str("msg")
        let title = mine ? "我发的红包" : "发了一个红包"
        return cardShell(
            top: Color(hex: 0xF0563C), bottom: Color(hex: 0xD93B27),
            title: title,
            subtitle: remark,
            foot: done ? "已领取" : "点击查看红包",
            icon: "yensign.circle.fill",
            iconColor: Color(hex: 0xFFE2B0)
        )
    }

    private var transfer: some View {
        let done = ex.int("status") != 0
        let title = mine ? "转账给 \(recipientName)" : "转账给你"
        let amount = ex.dbl("amount")
        let sub = amount > 0 ? String(format: "%.2f K币", amount) : ex.str("msg")
        let foot = done ? "已被领取" : (mine ? "等待对方领取" : "点击领取")
        return cardShell(
            top: Color(hex: 0xF5A54A), bottom: Color(hex: 0xE8882A),
            title: title,
            subtitle: sub.isEmpty ? "转账" : sub,
            foot: foot,
            icon: "arrow.left.arrow.right.circle.fill",
            iconColor: Color.white
        )
    }

    private var gift: some View {
        let done = ex.int("status") != 0
        let title = mine ? "送给 \(recipientName) 的礼物" : "送给你的礼物"
        let name = ex.str("gift_name").isEmpty ? "拆开礼物，惊喜等你哦~" : ex.str("gift_name")
        let foot = done ? "已领取" : (mine ? "等待对方领取" : "点击领取")
        let isVipGift = ex.str("gift_type") == "vip"
        let icon = isVipGift ? (ex.int("level") == 2 ? "crown.fill" : "diamond.fill") : "gift.fill"
        return cardShell(
            top: Color(hex: 0x6C4BD1), bottom: Color(hex: 0x452C9C),
            title: title,
            subtitle: name,
            foot: foot,
            icon: icon,
            iconColor: Color(hex: 0xFFE8A8)
        )
    }

    private func cardShell(top: Color, bottom: Color, title: String, subtitle: String,
                           foot: String, icon: String, iconColor: Color) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundColor(iconColor)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(2)
                if !foot.isEmpty {
                    Text(foot)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.75))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 236, alignment: .leading)
        .background(LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var locationCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 20)).foregroundColor(AKColor.brand)
            VStack(alignment: .leading, spacing: 3) {
                Text(rawText.isEmpty ? "位置" : rawText)
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
        let nickname = ex.str("nickname").isEmpty ? "用户" : ex.str("nickname")
        let number = ex.str("pretty_yxid").isEmpty ? ex.str("yx_id") : ex.str("pretty_yxid")
        let vip = ex.int("vip_level")
        return HStack(spacing: 10) {
            AvatarView(url: ex.str("avatar"), name: nickname, size: 38)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(nickname).font(.system(size: 13, weight: .semibold))
                        .foregroundColor(akNameColor(vipLevel: vip, isPretty: ex.str("pretty_yxid").isEmpty ? 0 : 1, isGroup: false))
                        .lineLimit(1)
                    if vip > 0 { VipBadge(level: vip) }
                }
                Text("AK号：\(number)").font(.system(size: 11)).foregroundColor(AKColor.muted)
            }
            Spacer(minLength: 0)
            Text("名片").font(.system(size: 11)).foregroundColor(AKColor.hint)
        }
        .padding(11)
        .frame(width: 236, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var groupCard: some View {
        let name = ex.str("name").isEmpty ? "群聊" : ex.str("name")
        let count = ex.int("member_count")
        let pretty = ex.int("is_pretty") == 1
        return HStack(spacing: 10) {
            AvatarView(url: ex.str("avatar"), name: name, size: 38)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(name).font(.system(size: 13, weight: .semibold))
                        .foregroundColor(pretty ? AKColor.gold : AKColor.text)
                        .lineLimit(1)
                    if pretty { PrettyBadge(number: "", isGroup: true) }
                }
                Text(count > 0 ? "\(count) 人" : "群聊")
                    .font(.system(size: 11)).foregroundColor(AKColor.muted)
            }
            Spacer(minLength: 0)
            Text("群名片").font(.system(size: 11)).foregroundColor(AKColor.hint)
        }
        .padding(11)
        .frame(width: 236, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// 直播分享卡片（type=19）：gid/name/avatar/title/live_id，点击进直播间
    private var liveCard: some View {
        let name = ex.str("name").isEmpty ? "群直播" : ex.str("name")
        let title = ex.str("title").isEmpty ? name : ex.str("title")
        let gid = Int64(ex.int("gid"))
        return HStack(spacing: 10) {
            AvatarView(url: ex.str("avatar"), name: name, size: 38)
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
        let video = ex.int("call_type") == 2
        let group = ex.int("group") == 1
        let status = ex.int("status")
        let duration = ex.int("duration")
        let base = (group ? "群" : "") + (video ? "视频通话" : "语音通话")
        var tail = ""
        if status == 2 {
            tail = String(format: "%02d:%02d", duration / 60, duration % 60)
        } else if status == 3 {
            tail = "已拒绝"
        } else if status == 4 {
            tail = "未接听"
        } else if status == 5 {
            tail = "已取消"
        } else if status == 6 {
            tail = "已中断"
        }
        return HStack(spacing: 10) {
            Image(systemName: video ? "video.fill" : "phone.fill")
                .font(.system(size: 15))
                .foregroundColor(AKColor.brand)
                .frame(width: 30, height: 30)
                .background(AKColor.brandSoft)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(base + " " + (tail.isEmpty ? "通话结束" : tail))
                    .font(.system(size: 13, weight: .medium)).foregroundColor(AKColor.text)
                Text("通话记录").font(.system(size: 11)).foregroundColor(AKColor.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(width: 236, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var videoBubble: some View {
        let cover = ex.str("cover")
        let duration = ex.int("duration")
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
    }

    private var momentCard: some View {
        let name = ex.str("name").isEmpty ? "用户" : ex.str("name")
        let text = ex.str("text")
        var imageList: [String] = []
        if case .array(let arr)? = ex["imgs"] {
            for item in arr {
                if let s = item.stringValue, !s.isEmpty { imageList.append(s) }
            }
        }
        return VStack(alignment: .leading, spacing: 8) {
            Text(text.isEmpty ? "分享了一条动态" : text)
                .font(.system(size: 13)).foregroundColor(AKColor.text)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !imageList.isEmpty {
                HStack(spacing: 4) {
                    ForEach(imageList.prefix(3), id: \.self) { path in
                        AsyncImage(url: APIClient.fullURL(path)) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                AKColor.fill
                            }
                        }
                        .frame(width: 66, height: 66)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    Spacer(minLength: 0)
                }
            }
            HStack(spacing: 4) {
                Image(systemName: "safari").font(.system(size: 10)).foregroundColor(AKColor.muted)
                Text("\(name) 的动态").font(.system(size: 11)).foregroundColor(AKColor.muted)
            }
        }
        .padding(11)
        .frame(width: 236, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var chatRecordCard: some View {
        let parsed = Self.jsonObject(message.content)
        let title = (parsed?["title"] as? String) ?? "聊天记录"
        let count = (parsed?["items"] as? [Any])?.count ?? 0
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold)).foregroundColor(AKColor.text)
                .lineLimit(2)
            HStack(spacing: 4) {
                Image(systemName: "list.bullet.rectangle").font(.system(size: 10)).foregroundColor(AKColor.muted)
                Text(count > 0 ? "\(count) 条聊天记录" : "聊天记录")
                    .font(.system(size: 11)).foregroundColor(AKColor.muted)
            }
        }
        .padding(11)
        .frame(width: 236, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var fileCard: some View {
        let name = ex.str("name").isEmpty ? "文件" : ex.str("name")
        let size = ex.int("size")
        return HStack(spacing: 10) {
            Image(systemName: "doc.fill")
                .font(.system(size: 22))
                .foregroundColor(AKColor.link)
                .frame(width: 34, height: 38)
                .background(AKColor.blueSoft)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.system(size: 13, weight: .medium))
                    .foregroundColor(AKColor.text).lineLimit(2)
                Text(Self.sizeText(size)).font(.system(size: 11)).foregroundColor(AKColor.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(width: 236, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    static func jsonObject(_ raw: String?) -> [String: Any]? {
        guard let raw, let data = raw.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    static func sizeText(_ bytes: Int) -> String {
        if bytes <= 0 { return "文件" }
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / 1024 / 1024)
    }
}
