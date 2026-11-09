import SwiftUI
import AVFoundation
import CoreImage
import PhotosUI
import UIKit

/// 二维码内容归类：群 / 用户 / 普通链接 / 其它文本（对齐安卓 QrCode.kt parseQrTarget）
enum QrTarget {
    case group(Int64)
    case user(Int64)
    case url(String)
    case text(String)

    /// 站点二维码是 `group_info.php?gid=X` 与 `user.php?id=X`，按参数与路径识别
    static func parse(_ raw: String) -> QrTarget {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()

        if lower.contains("group_info") || lower.contains("group_share") || lower.contains("group_chat"),
           let gid = value(in: text, names: ["gid"]), gid > 0 {
            return .group(gid)
        }
        if lower.contains("user.php"),
           let uid = value(in: text, names: ["id", "uid"]), uid > 0 {
            return .user(uid)
        }
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return .url(text)
        }
        if lower.hasPrefix("www.") {
            return .url("http://" + text)
        }
        return .text(text)
    }

    private static func value(in text: String, names: [String]) -> Int64? {
        for name in names {
            let pattern = "[?&#]" + name + "=(\\d+)"
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                return Int64(text[range])
            }
        }
        return nil
    }

    /// 结果卡文案
    var desc: String {
        switch self {
        case .group: return "群聊二维码，可加入群聊"
        case .user: return "用户二维码，可查看主页"
        case .url(let url): return url
        case .text(let text): return text
        }
    }

    var actionTitle: String {
        switch self {
        case .group: return "进群"
        case .user: return "查看主页"
        case .url: return "打开链接"
        case .text: return "复制内容"
        }
    }
}

/// 扫一扫：相机预览 + 相册识别 + 结果卡（对齐安卓 ScanScreen）
struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// 保留外部回调：用户二维码交给调用方打开资料页
    var onResult: (String) -> Void = { _ in }

    @State private var authorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    @State private var result: String?
    @State private var scanned = false
    @State private var torchOn = false
    @State private var decodingAlbum = false
    @State private var scanGen = 0
    @State private var albumItem: PhotosPickerItem?
    @State private var showAlbumPicker = false
    @State private var toastText: String?
    @State private var groupTarget: Int64?
    @State private var showGroup = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if authorized {
                    ScannerPreview(
                        onCode: { code in
                            guard !scanned else { return }
                            scanned = true
                            result = code
                        },
                        torch: torchOn,
                        scanGen: scanGen
                    )
                    .ignoresSafeArea()
                }

                if authorized && result == nil {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(hex: 0xFFFFFF, alpha: 0.06))
                        .frame(width: 240, height: 240)
                }

                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 0)
                    if let text = result {
                        resultCard(text)
                    } else {
                        Text(authorized ? "将二维码放入框内，即可自动识别" : "需要相机权限才能扫码")
                            .font(.system(size: 12.5))
                            .foregroundColor(Color.white.opacity(0.8))
                        if !authorized {
                            Button {
                                requestCamera()
                            } label: {
                                Text("授权相机")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 9)
                                    .background(AKColor.brand)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 18)
                        }
                    }
                    Color.clear.frame(height: 40)
                }
            }
            .background(Color.black)
            .overlay(alignment: .bottom) { toastView }
            .toolbar(.hidden, for: .navigationBar)
            .photosPicker(isPresented: $showAlbumPicker, selection: $albumItem, matching: .images)
            .onChange(of: albumItem) { item in
                guard let item else { return }
                decodeAlbum(item)
            }
            .task {
                if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
                    requestCamera()
                }
            }
            .navigationDestination(isPresented: $showGroup) {
                if let gid = groupTarget {
                    GroupPreviewView(groupId: gid).restoresSwipeBack()
                }
            }
        }
    }

    // MARK: - 顶部

    private var topBar: some View {
        HStack(spacing: 6) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Text("扫一扫")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)

            Button {
                guard !decodingAlbum else { return }
                showAlbumPicker = true
            } label: {
                Text(decodingAlbum ? "识别中…" : "相册")
                    .font(.system(size: 12.5))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Color(hex: 0x000000, alpha: 0.4))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(decodingAlbum)

            Button {
                torchOn.toggle()
            } label: {
                Image(systemName: torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                    .font(.system(size: 16))
                    .foregroundColor(torchOn ? Color(hex: 0xFFD60A) : .white)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
    }

    // MARK: - 结果卡

    private func resultCard(_ text: String) -> some View {
        let target = QrTarget.parse(text)
        return VStack(alignment: .leading, spacing: 0) {
            Text("识别结果")
                .font(.system(size: 12))
                .foregroundColor(AKColor.hint)
            Text(target.desc)
                .font(.system(size: 14))
                .foregroundColor(AKColor.text)
                .lineLimit(3)
                .padding(.top, 6)

            HStack(spacing: 10) {
                Button {
                    result = nil
                    scanned = false
                    scanGen += 1
                } label: {
                    Text("继续扫描")
                        .font(.system(size: 13.5))
                        .foregroundColor(AKColor.sub)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(AKColor.fill)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    open(target, raw: text)
                } label: {
                    Text(target.actionTitle)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(AKColor.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 14)
        }
        .padding(16)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func open(_ target: QrTarget, raw: String) {
        switch target {
        case .group(let gid):
            groupTarget = gid
            showGroup = true
        case .user:
            onResult(raw)
            dismiss()
        case .url(let url):
            if let u = URL(string: url) {
                dismiss()
                openURL(u)
            } else {
                showToast("无法打开链接")
            }
        case .text(let text):
            UIPasteboard.general.string = text
            showToast("内容已复制")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                dismiss()
            }
        }
    }

    // MARK: - 相册识别

    private func decodeAlbum(_ item: PhotosPickerItem) {
        decodingAlbum = true
        Task { @MainActor in
            defer {
                decodingAlbum = false
                albumItem = nil
            }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let code = Self.decode(image) else {
                showToast("未识别到二维码")
                return
            }
            scanned = true
            result = code
        }
    }

    /// 深色底的码（夜间模式截图）翻转后再试一次
    private static func decode(_ image: UIImage) -> String? {
        guard let cg = image.cgImage else { return nil }
        let detector = CIDetector(ofType: CIDetectorTypeQRCode,
                                  context: nil,
                                  options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        func scan(_ image: CIImage) -> String? {
            let features = detector?.features(in: image) as? [CIQRCodeFeature]
            return features?.first?.messageString
        }
        let source = CIImage(cgImage: cg)
        if let text = scan(source) { return text }
        guard let inverted = CIFilter(name: "CIColorInvert",
                                      parameters: [kCIInputImageKey: source])?.outputImage else {
            return nil
        }
        return scan(inverted)
    }

    // MARK: - 权限

    private func requestCamera() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                authorized = granted
            }
        }
    }

    // MARK: - Toast

    private var toastView: some View {
        Group {
            if let toastText {
                Text(toastText)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color(hex: 0x1A1D26, alpha: 0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.bottom, 120)
            }
        }
    }

    private func showToast(_ message: String) {
        toastText = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if toastText == message { toastText = nil }
        }
    }
}

private struct ScannerPreview: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    let torch: Bool
    let scanGen: Int

    func makeUIViewController(context: Context) -> ScannerController {
        let c = ScannerController()
        c.onCode = onCode
        return c
    }

    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {
        uiViewController.onCode = onCode
        uiViewController.setTorch(torch)
        uiViewController.resume(scanGen)
    }
}

final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?
    private var device: AVCaptureDevice?
    private var lastGen = -1

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        self.device = device
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        preview = layer

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
        setTorch(false)
    }

    func setTorch(_ on: Bool) {
        guard let device, device.hasTorch, device.torchMode != (on ? .on : .off) else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }

    /// 结果卡点「继续扫描」时重新开流
    func resume(_ gen: Int) {
        guard gen != lastGen else { return }
        lastGen = gen
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        session.stopRunning()
        onCode?(value)
    }
}
