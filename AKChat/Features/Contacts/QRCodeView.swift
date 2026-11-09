import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

/// 个人二维码：内容为个人主页链接，扫码后可直接打开主页
struct QRCodeView: View {
    let uid: Int64
    let name: String
    let avatar: String?

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
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 14) {
                    card
                    Text("扫一扫上面的二维码，加我为好友")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.muted)
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
                            .frame(height: 46)
                            .background(AKColor.brand)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
        }
        .background(AKColor.bg)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 0) {
            BackButton()
                .frame(width: 34, height: 34)
            Spacer(minLength: 0)
        }
        .overlay(
            Text("我的二维码")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AKColor.text)
        )
        .padding(.horizontal, 8)
        .frame(height: 46)
        .frame(maxWidth: .infinity)
        .background(AKColor.card)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AKColor.line).frame(height: 0.5)
        }
    }

    private var card: some View {
        VStack(spacing: 14) {
            if let avatar, let u = APIClient.fullURL(avatar) {
                AsyncImage(url: u) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    AKColor.fill
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Text(name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AKColor.text)
                .lineLimit(1)

            Text("AK号 \(uid)")
                .font(.system(size: 11.5))
                .foregroundColor(AKColor.gold)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(AKColor.goldSoft)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if let qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 230, height: 230)
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
