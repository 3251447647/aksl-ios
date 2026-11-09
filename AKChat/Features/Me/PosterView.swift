import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

/// 邀请海报：品牌绿渐变 + 头像/昵称 + 大号邀请码 + 带 logo 的二维码。
/// 画布固定 360×540（=1080×1620，2:3），预览等比缩放，保存按 3x 渲染。
struct PosterView: View {
    let name: String
    let avatar: String?
    let number: String
    let uid: Int64

    @State private var avatarImage: UIImage?
    @State private var qrImage: UIImage?
    @State private var cardImage: UIImage?
    @State private var saved = false
    @State private var showShare = false

    private let canvasW: CGFloat = 360
    private let canvasH: CGFloat = 540
    private let qrCardSide: CGFloat = 228
    private let qrSide: CGFloat = 192

    private var inviteCode: String {
        number.isEmpty ? "\(uid)" : number
    }

    /// 二维码内容仍是邀请链接，只是海报上不显示裸网址
    private var inviteLink: String {
        "https://www.aksliao.cn/register.php?invite=\(inviteCode)"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                posterPreview
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 20)
            }
            actionBar
        }
        .background(AKColor.bg.ignoresSafeArea())
        .reportsDetailPage()
        .navigationTitle("邀请海报")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let qr = qrImage ?? makeQR(inviteLink)
            qrImage = qr
            let image = await loadAvatar()
            renderPoster(avatar: image, qr: qr)
        }
        .sheet(isPresented: $showShare) {
            if let img = cardImage {
                ShareSheet(items: [img])
            }
        }
    }

    // MARK: - 预览

    private var posterPreview: some View {
        let width = min(UIScreen.main.bounds.width - 28, 420)
        let height = width * canvasH / canvasW
        return posterCanvas(avatar: avatarImage, qr: qrImage)
            .frame(width: canvasW, height: canvasH)
            .scaleEffect(width / canvasW)
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.14), radius: 12, y: 6)
            .frame(maxWidth: .infinity)
    }

    // MARK: - 海报画布（360×540）

    private func posterCanvas(avatar image: UIImage?, qr: UIImage?) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x07C160), Color(hex: 0x0AA855)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 260, height: 260)
                .offset(x: 130, y: -212)
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 300, height: 300)
                .offset(x: -150, y: 236)

            VStack(spacing: 0) {
                brandHeader
                avatarView(image)
                    .padding(.top, 12)
                Text(name.isEmpty ? "我" : name)
                    .font(.system(size: 17.5, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 48)
                    .padding(.top, 9)
                Text("AK号 \(inviteCode)")
                    .font(.system(size: 11.5))
                    .foregroundColor(.white.opacity(0.82))
                    .padding(.top, 3)

                Spacer(minLength: 10)

                inviteCodeBlock

                Spacer(minLength: 10)

                qrCard(qr)

                Text("扫码注册 AK商聊，添加我为好友")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.92))
                    .padding(.top, 12)
                    .padding(.bottom, 18)
            }
            .padding(.top, 18)
        }
        .frame(width: canvasW, height: canvasH)
        .clipped()
    }

    private var brandHeader: some View {
        VStack(spacing: 4) {
            HStack(spacing: 7) {
                Image("Logo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: Color.black.opacity(0.12), radius: 3, y: 1)
                Text("AK商聊")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
            }
            Text("让沟通更有温度")
                .font(.system(size: 9.5))
                .tracking(2)
                .foregroundColor(.white.opacity(0.72))
        }
    }

    private func avatarView(_ image: UIImage?) -> some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color(hex: 0x3FD584), Color(hex: 0x0B8F49)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Text(String((name.isEmpty ? "我" : name).prefix(1)))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white, lineWidth: 2))
        .shadow(color: Color.black.opacity(0.16), radius: 6, y: 3)
    }

    private var inviteCodeBlock: some View {
        VStack(spacing: 5) {
            Text("邀请码")
                .font(.system(size: 10, weight: .medium))
                .tracking(3)
                .foregroundColor(.white.opacity(0.72))
            Text(inviteCode)
                .font(.system(size: 34, weight: .bold))
                .tracking(2)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .padding(.horizontal, 24)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.16)))
                .overlay(
                    Capsule().stroke(Color(hex: 0xFFD86B).opacity(0.5), lineWidth: 1)
                )
        }
    }

    private func qrCard(_ qr: UIImage?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
            if let qr {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: qrSide, height: qrSide)
                    .overlay(qrLogoBadge)
            } else {
                ProgressView().tint(AKColor.brand)
            }
        }
        .frame(width: qrCardSide, height: qrCardSide)
        .shadow(color: Color.black.opacity(0.12), radius: 10, y: 5)
    }

    /// 白底圆角块 + 本站 Logo：边长 = 二维码宽度 22%，圆角 8，居中不压定位角
    private var qrLogoBadge: some View {
        let side = qrSide * 0.22
        return ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white)
            Image("Logo")
                .resizable()
                .scaledToFill()
                .frame(width: side - 8, height: side - 8)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .frame(width: side, height: side)
        .shadow(color: Color.black.opacity(0.12), radius: 2)
    }

    // MARK: - 底部操作

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                savePoster()
            } label: {
                actionLabel(saved ? "已保存到相册" : "保存到相册",
                            icon: "arrow.down.to.line",
                            primary: true)
            }
            .buttonStyle(.plain)
            .disabled(cardImage == nil)

            Button {
                showShare = true
            } label: {
                actionLabel("分享", icon: "square.and.arrow.up", primary: false)
            }
            .buttonStyle(.plain)
            .disabled(cardImage == nil)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(AKColor.bg)
    }

    private func actionLabel(_ text: String, icon: String, primary: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
            Text(text).font(.system(size: 15.5, weight: .semibold))
        }
        .foregroundColor(primary ? .white : AKColor.brand)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(
            Group {
                if primary {
                    LinearGradient(
                        colors: [AKColor.brand, AKColor.brandDark],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                } else {
                    AKColor.card
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(primary ? Color.clear : AKColor.brand, lineWidth: 1.2)
        )
        .opacity(cardImage == nil ? 0.55 : 1)
    }

    // MARK: - 数据 / 渲染

    private func loadAvatar() async -> UIImage? {
        if let avatarImage { return avatarImage }
        guard let url = APIClient.fullURL(avatar) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        let image = UIImage(data: data)
        avatarImage = image
        return image
    }

    /// 二维码按 720px 编码，画到 192pt（3x=576px）后仍是缩小采样，边缘清晰
    private func makeQR(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "H"
        guard let output = filter.outputImage else { return nil }
        let scale = 720 / max(output.extent.width, 1)
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    private func renderPoster(avatar image: UIImage?, qr: UIImage?) {
        let content = posterCanvas(avatar: image, qr: qr)
            .frame(width: canvasW, height: canvasH)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        cardImage = renderer.uiImage
    }

    private func savePoster() {
        guard let img = cardImage else { return }
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        saved = true
    }
}

/// 系统分享面板
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
