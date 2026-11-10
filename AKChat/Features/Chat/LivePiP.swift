import SwiftUI
import AVFoundation
import AVKit
import CoreMedia
import LiveKit

/// 把远端视频轨的帧送进 AVSampleBufferDisplayLayer，供画中画渲染。
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
            if layer.status == .failed {
                layer.flush()
            }
            layer.enqueue(sample)
        }
    }

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

    let renderer = LivePiPRenderer()

    private var controller: AVPictureInPictureController?
    private weak var track: VideoTrack?

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
    }

    func start() -> Bool {
        guard track != nil, let controller = ensureController() else { return false }
        guard controller.isPictureInPicturePossible else { return false }
        controller.startPictureInPicture()
        return true
    }

    func stop() {
        controller?.stopPictureInPicture()
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
        onMain { self.isActive = true }
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        onMain { self.isActive = false }
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    failedToStartPictureInPictureWithError error: Error) {
        onMain { self.isActive = false }
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

/// AVSampleBufferDisplayLayer 的宿主视图：画中画要求 layer 在视图层级里。
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
