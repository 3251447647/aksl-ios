import SwiftUI
import AVFoundation
import AVKit
import CoreMedia
import UIKit
import LiveKit

/// 把远端视频轨的帧送进 AVSampleBufferDisplayLayer，供画中画渲染。
/// LiveKit 的 VideoView 底层不是 AVSampleBufferDisplayLayer，所以这里另挂一个渲染器，
/// 与页面上的 LiveKit 视图共用同一条轨道。
final class LivePiPRenderer: NSObject, VideoRenderer, @unchecked Sendable {
    let displayLayer = AVSampleBufferDisplayLayer()

    var isAdaptiveStreamEnabled: Bool { false }
    var adaptiveStreamSize: CGSize { .zero }

    @objc func render(frame: VideoFrame) {
        guard let pixelBuffer = frame.toCVPixelBuffer() else { return }
        let pts = CMClockGetTime(CMClockGetHostTimeClock())
        guard let sample = Self.makeSampleBuffer(pixelBuffer, presentationTime: pts) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let layer = self?.displayLayer else { return }
            // 主线程忙时直接丢帧，避免队列积压导致画中画越播越延迟
            guard layer.isReadyForMoreMediaData else { return }
            if layer.status == .failed {
                layer.flush()
            }
            layer.enqueue(sample)
        }
    }

    /// 按宿主时钟打时间戳并标记立即显示：直播流不需要等待渲染时序。
    private static func makeSampleBuffer(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) -> CMSampleBuffer? {
        var format: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                           imageBuffer: pixelBuffer,
                                                           formatDescriptionOut: &format) == noErr,
              let format else { return nil }
        var timing = CMSampleTimingInfo(duration: .invalid,
                                        presentationTimeStamp: presentationTime,
                                        decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        guard CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
                                                       imageBuffer: pixelBuffer,
                                                       formatDescription: format,
                                                       sampleTiming: &timing,
                                                       sampleBufferOut: &sample) == noErr,
              let sample else { return nil }
        CMSetAttachment(sample,
                        key: kCMSampleAttachmentKey_DisplayImmediately,
                        value: kCFBooleanTrue,
                        attachmentMode: kCMAttachmentMode_ShouldPropagate)
        return sample
    }
}

/// 观众端画中画：远端画面在 App 进入后台后继续悬浮播放。
final class LivePiPController: NSObject, ObservableObject {
    @Published private(set) var isActive = false
    /// 启动失败的原因，页面拿它给用户提示
    @Published private(set) var lastError: String?

    let renderer = LivePiPRenderer()

    private var controller: AVPictureInPictureController?
    private weak var track: VideoTrack?
    private var pendingStart: ((Bool) -> Void)?
    /// 等待层出首帧（isPictureInPicturePossible 变 true）的轮询次数
    private var waitTicks = 0

    var isSupported: Bool { AVPictureInPictureController.isPictureInPictureSupported() }

    override init() {
        super.init()
        renderer.displayLayer.videoGravity = .resizeAspect
        renderer.displayLayer.isOpaque = true
    }

    /// 远端轨变化时重新挂渲染器；传 nil 会顺带停掉画中画。
    func sync(track: VideoTrack?) {
        guard self.track !== track else { return }
        self.track?.remove(videoRenderer: renderer)
        self.track = track
        if let track {
            track.add(videoRenderer: renderer)
        } else {
            stop()
        }
    }

    /// 提前建好控制器：内容在播放时用户切后台，系统才能自动弹出画中画。
    func prepare() {
        _ = ensureController()
        if !isSupported {
            lastError = "当前设备不支持画中画"
        }
    }

    /// 启动是异步的：displayLayer 拿到首帧后 isPictureInPicturePossible 才会变 true，
    /// 所以先轮询等待再启动，并把真实结果回调给页面。
    func start(completion: @escaping (Bool) -> Void) {
        guard isSupported else {
            finish(completion, ok: false, error: "当前设备不支持画中画")
            return
        }
        guard track != nil else {
            finish(completion, ok: false, error: "还没有可播放的画面")
            return
        }
        guard let controller = ensureController() else {
            finish(completion, ok: false, error: "画中画初始化失败")
            return
        }
        guard pendingStart == nil else { return }
        if controller.isPictureInPictureActive {
            finish(completion, ok: true, error: nil)
            return
        }
        if controller.isPictureInPicturePossible {
            lastError = nil
            waitTicks = 0
            pendingStart = completion
            controller.startPictureInPicture()
            // 委托回调偶发丢失（切后台/系统繁忙）时兜底，避免按钮点了一直没反应
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.resolveStart()
            }
            return
        }
        guard waitTicks < 8 else {
            finish(completion, ok: false, error: "画面还没准备好，请等主播画面出现后再试")
            return
        }
        waitTicks += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self else {
                completion(false)
                return
            }
            self.start(completion: completion)
        }
    }

    func stop() {
        onMain {
            if let pending = self.pendingStart {
                self.pendingStart = nil
                pending(false)
            }
            self.waitTicks = 0
            self.controller?.stopPictureInPicture()
        }
    }

    /// 退出直播间：停掉悬浮窗并摘掉渲染器，避免断流后停在最后一帧。
    func invalidate() {
        onMain {
            self.stop()
            self.track?.remove(videoRenderer: self.renderer)
            self.track = nil
        }
    }

    private func finish(_ completion: @escaping (Bool) -> Void, ok: Bool, error: String?) {
        waitTicks = 0
        lastError = error
        completion(ok)
    }

    /// 画中画启动结果落地：成功与否都以 isPictureInPictureActive 为准
    private func resolveStart() {
        guard let completion = pendingStart else { return }
        pendingStart = nil
        waitTicks = 0
        let ok = controller?.isPictureInPictureActive == true
        if !ok, lastError == nil {
            lastError = "画中画启动失败，请稍后再试"
        }
        completion(ok)
    }

    private func ensureController() -> AVPictureInPictureController? {
        if let controller { return controller }
        guard isSupported else { return nil }
        let source = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: renderer.displayLayer,
            playbackDelegate: self
        )
        guard let controller = AVPictureInPictureController(contentSource: source) else { return nil }
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        self.controller = controller
        return controller
    }

    private func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}

extension LivePiPController: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        onMain {
            self.isActive = true
            self.lastError = nil
            self.resolveStart()
        }
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        onMain {
            self.isActive = false
            self.resolveStart()
        }
    }

    /// 用户在悬浮窗点「回到 App」：系统收掉画中画，页面由 isActive 变化重挂渲染器
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    failedToStartPictureInPictureWithError error: Error) {
        onMain {
            self.isActive = false
            self.resolveStart()
            if self.lastError == nil || self.lastError == "画中画启动失败，请稍后再试" {
                self.lastError = "画中画启动失败：\(error.localizedDescription)"
            }
        }
    }
}

extension LivePiPController: AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
    }

    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }

    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        false
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    skipByInterval skipInterval: CMTime,
                                    completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

/// AVSampleBufferDisplayLayer 的宿主视图：画中画要求 layer 在视图层级里且尺寸非零。
final class PiPLayerHostView: UIView {
    private let displayLayer: AVSampleBufferDisplayLayer

    init(displayLayer: AVSampleBufferDisplayLayer) {
        self.displayLayer = displayLayer
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        layer.addSublayer(displayLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.frame = bounds
        CATransaction.commit()
    }
}

struct PiPDisplayView: UIViewRepresentable {
    let displayLayer: AVSampleBufferDisplayLayer

    func makeUIView(context: Context) -> PiPLayerHostView {
        PiPLayerHostView(displayLayer: displayLayer)
    }

    func updateUIView(_ uiView: PiPLayerHostView, context: Context) {
    }
}
