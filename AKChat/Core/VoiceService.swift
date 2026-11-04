import Foundation
import AVFoundation

final class VoiceService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var recording = false
    @Published var playingURL: String?

    /// 语音正文是「url|#|{"duration":n}」，播放前只取 url
    static func cleanPath(_ raw: String) -> String {
        raw.components(separatedBy: "|#|").first ?? raw
    }

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var startedAt: Date?

    func startRecording() async -> Bool {
        let granted: Bool = await withCheckedContinuation { cont in
            AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
        }
        guard granted else { return false }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("voice_\(Int(Date().timeIntervalSince1970)).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.record()
            recorder = rec
            startedAt = Date()
            recording = true
            return true
        } catch {
            return false
        }
    }

    /// 停止录音，返回 (本地文件, 秒数)
    func stopRecording() -> (URL, Int)? {
        guard let rec = recorder else { return nil }
        let seconds = max(1, Int(Date().timeIntervalSince(startedAt ?? Date())))
        rec.stop()
        recorder = nil
        recording = false
        startedAt = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return (rec.url, seconds)
    }

    func play(path: String) {
        guard let url = APIClient.fullURL(path) else { return }
        playingURL = path
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data else { return }
            DispatchQueue.main.async {
                self?.player = try? AVAudioPlayer(data: data)
                self?.player?.delegate = self
                self?.player?.play()
            }
        }.resume()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playingURL = nil
    }
}
