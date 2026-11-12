import SwiftUI
import AVKit
import Combine
import UIKit

/// 会话内图片/视频预览项：带原消息时才能转发/收藏/撤回/删除
struct PreviewMedia: Identifiable {
    let id = UUID()
    let url: URL
    let isVideo: Bool
    let message: Message?
}

struct PreviewImage: Identifiable {
    let id = UUID()
    let items: [PreviewMedia]
    let index: Int
}

/// 会话内媒体分页器（对齐安卓 MediaPager）：
/// 顶部关闭 + i/n，底部保存/转发/收藏/撤回/删除；图片双击 2.5x、双指 1–4x 缩放；下滑超过 140 关闭。
struct MediaPagerView: View {
    let items: [PreviewMedia]
    @State private var index: Int
    @State private var toast: String?
    @State private var toastToken = 0

    var onForward: (Message) -> Void = { _ in }
    var onFavorite: (Message) -> Void = { _ in }
    var onRecall: (Message) -> Void = { _ in }
    var onDelete: (Message) -> Void = { _ in }
    /// 是否显示「撤回」：撤回时限/身份由聊天页判断
    var canRecall: (Message) -> Bool = { _ in false }

    @Environment(\.dismiss) private var dismiss

    init(items: [PreviewMedia], index: Int,
         onForward: @escaping (Message) -> Void = { _ in },
         onFavorite: @escaping (Message) -> Void = { _ in },
         onRecall: @escaping (Message) -> Void = { _ in },
         onDelete: @escaping (Message) -> Void = { _ in },
         canRecall: @escaping (Message) -> Bool = { _ in false }) {
        self.items = items
        _index = State(initialValue: max(0, min(index, max(0, items.count - 1))))
        self.onForward = onForward
        self.onFavorite = onFavorite
        self.onRecall = onRecall
        self.onDelete = onDelete
        self.canRecall = canRecall
    }

    private var current: PreviewMedia? {
        items.indices.contains(index) ? items[index] : nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if items.isEmpty {
                Text("图片不可用").font(.system(size: 13)).foregroundColor(.white.opacity(0.7))
            } else {
                TabView(selection: $index) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                        Group {
                            if item.isVideo {
                                PagerVideoView(url: item.url, active: i == index)
                            } else {
                                ZoomableImageView(url: item.url) { dismiss() }
                            }
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()

                topBar
                bottomBar
            }

            if let toast {
                Text(toast)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
            }
        }
        .statusBarHidden(true)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.height > 140, abs(value.translation.width) < value.translation.height {
                        dismiss()
                    }
                }
        )
    }

    private var topBar: some View {
        VStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Text("✕")
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                Spacer()
                Text("\(index + 1)/\(items.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer()
                Color.clear.frame(width: 34, height: 34)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            Spacer()
        }
    }

    private var bottomBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 0) {
                action("保存") { saveCurrent() }
                if let msg = current?.message {
                    action("转发") {
                        onForward(msg)
                        dismiss()
                    }
                    action("收藏") {
                        onFavorite(msg)
                        dismiss()
                    }
                    if let msg = current?.message, canRecall(msg) {
                        action("撤回") {
                            onRecall(msg)
                            dismiss()
                        }
                    }
                    action("删除") {
                        onDelete(msg)
                        dismiss()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.6))
        }
    }

    private func action(_ label: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Text(label)
                .font(.system(size: 12.5))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func saveCurrent() {
        guard let item = current else { return }
        Task {
            let ok = await AKMediaSaver.save(url: item.url, isVideo: item.isVideo)
            showToast(ok ? "已保存到相册" : "保存失败")
        }
    }

    private func showToast(_ text: String) {
        toast = text
        toastToken += 1
        let token = toastToken
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                if token == toastToken { toast = nil }
            }
        }
    }
}

/* ---------------- 保存到相册 ---------------- */

/// 预览器与聊天长按菜单共用：下载后写入系统相册，失败返回 false
enum AKMediaSaver {
    static func save(url: URL, isVideo: Bool) async -> Bool {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return false }
        if isVideo {
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("ak_\(UUID().uuidString).mp4")
            guard (try? data.write(to: tmp)) != nil else { return false }
            UISaveVideoAtPathToSavedPhotosAlbum(tmp.path, nil, nil, nil)
            return true
        }
        guard let image = UIImage(data: data) else { return false }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        return true
    }
}

/* ---------------- 图片缩放 ---------------- */

private struct ZoomableImageView: View {
    let url: URL
    let onClose: () -> Void

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseScale: CGFloat = 1
    @State private var baseOffset: CGSize = .zero

    private let maxScale: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    ProgressView().tint(.white)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .scaleEffect(scale)
            .offset(offset)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                if scale > 1.01 {
                    scale = 1
                    offset = .zero
                    baseScale = 1
                    baseOffset = .zero
                } else {
                    scale = 2.5
                    baseScale = 2.5
                }
            }
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = min(max(baseScale * value, 1), maxScale)
                    }
                    .onEnded { _ in
                        baseScale = scale
                        if scale <= 1.01 {
                            scale = 1
                            offset = .zero
                            baseOffset = .zero
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        guard scale > 1.01 else { return }
                        offset = CGSize(width: baseOffset.width + value.translation.width,
                                        height: baseOffset.height + value.translation.height)
                    }
                    .onEnded { _ in
                        guard scale > 1.01 else { return }
                        let maxX = geo.size.width * (scale - 1) / 2
                        let maxY = geo.size.height * (scale - 1) / 2
                        offset = CGSize(width: min(max(offset.width, -maxX), maxX),
                                        height: min(max(offset.height, -maxY), maxY))
                        baseOffset = offset
                    }
            )
        }
    }
}

/* ---------------- 视频播放 ---------------- */

private struct PagerVideoView: View {
    let url: URL
    let active: Bool

    @StateObject private var playback = VideoPlayback()
    @Environment(\.scenePhase) private var scenePhase
    /// 进后台前是否在播：回前台恢复，但用户手动暂停的不能被自动放开
    @State private var resumeAfterBackground = false
    /// 拖动进度条时的临时值；松手才真正 seek
    @State private var scrub: Double?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = playback.player {
                AKVideoSurface(player: player)
                    .ignoresSafeArea()
            }

            if playback.state == .failed {
                failedHint
            } else if playback.state == .paused {
                playBadge
            }

            if playback.buffering || playback.state == .loading {
                ProgressView()
                    .scaleEffect(1.1)
                    .tint(.white)
            }

            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        playback.toggle()
                    } label: {
                        Text(playback.state == .playing ? "⏸" : "▶")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Slider(
                        value: Binding(
                            get: { scrub ?? (playback.duration > 0 ? playback.position / playback.duration : 0) },
                            set: { scrub = $0 }
                        ),
                        in: 0...1
                    ) { editing in
                        if !editing, let value = scrub {
                            playback.seek(to: value * playback.duration)
                            scrub = nil
                        }
                    }
                    .tint(AKColor.brand)

                    Text(fmt(playback.duration))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 84)
            }
        }
        .onTapGesture {
            if playback.state == .failed {
                playback.retry()
            } else {
                playback.toggle()
            }
        }
        .onAppear {
            playback.load(url)
            if active { playback.play() }
        }
        .onChange(of: active) { on in
            if on { playback.play() } else { playback.pause() }
        }
        .onDisappear { playback.pause() }
        /*
         * 工程开了 audio 后台模式（通话/直播要用），AVPlayer 不会因为进后台就停：
         * 预览视频会继续出声、继续解码。这里和安卓 PausePlayerWhenHidden 同口径：
         * 进后台暂停，回前台只恢复本来在播的那一条。
         */
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                if resumeAfterBackground {
                    resumeAfterBackground = false
                    playback.play()
                }
            } else {
                resumeAfterBackground = playback.state == .playing
                playback.pause()
            }
        }
    }

    /// 失败不静默：给明确文案，点画面任意位置重建 item 重试
    private var failedHint: some View {
        VStack(spacing: 7) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 22))
            Text("视频无法播放，点击重试")
                .font(.system(size: 13))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .allowsHitTesting(false)
    }

    private var playBadge: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 22))
            .foregroundColor(.white)
            .frame(width: 64, height: 64)
            .background(Color.black.opacity(0.4))
            .clipShape(Circle())
            .allowsHitTesting(false)
    }

    private func fmt(_ seconds: Double) -> String {
        guard seconds > 0 else { return "00:00" }
        let s = Int(seconds)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
