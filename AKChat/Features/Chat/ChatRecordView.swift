import SwiftUI
import UIKit

/// 聊天记录卡片展开页：标题/副标题 + 按天分组 + 头像/昵称/时间/正文（对齐安卓 ChatRecordScreen）
struct ChatRecordView: View {
    let payload: String

    @Environment(\.dismiss) private var dismiss
    @State private var toast: String?
    @State private var toastToken = 0
    @State private var preview: PreviewImage?

    private struct RecordItem: Identifiable {
        let id = UUID()
        let name: String
        let avatar: String
        let content: String
        let time: Int64
        let type: Int
        let image: String
    }

    private struct ChatRecord {
        let title: String
        let sub: String
        let items: [RecordItem]
    }

    private var record: ChatRecord {
        guard let o = MessageBody.jsonObject(payload) else {
            return ChatRecord(title: "聊天记录", sub: "", items: [])
        }
        let title = (o["title"] as? String) ?? "聊天记录"
        let sub = (o["sub"] as? String) ?? ""
        var list: [RecordItem] = []
        if let arr = o["items"] as? [Any] {
            for raw in arr {
                guard let m = raw as? [String: Any] else { continue }
                list.append(RecordItem(
                    name: (m["u"] as? String) ?? "",
                    avatar: (m["a"] as? String) ?? "",
                    content: (m["c"] as? String) ?? "",
                    time: (m["t"] as? NSNumber)?.int64Value ?? 0,
                    type: (m["ty"] as? NSNumber)?.intValue ?? 1,
                    image: (m["p"] as? String) ?? ""
                ))
            }
        }
        return ChatRecord(title: title, sub: sub, items: list)
    }

    var body: some View {
        let data = record
        VStack(spacing: 0) {
            header(data)
            if data.items.isEmpty {
                Text("没有内容")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.hint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AKColor.bg)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(data.items.enumerated()), id: \.element.id) { index, item in
                            if index == 0 || !sameDay(data.items[index - 1].time, item.time) {
                                Text(dayText(item.time))
                                    .font(.system(size: 11))
                                    .foregroundColor(AKColor.hint)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(AKColor.fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            row(item)
                        }
                    }
                }
                .background(AKColor.card)
            }
        }
        .background(AKColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $preview) { item in
            MediaPagerView(items: item.items, index: item.index)
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .padding(.bottom, 40)
            }
        }
    }

    private func header(_ data: ChatRecord) -> some View {
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
                Text(data.title.isEmpty ? "聊天记录" : data.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AKColor.text)
                    .lineLimit(1)
                if !data.sub.isEmpty {
                    Text(data.sub)
                        .font(.system(size: 10.5))
                        .foregroundColor(AKColor.hint)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            Spacer().frame(width: 44)
        }
        .padding(.vertical, 4)
        .background(AKColor.card)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AKColor.line).frame(height: 0.5)
        }
    }

    private func row(_ item: RecordItem) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 9) {
                AvatarView(url: item.avatar.isEmpty ? nil : item.avatar,
                           name: item.name.isEmpty ? "成员" : item.name,
                           size: 34)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        Text(item.name.isEmpty ? "成员" : item.name)
                            .font(.system(size: 12))
                            .foregroundColor(AKColor.sub)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(clock(item.time))
                            .font(.system(size: 10))
                            .foregroundColor(AKColor.hint)
                    }
                    if item.type == 5 && !item.image.isEmpty {
                        imageRow(item.image)
                    } else {
                        AKLinkText(text: item.content, color: AKColor.text, fontSize: 14, lineHeight: 20,
                                   onNumberTap: { no in
                                       UIPasteboard.general.string = no
                                       showToast("号码已复制")
                                   })
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            Rectangle().fill(AKColor.line).frame(height: 0.5).padding(.leading, 57)
        }
    }

    private func imageRow(_ path: String) -> some View {
        Group {
            if let url = APIClient.fullURL(path) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        AKColor.fill
                    }
                }
                .frame(width: 120)
                .frame(maxHeight: 160)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture {
                    preview = PreviewImage(items: [PreviewMedia(url: url, isVideo: false, message: nil)], index: 0)
                }
            }
        }
    }

    private func showToast(_ text: String) {
        toast = text
        toastToken += 1
        let token = toastToken
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            await MainActor.run {
                if token == toastToken { toast = nil }
            }
        }
    }

    private func sameDay(_ a: Int64, _ b: Int64) -> Bool {
        guard a > 0, b > 0 else { return false }
        return (a + 8 * 3600) / 86400 == (b + 8 * 3600) / 86400
    }

    private func dayText(_ ts: Int64) -> String {
        guard ts > 0 else { return "" }
        let f = formatter("M月d日")
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }

    private func clock(_ ts: Int64) -> String {
        guard ts > 0 else { return "" }
        return formatter("HH:mm:ss").string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }

    private func formatter(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)
        f.dateFormat = pattern
        return f
    }
}
