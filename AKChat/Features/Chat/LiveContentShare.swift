import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation
import CoreImage
import LiveKit

/// 内容共享的素材来源
enum LiveContentSource {
    case photos([UIImage])
    case video(URL)
    case page(UIImage)
}

struct LiveContentSelection {
    let source: LiveContentSource
    let label: String
}

/// 把图片/视频/渲染好的页面按固定节奏画进 1280x720 画布，交给 BufferCapturer 推帧。
/// 不依赖录屏，只要主播保持 App 前台就能持续出帧。
@MainActor
final class LiveContentFeed: ObservableObject {
    @Published private(set) var isRunning = false

    private let canvas = CGSize(width: 1280, height: 720)
    private let canvasRect = CGRect(x: 0, y: 0, width: 1280, height: 720)
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private lazy var background = CIImage(color: CIColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1))
        .cropped(to: canvasRect)

    private var capturer: BufferCapturer?
    private var source: LiveContentSource?
    private var loop: Task<Void, Never>?
    private var renderedFirstFrame = false

    private var photoIndex = 0
    private var photosSince: TimeInterval = 0
    private var pageScroll: CGFloat = 0
    private var pageDirection: CGFloat = 1
    private var lastTick: TimeInterval = 0

    private var player: AVPlayer?
    private var playerOutput: AVPlayerItemVideoOutput?
    private var lastVideoImage: CIImage?

    func start(capturer: BufferCapturer, source: LiveContentSource) async -> Bool {
        reset()
        self.capturer = capturer
        self.source = source
        photoIndex = 0
        photosSince = 0
        pageScroll = 0
        pageDirection = 1
        lastTick = Date().timeIntervalSince1970
        renderedFirstFrame = false
        isRunning = true
        prepareVideoIfNeeded(source)

        renderFrame()
        // 视频第一帧要等解码：先抓到一帧再发布，否则 publish 会等维度超时
        for _ in 0 ..< 20 where !renderedFirstFrame {
            try? await Task.sleep(nanoseconds: 100_000_000)
            renderFrame()
        }
        guard renderedFirstFrame else {
            stop()
            return false
        }

        loop = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 83_000_000)
                guard let self, self.isRunning else { return }
                self.renderFrame()
            }
        }
        return true
    }

    func stop() {
        reset()
        removeTemporaryFiles()
    }

    private func reset() {
        isRunning = false
        loop?.cancel()
        loop = nil
        capturer = nil
        source = nil
        renderedFirstFrame = false
        destroyVideo()
    }

    private func renderFrame() {
        guard let capturer,
              let image = makeFrameImage(now: Date().timeIntervalSince1970),
              let pixelBuffer = makePixelBuffer() else { return }
        ciContext.render(image, to: pixelBuffer, bounds: canvasRect, colorSpace: CGColorSpaceCreateDeviceRGB())
        capturer.capture(pixelBuffer)
        renderedFirstFrame = true
    }

    private func makeFrameImage(now: TimeInterval) -> CIImage? {
        guard let source else { return nil }
        switch source {
        case .photos(let images):
            guard !images.isEmpty else { return nil }
            if photosSince == 0 { photosSince = now }
            if images.count > 1, now - photosSince >= 4 {
                photoIndex = (photoIndex + 1) % images.count
                photosSince = now
            }
            guard let ci = CIImage(image: images[min(photoIndex, images.count - 1)]) else { return nil }
            return fit(ci)
        case .video:
            return videoFrameImage()
        case .page(let image):
            return pageFrameImage(image, now: now)
        }
    }

    private func fit(_ image: CIImage) -> CIImage {
        let scale = min(canvas.width / image.extent.width, canvas.height / image.extent.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let dx = (canvas.width - scaled.extent.width) / 2 - scaled.extent.minX
        let dy = (canvas.height - scaled.extent.height) / 2 - scaled.extent.minY
        return scaled.transformed(by: CGAffineTransform(translationX: dx, y: dy))
            .composited(over: background)
    }

    private func pageFrameImage(_ image: UIImage, now: TimeInterval) -> CIImage? {
        guard let ci = CIImage(image: image) else { return nil }
        let scale = canvas.width / ci.extent.width
        let scaled = ci.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let pageHeight = scaled.extent.height
        if pageHeight <= canvas.height + 1 { return fit(ci) }
        let maxScroll = max(0, pageHeight - canvas.height)

        let dt = min(max(now - lastTick, 0), 0.5)
        lastTick = now
        pageScroll += CGFloat(dt) * 55 * pageDirection
        if pageScroll >= maxScroll {
            pageScroll = maxScroll
            pageDirection = -1
        } else if pageScroll <= 0 {
            pageScroll = 0
            pageDirection = 1
        }

        let cropY = max(0, pageHeight - canvas.height - pageScroll)
        let crop = CGRect(x: 0, y: cropY, width: canvas.width, height: canvas.height)
        return scaled.cropped(to: crop)
            .transformed(by: CGAffineTransform(translationX: 0, y: -cropY))
            .composited(over: background)
    }

    private func videoFrameImage() -> CIImage? {
        guard let player, let output = playerOutput else { return lastVideoImage.map(fit) }
        if let item = player.currentItem, item.duration.isNumeric {
            let duration = item.duration.seconds
            if duration > 0, player.currentTime().seconds >= duration - 0.1 {
                player.seek(to: .zero)
                player.play()
            }
        }
        let itemTime = output.itemTime(forHostTime: CACurrentMediaTime())
        if output.hasNewPixelBuffer(forItemTime: itemTime),
           let pixelBuffer = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) {
            lastVideoImage = CIImage(cvPixelBuffer: pixelBuffer)
        }
        guard let image = lastVideoImage else { return nil }
        return fit(image)
    }

    private func prepareVideoIfNeeded(_ source: LiveContentSource) {
        guard case .video(let url) = source else { return }
        let item = AVPlayerItem(url: url)
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
        ] as [String: Any])
        item.add(output)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .none
        self.player = player
        playerOutput = output
        player.play()
    }

    private func destroyVideo() {
        player?.pause()
        if let item = player?.currentItem, let output = playerOutput {
            item.remove(output)
        }
        player = nil
        playerOutput = nil
        lastVideoImage = nil
    }

    private func makePixelBuffer() -> CVPixelBuffer? {
        let attributes: [CFString: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ]
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(canvas.width),
                                         Int(canvas.height),
                                         kCVPixelFormatType_32BGRA,
                                         attributes as CFDictionary,
                                         &pixelBuffer)
        guard status == kCVReturnSuccess else { return nil }
        return pixelBuffer
    }

    /// 只清我们自己下载到临时目录的视频，不碰相册原文件
    private func removeTemporaryFiles() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ak-live-content", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

/// 群聊/朋友圈页面快照：用真实数据画成一张长图，共享时自动上下浏览
enum LivePageRenderer {
    static func groupChat(title: String, messages: [Message]) -> UIImage? {
        let entries = messages.map { message in
            PageEntry(name: message.fromName ?? "成员",
                      text: summary(of: message),
                      meta: timeText(message.createdAt))
        }
        return render(title: "群聊 · \(title)", subtitle: "\(messages.count) 条消息", entries: entries)
    }

    static func moments(_ list: [Moment]) -> UIImage? {
        let entries = list.prefix(12).map { moment in
            PageEntry(name: moment.nickname ?? "好友",
                      text: (moment.content ?? "").isEmpty ? "[图片/视频动态]" : (moment.content ?? ""),
                      meta: "赞 \(moment.likeCount) · 评论 \(moment.commentCount)")
        }
        return render(title: "朋友圈", subtitle: "最新 \(entries.count) 条动态", entries: Array(entries))
    }

    private struct PageEntry {
        let name: String
        let text: String
        let meta: String
    }

    private static func summary(of message: Message) -> String {
        if message.recalled == 1 { return "撤回了一条消息" }
        switch message.type {
        case 1: return (message.text ?? message.content ?? "").isEmpty ? "[消息]" : (message.text ?? message.content ?? "")
        case 2: return "[图片]"
        case 3: return "[语音]"
        case 4: return "[视频]"
        case 5: return "[文件]"
        default: return "[消息]"
        }
    }

    private static func timeText(_ ts: Int64) -> String {
        guard ts > 0 else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }

    private static func render(title: String, subtitle: String, entries: [PageEntry]) -> UIImage? {
        guard !entries.isEmpty else { return nil }
        let width: CGFloat = 900
        let margin: CGFloat = 40
        let avatar: CGFloat = 52
        let gap: CGFloat = 16
        let bubbleX = margin + avatar + gap
        let bubbleWidth = width - bubbleX - margin
        let bubbleInset: CGFloat = 20

        let nameFont = UIFont.systemFont(ofSize: 24, weight: .medium)
        let textFont = UIFont.systemFont(ofSize: 28)
        let metaFont = UIFont.systemFont(ofSize: 20)

        let textWidth = bubbleWidth - bubbleInset * 2
        var bubbleHeights: [CGFloat] = []
        for entry in entries {
            let rect = (entry.text as NSString).boundingRect(
                with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: textFont],
                context: nil
            )
            bubbleHeights.append(ceil(rect.height) + bubbleInset * 2)
        }

        let headerHeight: CGFloat = 132
        let footerHeight: CGFloat = 80
        let rowSpacing: CGFloat = 22
        let nameRowHeight: CGFloat = 30
        let contentHeight = bubbleHeights.reduce(0) { $0 + $1 + nameRowHeight + rowSpacing }
        let height = max(720, headerHeight + 24 + contentHeight + footerHeight)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)

        return renderer.image { context in
            let gc = context.cgContext
            UIColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1).setFill()
            gc.fill(CGRect(x: 0, y: 0, width: width, height: height))

            UIColor(red: 0.09, green: 0.10, blue: 0.13, alpha: 1).setFill()
            gc.fill(CGRect(x: 0, y: 0, width: width, height: headerHeight))
            UIColor(red: 0.0, green: 0.45, blue: 0.98, alpha: 1).setFill()
            gc.fill(CGRect(x: 0, y: headerHeight - 3, width: width, height: 3))

            (title as NSString).draw(at: CGPoint(x: margin, y: 40),
                                     withAttributes: [.font: UIFont.systemFont(ofSize: 36, weight: .semibold),
                                                      .foregroundColor: UIColor.white])
            (subtitle as NSString).draw(at: CGPoint(x: margin, y: 88),
                                        withAttributes: [.font: metaFont,
                                                         .foregroundColor: UIColor(white: 1, alpha: 0.55)])

            var y = headerHeight + 24
            for (index, entry) in entries.enumerated() {
                let bubbleHeight = bubbleHeights[index]

                UIColor(red: 0.16, green: 0.20, blue: 0.27, alpha: 1).setFill()
                let avatarRect = CGRect(x: margin, y: y + 2, width: avatar, height: avatar)
                gc.fillEllipse(in: avatarRect)
                let initial = String(entry.name.prefix(1))
                let initialSize = (initial as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 24, weight: .semibold)])
                (initial as NSString).draw(at: CGPoint(x: avatarRect.midX - initialSize.width / 2,
                                                       y: avatarRect.midY - initialSize.height / 2),
                                           withAttributes: [.font: UIFont.systemFont(ofSize: 24, weight: .semibold),
                                                            .foregroundColor: UIColor.white])

                (entry.name as NSString).draw(at: CGPoint(x: bubbleX, y: y + 4),
                                              withAttributes: [.font: nameFont,
                                                               .foregroundColor: UIColor(white: 1, alpha: 0.8)])
                if !entry.meta.isEmpty {
                    let metaSize = (entry.meta as NSString).size(withAttributes: [.font: metaFont])
                    (entry.meta as NSString).draw(at: CGPoint(x: width - margin - metaSize.width, y: y + 6),
                                                  withAttributes: [.font: metaFont,
                                                                   .foregroundColor: UIColor(white: 1, alpha: 0.45)])
                }

                let bubbleRect = CGRect(x: bubbleX, y: y + nameRowHeight, width: bubbleWidth, height: bubbleHeight)
                UIColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 1).setFill()
                UIBezierPath(roundedRect: bubbleRect, cornerRadius: 14).fill()
                (entry.text as NSString).draw(in: bubbleRect.insetBy(dx: bubbleInset, dy: bubbleInset),
                                              withAttributes: [.font: textFont,
                                                               .foregroundColor: UIColor(white: 1, alpha: 0.92)])
                y += nameRowHeight + bubbleHeight + rowSpacing
            }

            ("AK商聊 · 直播内容共享" as NSString).draw(at: CGPoint(x: margin, y: height - footerHeight + 26),
                                                     withAttributes: [.font: metaFont,
                                                                      .foregroundColor: UIColor(white: 1, alpha: 0.35)])
        }
    }
}

/// 相册视频转存到应用临时目录，避免整段视频进内存
struct LiveMovieFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ak-live-content", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copy = dir.appendingPathComponent("\(UUID().uuidString).\(ext)")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return LiveMovieFile(url: copy)
        }
    }
}

/// 内容共享选择面板：相册图片/视频，或把群聊/朋友圈页面渲染成画面
struct LiveContentPickerSheet: View {
    var makeGroupChat: () async -> LiveContentSelection?
    var makeMoments: () async -> LiveContentSelection?
    var onReady: (LiveContentSelection) -> Void
    var onError: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var items: [PhotosPickerItem] = []
    @State private var loading = false
    @State private var loadingText = ""

    var body: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            Text("共享内容")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AKColor.text)
                .padding(.bottom, 2)

            PhotosPicker(selection: $items, maxSelectionCount: 9, matching: .any(of: [.images, .videos])) {
                optionRow(icon: "photo.on.rectangle", title: "相册图片/视频",
                          detail: "最多 9 张图片，或 1 个视频")
            }
            .buttonStyle(.plain)

            Button {
                pickPage(makeGroupChat, empty: "群聊里还没有消息，先聊两句再共享")
            } label: {
                optionRow(icon: "bubble.left.and.bubble.right", title: "群聊画面",
                          detail: "把最近的消息渲染成画面自动浏览")
            }
            .buttonStyle(.plain)

            Button {
                pickPage(makeMoments, empty: "朋友圈还没有动态")
            } label: {
                optionRow(icon: "photo.stack", title: "朋友圈画面",
                          detail: "把最新的动态渲染成画面自动浏览")
            }
            .buttonStyle(.plain)

            if loading {
                HStack(spacing: 8) {
                    ProgressView().tint(AKColor.text)
                    Text(loadingText)
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.text.opacity(0.7))
                }
                .padding(.top, 6)
            }

            Spacer(minLength: 4)

            Button {
                dismiss()
            } label: {
                Text("取消")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AKColor.text.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(AKColor.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .onChange(of: items) { picked in
            Task { await load(picked) }
        }
    }

    private func optionRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(AKColor.brand)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AKColor.text)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(AKColor.text.opacity(0.55))
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AKColor.text.opacity(0.35))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func pickPage(_ loader: @escaping () async -> LiveContentSelection?, empty: String) {
        loading = true
        loadingText = "正在生成画面…"
        Task {
            let selection = await loader()
            loading = false
            if let selection {
                onReady(selection)
            } else {
                onError(empty)
            }
        }
    }

    private func load(_ picked: [PhotosPickerItem]) async {
        guard !picked.isEmpty else { return }
        guard !loading else { return }
        loading = true
        loadingText = "正在读取…"
        defer { loading = false }

        if let first = picked.first, isVideo(first) {
            if let movie = try? await first.loadTransferable(type: LiveMovieFile.self) {
                onReady(LiveContentSelection(source: .video(movie.url), label: "视频"))
            } else {
                onError("视频读取失败，请换一个试试")
            }
            return
        }

        var images: [UIImage] = []
        for item in picked.prefix(9) {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { continue }
            images.append(downsized(image, maxSide: 1600))
        }
        guard !images.isEmpty else {
            onError("图片读取失败，请重试")
            return
        }
        onReady(LiveContentSelection(source: .photos(images),
                                     label: images.count > 1 ? "相册 \(images.count) 张图片" : "相册图片"))
    }

    private func isVideo(_ item: PhotosPickerItem) -> Bool {
        item.supportedContentTypes.contains { $0.conforms(to: .movie) }
    }

    private func downsized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxSide, longest > 0 else { return image }
        let scale = maxSide / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
