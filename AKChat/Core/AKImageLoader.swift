import Foundation
import UIKit
import ImageIO
import Combine

// MARK: - 并发闸门

/// 轻量并发闸门：最多 `limit` 个任务同时持有名额，其余排队等待（等待期间不占线程）。
/// release() 是同步的，可以直接写在 defer 里。
final class AKConcurrencyLimiter: @unchecked Sendable {
    private let limit: Int
    private let lock = NSLock()
    private var active = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = max(limit, 1)
    }

    func acquire() async {
        lock.lock()
        if active < limit {
            active += 1
            lock.unlock()
            return
        }
        lock.unlock()

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            lock.lock()
            if active < limit {
                active += 1
                lock.unlock()
                cont.resume()
            } else {
                waiters.append(cont)
                lock.unlock()
            }
        }
    }

    func release() {
        lock.lock()
        if waiters.isEmpty {
            active = max(active - 1, 0)
            lock.unlock()
        } else {
            let next = waiters.removeFirst()
            lock.unlock()
            next.resume() // 名额直接转交，active 保持不变
        }
    }
}

// MARK: - 请求

/// 一次图片请求的身份：URL + 目标像素。
/// 同一个 URL 在不同位置（44pt 头像 / 三列九宫格 / 全屏预览）会按各自尺寸分别解码缓存，
/// 避免把 1080p 原图整张解码后塞给 44pt 的头像。
struct AKImageRequest: Hashable {
    let url: URL
    let maxPixel: Int

    var key: String { "\(url.absoluteString)|\(maxPixel)" }

    /// 只在主线程调用（读取 UIScreen.scale 与屏幕尺寸相关的换算）
    init(url: URL, size: CGSize) {
        self.url = url
        let scale = UIScreen.main.scale
        let longest = max(size.width, size.height) * scale
        let raw = Int(longest.rounded(.up))
        let bucket = ((raw + 31) / 32) * 32 // 归一到 32px 台阶，相近尺寸复用同一份位图
        self.maxPixel = min(max(bucket, 64), 2048)
    }
}

/// 解码完成的图片 + 它对应的请求 key（key 不一致时视图不渲染，避免换图时闪旧图）
struct AKLoadedImage {
    let key: String
    let image: UIImage
}

// MARK: - 加载器

/// 图片加载器：内存 NSCache + 磁盘 URLCache + ImageIO 降采样，下载最多 4 并发。
/// 同一个 key 的并发请求合并为一次下载；命中磁盘/内存都不占并发名额。
final class AKImageLoader: @unchecked Sendable {
    static let shared = AKImageLoader()
    /// 下载并发上限，避免与消息接口抢带宽
    static let downloadLimit = 4

    private let memory = NSCache<NSString, UIImage>()
    private let disk: URLCache
    private let session: URLSession
    private let gate = AKConcurrencyLimiter(limit: AKImageLoader.downloadLimit)
    private let lock = NSLock()
    private var inflight: [String: (token: UUID, task: Task<UIImage?, Never>)] = [:]

    private init() {
        memory.countLimit = 400
        memory.totalCostLimit = 64 * 1024 * 1024

        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("AKImageDisk", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        disk = URLCache(memoryCapacity: 0, diskCapacity: 256 * 1024 * 1024, directory: dir)

        let cfg = URLSessionConfiguration.default
        cfg.urlCache = disk
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 30
        cfg.httpMaximumConnectionsPerHost = AKImageLoader.downloadLimit
        session = URLSession(configuration: cfg)
    }

    /// 同步查内存缓存：body 里直接调用，命中时首帧就出图，不闪占位
    func cachedImage(for request: AKImageRequest) -> UIImage? {
        memory.object(forKey: request.key as NSString)
    }

    func image(for request: AKImageRequest) async -> UIImage? {
        if let hit = cachedImage(for: request) { return hit }
        let (token, task) = sharedTask(for: request)
        let image = await task.value
        lock.lock()
        if inflight[request.key]?.token == token { inflight[request.key] = nil }
        lock.unlock()
        return image
    }

    private func sharedTask(for request: AKImageRequest) -> (UUID, Task<UIImage?, Never>) {
        lock.lock()
        if let existing = inflight[request.key] {
            lock.unlock()
            return (existing.token, existing.task)
        }
        let token = UUID()
        let task = Task.detached(priority: .utility) { [weak self] () -> UIImage? in
            guard let self else { return nil }
            return await self.fetch(request)
        }
        inflight[request.key] = (token, task)
        lock.unlock()
        return (token, task)
    }

    // MARK: 取图

    private func fetch(_ request: AKImageRequest) async -> UIImage? {
        let started = AKPerf.start()
        let urlRequest = URLRequest(url: request.url)
        let source: String
        let data: Data?

        if let cached = disk.cachedResponse(for: urlRequest), !cached.data.isEmpty {
            source = "disk"
            data = cached.data
        } else {
            source = "network"
            await gate.acquire()
            data = try? await download(request.url)
            gate.release()
        }

        guard let data else { return nil }
        let image: UIImage? = autoreleasepool {
            Self.downsample(data: data, maxPixel: request.maxPixel)
        }
        if let image {
            let cost = image.cgImage.map { $0.bytesPerRow * $0.height }
                ?? Int(image.size.width * image.size.height * 4)
            memory.setObject(image, forKey: request.key as NSString, cost: cost)
        }
        AKPerf.log("image.\(source)", since: started, request.key)
        return image
    }

    /// 下载并落盘；排队期间别的请求可能已经存过同一张图，所以拿到名额后再查一次磁盘
    private func download(_ url: URL) async throws -> Data? {
        let urlRequest = URLRequest(url: url)
        if let cached = disk.cachedResponse(for: urlRequest), !cached.data.isEmpty {
            return cached.data
        }
        var req = urlRequest
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 20
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              !data.isEmpty else { return nil }
        storeOnDisk(data, mime: http.mimeType, url: url)
        return data
    }

    /// 显式写入并补一年过期时间：服务端没给缓存头时 URLCache 仍能长期命中
    private func storeOnDisk(_ data: Data, mime: String?, url: URL) {
        let headers = [
            "Content-Type": mime ?? "image/jpeg",
            "Content-Length": String(data.count),
            "Cache-Control": "public, max-age=31536000"
        ]
        guard let stamped = HTTPURLResponse(url: url, statusCode: 200,
                                            httpVersion: "HTTP/1.1", headerFields: headers) else { return }
        let cached = CachedURLResponse(response: stamped, data: data, userInfo: nil, storagePolicy: .allowed)
        disk.storeCachedResponse(cached, for: URLRequest(url: url))
    }

    /// ImageIO 直接按目标像素解码，位图内存从「原图」降到「展示尺寸」
    private static func downsample(data: Data, maxPixel: Int) -> UIImage? {
        let srcOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithData(data as CFData, srcOptions) else {
            return fallback(data)
        }
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOptions as CFDictionary) else {
            return fallback(data)
        }
        return UIImage(cgImage: cg)
    }

    /// 极少数格式取不到缩略图时才整张解码，并且只接受小图
    private static func fallback(_ data: Data) -> UIImage? {
        guard data.count <= 6 * 1024 * 1024 else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - 视图模型

/// 视图侧状态：加载完成后在 MainActor 上发布；key 不匹配时视图不会画这张图
final class AKImageModel: ObservableObject {
    @Published private(set) var loaded: AKLoadedImage?

    func load(_ request: AKImageRequest) async {
        if loaded?.key == request.key { return }
        if let hit = AKImageLoader.shared.cachedImage(for: request) {
            await publish(hit, for: request)
            return
        }
        let image = await AKImageLoader.shared.image(for: request)
        await publish(image, for: request)
    }

    private func publish(_ image: UIImage?, for request: AKImageRequest) async {
        guard let image, !Task.isCancelled else { return }
        await MainActor.run {
            loaded = AKLoadedImage(key: request.key, image: image)
        }
    }
}
