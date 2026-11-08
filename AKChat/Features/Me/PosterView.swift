import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

/// 个人海报：头像 + 昵称 + AK号/靓号 + 二维码，可保存到相册或分享（对齐安卓 PosterScreen）
struct PosterView: View {
    let name: String
    let avatar: String?
    let number: String
    let uid: Int64

    @Environment(\.dismiss) private var dismiss
    @State private var avatarImage: UIImage?
    @State private var saved = false
    @State private var showShare = false

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
        VStack(spacing: 16) {
            ScrollView {
                VStack(spacing: 14) {
                    if let qr = qrImage(link) {
                        VStack(spacing: 12) {
                            if let avatarImage {
                                Image(uiImage: avatarImage)
                                    .resizable().scaledToFill()
                                    .frame(width: 62, height: 62)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            } else {
                                AvatarView(url: avatar, name: name, size: 62)
                            }
                            Text(name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(AKColor.text)
                            Text("AK号：\(number)")
                                .font(.system(size: 12.5))
                                .foregroundColor(AKColor.muted)
                            Image(uiImage: qr)
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 190, height: 190)
                            Text("扫码加我，一起聊")
                                .font(.system(size: 12))
                                .foregroundColor(AKColor.hint)
                        }
                        .padding(22)
                        .frame(maxWidth: .infinity)
                        .background(AKColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .padding(16)
            }

            HStack(spacing: 10) {
                Button {
                    Task { await savePoster() }
                } label: {
                    Text(saved ? "已保存" : "保存海报")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(AKColor.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                Button {
                    showShare = true
                } label: {
                    Text("分享")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AKColor.text)
                        .frame(width: 96)
                        .frame(height: 44)
                        .background(AKColor.fill)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .navigationTitle("我的海报")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadAvatar() }
        .sheet(isPresented: $showShare) {
            if let img = renderPoster() {
                ShareSheet(items: [img])
            }
        }
    }

    private func loadAvatar() async {
        guard let u = APIClient.fullURL(avatar), avatarImage == nil else { return }
        if let (data, _) = try? await URLSession.shared.data(from: u) {
            avatarImage = UIImage(data: data)
        }
    }

    private func renderPoster() -> UIImage? {
        let content = VStack(spacing: 12) {
            if let avatarImage {
                Image(uiImage: avatarImage)
                    .resizable().scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            Text(name).font(.system(size: 20, weight: .semibold)).foregroundColor(.black)
            Text("AK号：\(number)").font(.system(size: 13)).foregroundColor(.gray)
            if let qr = qrImage(link, scale: 12) {
                Image(uiImage: qr).interpolation(.none).resizable().frame(width: 220, height: 220)
            }
            Text("扫码加我，一起聊").font(.system(size: 13)).foregroundColor(.gray)
        }
        .padding(28)
        .frame(width: 360)
        .background(Color.white)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        return renderer.uiImage
    }

    private func savePoster() async {
        await loadAvatar()
        guard let img = renderPoster() else { return }
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
