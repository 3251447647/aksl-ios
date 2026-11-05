import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

/// 个人二维码：内容为个人主页链接，扫码后可直接打开主页
struct QRCodeView: View {
    let uid: Int64
    let name: String
    let avatar: String?

    @Environment(\.dismiss) private var dismiss
    @State private var saved = false

    private var link: String { "https://www.aksliao.cn/user.php?id=\(uid)" }

    private var qrImage: UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(link.utf8)
        filter.correctionLevel = "M"
        guard let out = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)) else {
            return nil
        }
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Spacer(minLength: 10)

                VStack(spacing: 14) {
                    if let avatar, let u = APIClient.fullURL(avatar) {
                        AsyncImage(url: u) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            AKColor.fill
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Text(name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AKColor.text)

                    if let qrImage {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 230, height: 230)
                            .padding(14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Text("AK号 \(uid)")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.sub)
                }
                .padding(22)
                .frame(maxWidth: .infinity)
                .background(AKColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 28)

                Text("扫一扫上面的二维码，加我为好友")
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.muted)

                Spacer()

                Button {
                    if let qrImage {
                        UIImageWriteToSavedPhotosAlbum(qrImage, nil, nil, nil)
                        saved = true
                    }
                } label: {
                    Text(saved ? "已保存到相册" : "保存二维码")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(AKColor.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
            .background(AKColor.bg)
            .navigationTitle("我的二维码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
