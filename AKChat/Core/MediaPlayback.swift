import AVFoundation
import Combine
import Foundation
import SwiftUI
import UIKit

/* ---------------- 媒体地址 ---------------- */

/// 媒体消息地址清洗与绝对化。
/// 历史数据里同一个字段出现过「URL」「URL|」「URL|#|{json}」三种形态（对齐安卓 cleanMediaUrl/API.fullUrl），
/// 直接拿去建 AVPlayer/AVURLAsset 会 404 或直接返回 nil，表现为点了没反应或永远黑屏。
enum MediaURLPath {
    static func clean(_ raw: String?) -> String {
        guard let raw else { return "" }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let withoutMeta = trimmed.components(separatedBy: "|#|").first ?? trimmed
        return (withoutMeta.components(separatedBy: "|").first ?? withoutMeta)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 相对路径拼 https 绝对地址；路径里的中文/空格按百分号编码（URL(string:) 遇到空格会直接返回 nil）
    static func url(_ raw: String?) -> URL? {
        let path = clean(raw)
        guard !path.isEmpty else { return nil }

        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            if let url = URL(string: path), url.host != nil { return url }
            guard let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) else {
                return nil
            }
            return URL(string: encoded)
        }

        let relative = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !relative.isEmpty else { return nil }
        if let url = URL(string: APIClient.base.absoluteString + relative), url.host != nil {
            return url
        }
        let encoded = relative.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? relative
        return URL(string: APIClient.base.absoluteString + encoded)
    }
}

/* ---------------- 播放状态 ---------------- */

/// AVPlayer 的显式状态机：任何视频都能落到「就绪/播放/暂停/失败」，失败可重建 item 重试。
/// 原来直接 AVPlayer(url:) 不看 status，moov 在尾部的原片或解码失败时就是一块黑屏，点播放也没反应。
final class VideoPlayback: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case playing
        case paused
        case failed
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var buffering = false

    private(set) var player: AVPlayer?
    private var item: AVPlayerItem?
    private var source: URL?
    private var statusToken: NSKeyValueObservation?
    private var keepUpToken: NSKeyValueObservation?
    private var timeControlToken: NSKeyValueObservation?
    private var timeToken: Any?
    private var endToken: NSObjectProtocol?
    private var failToken: NSObjectProtocol?
    private var watchdog: DispatchWorkItem?
    /// 用户意图：就绪前就点了播放，status 到 readyToPlay 后要自动起播
    private var wantsPlayback = false

    deinit {
        /* 析构里不能碰 @Published（会向已释放的订阅者发变更），只收监听并停播 */
        watchdog?.cancel()
        if let token = timeToken, let player = player { player.removeTimeObserver(token) }
        if let endToken { NotificationCenter.default.removeObserver(endToken) }
        if let failToken { NotificationCenter.default.removeObserver(failToken) }
        statusToken?.invalidate()
        keepUpToken?.invalidate()
        timeControlToken?.invalidate()
        player?.pause()
    }

    func load(_ url: URL, autoplay: Bool = false) {
        if source == url, player != nil { return }
        teardown()
        source = url
        state = .loading

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        /* 服务端零转码、moov 常在文件尾：预缓冲只留 2s，不让播放器为了大缓冲一直不吐画面 */
        item.preferredForwardBufferDuration = 2
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = true

        self.item = item
        self.player = player
        observe(item, player)

        Task {
            if let value = try? await asset.load(.duration) {
                let seconds = value.seconds
                await MainActor.run {
                    self.duration = seconds.isFinite ? max(0, seconds) : 0
                }
            }
        }

        if autoplay { play() }
    }

    func play() {
        guard let player else { return }
        if state == .failed {
            retry()
            return
        }
        wantsPlayback = true
        if duration > 0, position >= duration - 0.1 {
            player.seek(to: CMTime(seconds: 0, preferredTimescale: 600))
            position = 0
        }
        player.play()
        state = player.currentItem?.status == .readyToPlay ? .playing : .loading
        startWatchdog()
    }

    func pause() {
        wantsPlayback = false
        player?.pause()
        if state == .playing { state = .paused }
        buffering = false
        watchdog?.cancel()
        watchdog = nil
    }

    func toggle() {
        if state == .playing { pause() } else { play() }
    }

    func seek(to seconds: Double) {
        guard let player, duration > 0 else { return }
        let target = min(max(seconds, 0), duration)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        position = target
    }

    func retry() {
        guard let url = source else { return }
        teardown()
        load(url, autoplay: true)
    }

    func stop() {
        teardown()
        source = nil
        state = .idle
        position = 0
        duration = 0
    }

    /* ---------------- 内部 ---------------- */

    private func observe(_ item: AVPlayerItem, _ player: AVPlayer) {
        statusToken = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    if self.wantsPlayback {
                        self.player?.play()
                        self.state = .playing
                    } else if self.state == .loading {
                        self.state = .paused
                    }
                    self.buffering = false
                case .failed:
                    self.fail()
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }

        keepUpToken = item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self, self.state == .playing else { return }
                self.buffering = !item.isPlaybackLikelyToKeepUp
            }
        }

        timeControlToken = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.state == .playing else {
                    self.buffering = false
                    return
                }
                let waiting = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                self.buffering = waiting
                /* 播放中途卡住超过 12s 也要给提示，而不是只有转圈 */
                if waiting {
                    self.startWatchdog()
                } else {
                    self.watchdog?.cancel()
                    self.watchdog = nil
                }
            }
        }

        timeToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            let seconds = time.seconds
            guard seconds.isFinite else { return }
            self.position = max(0, seconds)
            if self.duration <= 0 {
                let itemDuration = self.player?.currentItem?.duration.seconds ?? 0
                if itemDuration.isFinite, itemDuration > 0 { self.duration = itemDuration }
            }
        }

        endToken = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.state = .paused
            self.buffering = false
            self.position = self.duration
        }

        failToken = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: item, queue: .main
        ) { [weak self] _ in
            self?.fail()
        }
    }

    /// 12s 内还在等缓冲就直接判失败：宁可给「点击重试」，也不要静默卡在首帧
    private func startWatchdog() {
        watchdog?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.wantsPlayback else { return }
            if self.player?.timeControlStatus != .playing {
                self.fail()
            }
        }
        watchdog = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: work)
    }

    private func fail() {
        watchdog?.cancel()
        watchdog = nil
        wantsPlayback = false
        buffering = false
        state = .failed
    }

    private func teardown() {
        watchdog?.cancel()
        watchdog = nil

        statusToken?.invalidate()
        statusToken = nil
        keepUpToken?.invalidate()
        keepUpToken = nil
        timeControlToken?.invalidate()
        timeControlToken = nil

        if let token = timeToken, let player = player {
            player.removeTimeObserver(token)
        }
        timeToken = nil

        if let endToken { NotificationCenter.default.removeObserver(endToken) }
        endToken = nil
        if let failToken { NotificationCenter.default.removeObserver(failToken) }
        failToken = nil

        player?.pause()
        player = nil
        item = nil
        wantsPlayback = false
        buffering = false
    }
}

/* ---------------- 视频画面 ---------------- */

/// AVPlayerLayer 宿主：SwiftUI 只负责布局，播放控制留在上层，不接管触摸
struct AKVideoSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> AKPlayerContainerView {
        let view = AKPlayerContainerView()
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: AKPlayerContainerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }
}

final class AKPlayerContainerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspect
        backgroundColor = .black
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        playerLayer.videoGravity = .resizeAspect
        backgroundColor = .black
        isUserInteractionEnabled = false
    }
}
