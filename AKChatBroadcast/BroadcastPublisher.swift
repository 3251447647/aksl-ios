import AVFoundation
import CoreMedia
import LiveKit

/// 屏幕共享扩展内的 LiveKit 发布器。
///
/// 扩展用独立 identity（`<主播 uid>_bc`）连进同一个直播间：
/// - 画面：`BufferCapturer` 推 `screen_share` 视频轨；
/// - 系统声音：`AudioManager.setManualRenderingMode(true)` + `mixer.capture(appAudio:)`
///   形成一条独立音频轨（源是 microphone，但内容只有系统播放声音）；
/// - 主播麦克风仍由主 App 的麦克风轨发布，两条音频互不混音。
///
/// 扩展进程没有设备音频权限也不需要：手动渲染模式不会打开麦克风，
/// 只把 ReplayKit 送来的 `.audioApp` PCM 喂给 WebRTC 的音频输入。
final class BroadcastPublisher: NSObject, RoomDelegate, @unchecked Sendable {
    static let shared = BroadcastPublisher()

    enum AudioSource {
        case system
        case microphone
    }

    private let queue = DispatchQueue(label: "com.yixin.chat.broadcast.publisher")
    private let maxPendingAudio = 80

    private var started = false
    private var room: Room?
    private var videoTrack: LocalVideoTrack?
    private var videoCapturer: BufferCapturer?
    private var videoPublishing = false
    private var videoPublished = false
    private var videoPublishFailures = 0
    private var pendingVideo: CMSampleBuffer?
    private var audioTrack: LocalAudioTrack?
    private var audioPublication: LocalTrackPublication?
    private var audioReady = false
    private var audioUnavailable = false
    private var pendingAudio: [AVAudioPCMBuffer] = []

    /// 连接/发布失败时通知扩展收掉系统广播，避免主播看到一条永远连不上的共享
    var onFailure: (() -> Void)?

    func start() {
        queue.async { [weak self] in
            guard let self, !self.started else { return }
            guard let config = BroadcastBridge.session else {
                // App 没写凭证（App Group 未授权/已停止共享）：不要留一个没有画面的广播
                DispatchQueue.main.async { [weak self] in self?.onFailure?() }
                return
            }
            self.started = true
            self.audioUnavailable = false
            self.connect(config)
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.started = false
            let room = self.room
            let publication = self.audioPublication
            self.room = nil
            self.videoTrack = nil
            self.videoCapturer = nil
            self.videoPublishing = false
            self.videoPublished = false
            self.videoPublishFailures = 0
            self.pendingVideo = nil
            self.audioTrack = nil
            self.audioPublication = nil
            self.audioReady = false
            self.audioUnavailable = false
            self.pendingAudio.removeAll()

            Task {
                if let publication {
                    try? await room?.localParticipant.unpublish(publication: publication)
                }
                await room?.disconnect()
                try? AudioManager.shared.setManualRenderingMode(false)
            }
        }
    }

    func appendVideo(_ sampleBuffer: CMSampleBuffer) {
        queue.async { [weak self] in
            guard let self, self.started else { return }
            guard self.videoCapturer != nil else {
                // 轨道/房间还没建好时只留最后一帧，建好后补发，保证发布时有尺寸
                self.pendingVideo = sampleBuffer
                return
            }
            self.captureVideoLocked(sampleBuffer)
        }
    }

    func appendAudio(_ sampleBuffer: CMSampleBuffer, source: AudioSource) {
        if source == .microphone, !BroadcastBridge.extensionMicEnabled { return }
        queue.async { [weak self] in
            guard let self, self.started else { return }
            guard let pcm = Self.pcmBuffer(from: sampleBuffer) else { return }
            if self.audioUnavailable { return }
            if self.audioReady {
                AudioManager.shared.mixer.capture(appAudio: pcm)
            } else if self.pendingAudio.count < self.maxPendingAudio {
                self.pendingAudio.append(pcm)
            }
        }
    }

    // MARK: - Connect

    private func connect(_ config: BroadcastSessionConfig) {
        var manualAudioUsable = true
        do {
            try AudioManager.shared.setManualRenderingMode(true)
            AudioManager.shared.mixer.appVolume = 0.8
        } catch {
            // 手动渲染不可用时只发画面，不能因为系统声音失败把屏幕共享也拖死。
            // 也不能去抢设备麦克风。
            manualAudioUsable = false
        }
        let initialAudioUsable = manualAudioUsable

        let room = Room()
        room.add(delegate: self)

        Task { [weak self] in
            do {
                try await room.connect(
                    url: config.url,
                    token: config.token,
                    connectOptions: ConnectOptions(autoSubscribe: false),
                    // 扩展本身就是后台进程，禁止 SDK 按 App 前后台自动挂起屏幕视频轨
                    roomOptions: RoomOptions(suspendLocalVideoTracksInBackground: false)
                )

                guard let self, self.isStarted else {
                    await room.disconnect()
                    return
                }

                let video = await LocalVideoTrack.createBufferTrack(
                    name: "screen",
                    source: .screenShareVideo,
                    options: BufferCaptureOptions(dimensions: .h720_169, fps: 15)
                )
                var audioUsable = initialAudioUsable
                let audio: LocalAudioTrack?
                if audioUsable {
                    audio = await LocalAudioTrack.createTrack(
                        name: "host_system_audio",
                        options: AudioCaptureOptions(
                            echoCancellation: false,
                            autoGainControl: false,
                            noiseSuppression: false
                        )
                    )
                } else {
                    audio = nil
                }
                var publication: LocalTrackPublication?
                if let audio, audioUsable {
                    publication = try? await room.localParticipant.publish(audioTrack: audio)
                    if publication == nil { audioUsable = false }
                }
                let finalPublication = publication
                let audioReady = audioUsable && finalPublication != nil

                self.queue.async {
                    guard self.started else {
                        Task {
                            try? await room.disconnect()
                        }
                        return
                    }
                    self.room = room
                    self.videoTrack = video
                    self.videoCapturer = video.capturer as? BufferCapturer
                    self.audioTrack = audio
                    self.audioPublication = finalPublication
                    self.audioReady = audioReady
                    self.audioUnavailable = !audioReady
                    if audioReady {
                        self.flushAudioLocked()
                    } else {
                        self.pendingAudio.removeAll()
                    }
                    if let frame = self.pendingVideo {
                        self.pendingVideo = nil
                        self.captureVideoLocked(frame)
                    }
                }
            } catch {
                await room.disconnect()
                self?.queue.async {
                    self?.started = false
                    DispatchQueue.main.async { self?.onFailure?() }
                }
            }
        }
    }

    private var isStarted: Bool {
        queue.sync { started }
    }

    // MARK: - Media

    private func captureVideoLocked(_ sampleBuffer: CMSampleBuffer) {
        guard let capturer = videoCapturer else { return }
        capturer.capture(sampleBuffer)

        guard !videoPublishing, !videoPublished,
              let track = videoTrack, let room,
              room.connectionState == .connected else { return }

        videoPublishing = true
        Task { [weak self] in
            do {
                _ = try await room.localParticipant.publish(videoTrack: track)
                self?.queue.async {
                    self?.videoPublished = true
                    self?.videoPublishing = false
                    self?.videoPublishFailures = 0
                }
            } catch {
                // 失败后下一帧重试；连续失败说明 token/源不对或发布超时，收掉广播
                self?.queue.async {
                    guard let self else { return }
                    self.videoPublishing = false
                    self.videoPublishFailures += 1
                    if self.videoPublishFailures >= 3 {
                        DispatchQueue.main.async { self.onFailure?() }
                    }
                }
            }
        }
    }

    private func flushAudioLocked() {
        guard audioReady, !pendingAudio.isEmpty else { return }
        let buffers = pendingAudio
        pendingAudio.removeAll()
        for buffer in buffers {
            AudioManager.shared.mixer.capture(appAudio: buffer)
        }
    }

    // MARK: - RoomDelegate

    func room(_ room: Room, didUpdateConnectionState connectionState: ConnectionState,
              from oldConnectionState: ConnectionState) {
        switch connectionState {
        case .connected:
            queue.async { [weak self] in
                guard let self, self.audioTrack != nil, self.audioPublication != nil else { return }
                self.audioReady = true
                self.flushAudioLocked()
            }
        case .disconnected, .disconnecting:
            queue.async { [weak self] in self?.audioReady = false }
        default:
            break
        }
    }

    // MARK: - ReplayKit PCM

    /// 把 ReplayKit 的 CMSampleBuffer 原样拷贝成 AVAudioPCMBuffer。
    /// `mixer.capture(appAudio:)` 内部会再做一次格式转换，所以这里保留原始 ASBD
    /// （44.1/48kHz、单/双声道、交错或非交错都支持）。
    private static func pcmBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        else { return nil }

        guard let format = AVAudioFormat(streamDescription: streamDescription) else { return nil }
        let frames = CMSampleBufferGetNumSamples(sampleBuffer)
        guard frames > 0,
              let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))
        else { return nil }

        let channels = max(1, Int(streamDescription.pointee.mChannelsPerFrame))
        let audioBufferList = AudioBufferList.allocate(maximumBuffers: channels)
        defer { free(audioBufferList.unsafeMutablePointer) }

        var blockBuffer: CMBlockBuffer?
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: audioBufferList.unsafeMutablePointer,
            bufferListSize: AudioBufferList.sizeInBytes(maximumBuffers: channels),
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr else { return nil }

        let source = UnsafeMutableAudioBufferListPointer(audioBufferList.unsafeMutablePointer)
        var destination = UnsafeMutableAudioBufferListPointer(pcm.mutableAudioBufferList)
        guard source.count == destination.count else { return nil }

        for index in 0 ..< source.count {
            let sourceBuffer = source[index]
            var destinationBuffer = destination[index]
            guard let sourceData = sourceBuffer.mData,
                  let destinationData = destinationBuffer.mData
            else { return nil }
            let byteCount = Int(sourceBuffer.mDataByteSize)
            guard byteCount > 0 else { continue }
            memcpy(destinationData, sourceData, byteCount)
            destinationBuffer.mDataByteSize = sourceBuffer.mDataByteSize
            destination[index] = destinationBuffer
        }

        pcm.frameLength = AVAudioFrameCount(frames)
        return pcm
    }
}
