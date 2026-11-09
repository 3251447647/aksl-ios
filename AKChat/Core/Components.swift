import SwiftUI
import UIKit

/// 统一网络图片视图：内存 NSCache + 磁盘 URLCache + 按目标尺寸降采样，下载最多 4 并发。
/// `size` 只用于决定解码像素，不参与布局；布局仍由调用方的 frame 决定。
struct AKImage: View {
    let url: String?
    let size: CGSize
    var contentMode: ContentMode = .fill
    var placeholder: Color = AKColor.fill

    @StateObject private var model = AKImageModel()

    init(url: String?, size: CGSize, contentMode: ContentMode = .fill, placeholder: Color = AKColor.fill) {
        self.url = url
        self.size = size
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    init(url: String?, size: CGFloat, contentMode: ContentMode = .fill, placeholder: Color = AKColor.fill) {
        self.init(url: url, size: CGSize(width: size, height: size),
                  contentMode: contentMode, placeholder: placeholder)
    }

    private var request: AKImageRequest? {
        guard let resolved = APIClient.fullURL(url) else { return nil }
        return AKImageRequest(url: resolved, size: size)
    }

    /// 先看本次加载结果，再同步查内存缓存：命中时第一帧就不闪占位
    private var image: UIImage? {
        guard let request else { return nil }
        if let loaded = model.loaded, loaded.key == request.key { return loaded.image }
        return AKImageLoader.shared.cachedImage(for: request)
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder
            }
        }
        .task(id: request?.key) {
            guard let request else { return }
            await model.load(request)
        }
    }
}

struct AvatarView: View {
    let url: String?
    let name: String
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            fallback
            if APIClient.fullURL(url) != nil {
                /* 占位透出底下的首字色块；图片加载完成后覆盖它，不会先白一下 */
                AKImage(url: url, size: size, contentMode: .fill, placeholder: .clear)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(colors: [AKColor.brand, AKColor.brandDark], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(String(name.prefix(1)))
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

struct BadgeView: View {
    let text: String
    var color: Color = AKColor.gold
    var background: Color = AKColor.goldSoft

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(background)
            .clipShape(Capsule())
    }
}

/* 徽章与安卓 LuxPill 同款：深色玻璃底 + 金属描边 + 细高光，不用位图 */
private struct LuxPill: View {
    let title: String
    var number: String = ""
    let accent: Color
    let border: Color
    let top: Color
    let bottom: Color
    var icon: String
    var height: CGFloat = 15
    var corner: CGFloat = 7
    var titleSize: CGFloat = 8.5

    var body: some View {
        HStack(spacing: 2.5) {
            Image(systemName: icon)
                .font(.system(size: height * 0.52, weight: .semibold))
                .foregroundColor(accent)
            Text(title)
                .font(.system(size: titleSize, weight: .bold))
                .tracking(0.5)
                .foregroundColor(accent)
            if !number.isEmpty {
                Text(number)
                    .font(.system(size: titleSize, weight: .bold))
                    .tracking(0.2)
                    .foregroundColor(accent)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: height)
        .background(
            LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [border.opacity(0.95), border.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(colors: [Color.white.opacity(0.16), Color.clear], startPoint: .top, endPoint: .center)
                )
                .allowsHitTesting(false)
        )
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

/// 会员：VIP 紫金玻璃，SVIP 黑金玻璃（与安卓 VipBadge 一致）
struct VipBadge: View {
    let level: Int
    var body: some View {
        if level == 2 {
            LuxPill(title: "SVIP", accent: Color(hex: 0xF3D27C), border: Color(hex: 0xD4AF37),
                    top: Color(hex: 0x2B2418), bottom: Color(hex: 0x0D0B08),
                    icon: "crown.fill", height: 16, corner: 7, titleSize: 9)
        } else if level == 1 {
            LuxPill(title: "VIP", accent: Color(hex: 0xE9E2FF), border: Color(hex: 0x9B8CFF),
                    top: Color(hex: 0x332A7A), bottom: Color(hex: 0x19154A),
                    icon: "shield.fill", height: 15, corner: 7, titleSize: 8.5)
        }
    }
}

/// 靓号：个人红金圆章带号码，群靓黑金方章不带号码（与安卓 PrettyBadge 一致）
struct PrettyBadge: View {
    let number: String
    var isGroup: Bool = false
    var body: some View {
        if isGroup {
            LuxPill(title: "群靓", accent: Color(hex: 0xF0CE7A), border: Color(hex: 0xC9A44C),
                    top: Color(hex: 0x26211A), bottom: Color(hex: 0x12100D),
                    icon: "crown.fill", height: 15, corner: 5, titleSize: 9)
        } else if !number.isEmpty {
            LuxPill(title: "靓", number: number, accent: Color(hex: 0xFFE0A6), border: Color(hex: 0xD9A441),
                    top: Color(hex: 0x8F1D2C), bottom: Color(hex: 0x5E101B),
                    icon: "diamond.fill", height: 15, corner: 7, titleSize: 9)
        }
    }
}

/// 群内身份：1 群主红胶囊，2 管理员蓝胶囊
struct RoleBadge: View {
    let role: Int
    var body: some View {
        if role == 1 || role == 2 {
            Text(role == 1 ? "群主" : "管理员")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(role == 1 ? Color(hex: 0xE5484D) : Color(hex: 0x3B6BFF))
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(role == 1 ? Color(hex: 0xFFE9E9) : Color(hex: 0xE8F0FF))
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        }
    }
}

/// 名字颜色：靓号红/群靓金，SVIP 金，VIP 蓝
func akNameColor(vipLevel: Int, isPretty: Int, isGroup: Bool) -> Color {
    if isPretty == 1 { return isGroup ? AKColor.gold : AKColor.red }
    if vipLevel == 2 { return Color(hex: 0xD79A19) }
    if vipLevel == 1 { return AKColor.link }
    return AKColor.text
}

enum TimeText {
    /// 全站统一北京时间，不跟随设备时区
    private static let tz = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)!

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = tz
        f.dateFormat = format
        return f
    }

    private static func date(_ ts: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(ts))
    }

    static func short(_ ts: Int64) -> String {
        guard ts > 0 else { return "" }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let d = date(ts)
        if cal.isDateInToday(d) { return formatter("HH:mm").string(from: d) }
        if cal.isDateInYesterday(d) { return "昨天" }
        if cal.component(.year, from: d) == cal.component(.year, from: Date()) {
            return formatter("MM-dd").string(from: d)
        }
        return formatter("yyyy-MM-dd").string(from: d)
    }

    /// 会话列表时间：今天 HH:mm / 昨天 HH:mm / 今年 MM-dd / 更早 yyyy-MM-dd
    static func listTime(_ ts: Int64) -> String {
        guard ts > 0 else { return "" }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let d = date(ts)
        if cal.isDateInToday(d) { return formatter("HH:mm").string(from: d) }
        if cal.isDateInYesterday(d) { return "昨天 " + formatter("HH:mm").string(from: d) }
        if cal.component(.year, from: d) == cal.component(.year, from: Date()) {
            return formatter("MM-dd").string(from: d)
        }
        return formatter("yyyy-MM-dd").string(from: d)
    }

    /// 聊天内时间分隔：与上一条相差 5 分钟以上或跨天时显示
    static func divider(previous: Int64, current: Int64) -> String? {
        guard current > 0 else { return nil }
        if previous <= 0 { return full(current) }
        if current - previous < 300 { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let cur = date(current)
        let prev = date(previous)
        if !cal.isDate(cur, inSameDayAs: prev) {
            if cal.isDateInToday(cur) { return "今天 " + formatter("HH:mm").string(from: cur) }
            if cal.isDateInYesterday(cur) { return "昨天 " + formatter("HH:mm").string(from: cur) }
            if cal.component(.year, from: cur) == cal.component(.year, from: Date()) {
                return formatter("MM-dd HH:mm").string(from: cur)
            }
            return formatter("yyyy-MM-dd HH:mm").string(from: cur)
        }
        return formatter("HH:mm").string(from: cur)
    }

    static func full(_ ts: Int64) -> String {
        guard ts > 0 else { return "" }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let d = date(ts)
        if cal.isDateInToday(d) { return "今天 " + formatter("HH:mm").string(from: d) }
        if cal.isDateInYesterday(d) { return "昨天 " + formatter("HH:mm").string(from: d) }
        if cal.component(.year, from: d) == cal.component(.year, from: Date()) {
            return formatter("MM-dd HH:mm").string(from: d)
        }
        return formatter("yyyy-MM-dd HH:mm").string(from: d)
    }
}
