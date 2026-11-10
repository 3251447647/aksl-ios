import AVFoundation

/// 系统广播的画面与系统声音由扩展直接发布；主 App 只负责主播麦克风轨与直播间 UI。
/// 主 App 一进后台被挂起就会断麦，这里在共享期间用静音播放占用 audio 后台模式，
/// 让主播麦克风保持在线。停止共享/离开直播间时必须调用 stop()。
final class ScreenShareKeepAlive {
    static let shared = ScreenShareKeepAlive()

    private var player: AVAudioPlayer?

    private init() {}

    func start() {
        guard player == nil, let data = Self.silentWAV() else { return }
        let session = AVAudioSession.sharedInstance()
        // 主播开麦时 LiveKit 已经设成 playAndRecord，不要覆盖，否则会打断采集
        if session.category != .playAndRecord {
            try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        }
        try? session.setActive(true)
        guard let p = try? AVAudioPlayer(data: data) else { return }
        p.numberOfLoops = -1
        p.volume = 0
        p.play()
        player = p
    }

    func stop() {
        player?.stop()
        player = nil
    }

    /// 1 秒 8kHz 单声道 16bit 静音 WAV
    private static func silentWAV() -> Data {
        let sampleRate: UInt32 = 8000
        let channels: UInt16 = 1
        let bits: UInt16 = 16
        let dataSize = Int(sampleRate) * Int(channels) * Int(bits / 8)

        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }

        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16))
        append(UInt16(1))
        append(channels)
        append(sampleRate)
        append(sampleRate * UInt32(channels) * UInt32(bits / 8))
        append(UInt16(channels * bits / 8))
        append(bits)
        data.append(contentsOf: Array("data".utf8))
        append(UInt32(dataSize))
        data.append(Data(count: dataSize))
        return data
    }
}
