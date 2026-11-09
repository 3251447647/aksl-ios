import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

/// 个人海报：头像 + 昵称 + AK号/靓号 + 二维码，整张卡保存到相册（对齐安卓 PosterScreen）
struct PosterView: View {
    let name: String
    let avatar: String?
    let number: String
    let uid: Int64

    @Environment(\.dismiss) private var dismiss
    @State private var avatarImage: UIImage?
    @State private var cardImage: UIImage?
    @State private var saved = false

    private var link: String { "https://www.aksliao.cn/user.php?id=\(uid)" }

    private func qrImage(_ text: String, scale: CGFloat = 10) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let out = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) else { return nil }
        guard let cg = CIContext().createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                posterCard
                    .padding(14)
            }
            actionBar
        }
        .background(AKColor.bg.ignoresSafeArea())
        .reportsDetailPage()
        .navigationTitle("邀请海报")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAvatar()
            renderCard()
        }
    }

    // MARK: - 海报

    private var posterCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("AK商聊")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text("扫码加我，一起聊")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(
                LinearGradient(colors: [Color(hex: 0x2FBE6E), Color(hex: 0x1FA45B)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )

            VStack(spacing: 0) {
                ZStack(alignment: .bottomTrailing) {
                    if let avatarImage {
                        Image(uiImage: avatarImage)
                            .resizable().scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    } else {
                        AvatarView(url: avatar, name: name, size: 72)
                    }
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: 0x2FBE6E))
                        .background(Circle().fill(Color.white).frame(width: 17, height: 17))
                }
                .padding(3)
                .background(AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                .padding(.top, -40)

                Text(name)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AKColor.text)
                    .padding(.top, 10)

                Text("AK号：\(number)")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.muted)
                    .padding(.top, 5)

                if let qr = qrImage(link) {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 190, height: 190)
                        .padding(10)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.top, 16)
                }

                Text("长按识别二维码，添加我为好友")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.hint)
                    .padding(.top, 12)

                Rectangle()
                    .fill(AKColor.line)
                    .frame(height: 0.5)
                    .padding(.horizontal, 56)
                    .padding(.top, 16)

                Text("AK商聊 · 让沟通更有温度")
                    .font(.system(size: 10.5))
                    .foregroundColor(AKColor.placeholder)
                    .padding(.top, 10)
                    .padding(.bottom, 18)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(AKColor.card)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - 底部操作

    private var actionBar: some View {
        Button {
            savePoster()
        } label: {
            Text(cardImage == nil ? "正在生成海报…" : (saved ? "已保存到相册" : "↓  保存到相册"))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: cardImage == nil
                            ? [Color(hex: 0xB7C0C8), Color(hex: 0xA5AEB8)]
                            : [Color(hex: 0x43C463), Color(hex: 0x2FA84F)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(cardImage == nil)
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(AKColor.bg)
    }

    private func loadAvatar() async {
        guard let u = APIClient.fullURL(avatar), avatarImage == nil else { return }
        if let (data, _) = try? await URLSession.shared.data(from: u) {
            avatarImage = UIImage(data: data)
        }
    }

    private func renderCard() {
        let width = max(UIScreen.main.bounds.width - 28, 280)
        let renderer = ImageRenderer(content: posterCard.frame(width: width))
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
