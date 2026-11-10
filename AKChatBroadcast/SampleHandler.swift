import CoreMedia
import LiveKit
import ReplayKit

/// ReplayKit 屏幕广播扩展。
///
/// 画面与系统播放声音都由扩展直接发布到 LiveKit（独立 identity `<主播 uid>_bc`），
/// 这样切到其他 App 后仍能继续共享，并且系统声音是单独一条音轨；
/// 主播麦克风仍由主 App 的麦克风轨发布，两者不混音。
final class SampleHandler: RPBroadcastSampleHandler {
    private var finishing = false
    private var observerPointer: UnsafeMutableRawPointer?

    override init() {
        super.init()
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        observerPointer = pointer
        CFNotificationCenterAddObserver(
            center,
            pointer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                Unmanaged<SampleHandler>.fromOpaque(observer)
                    .takeUnretainedValue()
                    .stopFromHost()
            },
            BroadcastControl.stopNotification as CFString,
            nil,
            .deliverImmediately
        )
    }

    deinit {
        if let observerPointer {
            CFNotificationCenterRemoveObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                observerPointer,
                CFNotificationName(BroadcastControl.stopNotification as CFString),
                nil
            )
        }
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        // 扩展自己用 BufferCapturer 发布画面；禁止 LiveKit 在收到广播开始通知后
        // 再自动创建一条 BroadcastScreenCapturer 轨，避免同一 Room 出现两条屏幕轨。
        BroadcastManager.shared.shouldPublishTrack = false
        BroadcastBridge.markStarted()
        BroadcastControl.postStarted()
        BroadcastPublisher.shared.onFailure = { [weak self] in self?.stopFromHost() }
        BroadcastPublisher.shared.start()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer,
                                      with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            BroadcastPublisher.shared.appendVideo(sampleBuffer)
        case .audioApp:
            // 其他 App / 系统播放声音 → 独立系统声音轨
            BroadcastPublisher.shared.appendAudio(sampleBuffer, source: .system)
        case .audioMic:
            // 默认不重复发布：主播麦克风由主 App 的麦克风轨负责，扩展再发会双声/回声。
            // 只有主 App 明确把麦克风交给扩展时才接收（BroadcastBridge.extensionMicEnabled）。
            BroadcastPublisher.shared.appendAudio(sampleBuffer, source: .microphone)
        @unknown default:
            break
        }
    }

    override func broadcastFinished() {
        finishing = true
        BroadcastPublisher.shared.stop()
        BroadcastBridge.markStopped()
        BroadcastControl.postStopped()
    }

    /// 主 App 点「停止共享」时通过 BroadcastControl 发本应用自定义 Darwin 通知，
    /// 扩展必须自己 finish，否则系统广播会一直挂在下拉控制中心。
    private func stopFromHost() {
        guard !finishing else { return }
        finishing = true
        BroadcastPublisher.shared.stop()
        BroadcastBridge.markStopped()
        BroadcastControl.postStopped()
        AKFinishBroadcastWithoutError(self)
    }
}
