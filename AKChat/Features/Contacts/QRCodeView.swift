import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

/// 个人二维码：内容为个人主页链接（user.php?id=），扫码后直接打开资料页。
/// 卡片版式与群二维码同源（白卡 + 头像 + 号码 + 二维码 + 提示语），保存/分享都用整张卡。
struct QRCodeView: View {
    let uid: Int64
    let name: String
    let avatar: String?
    /// 展示用的号码：靓号优先，没有则 AK号
    var number: String = ""
    var isPretty: Bool = false

    @State private var saved = false
    @State private var cardImage: UIImage?

    private var link: String { "https://www.aksliao.cn/user.php?id=\(uid)" }

    private var displayNumber: String {
        if !number.isEmpty { return number }
        return "\(uid)"
    }

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
                VStack(spacing: 0) {
                    card
                        .padding(.horizontal, 18)

                    HStack(spacing: 14) {
                        Button {
                            save()
                        } label: {
                            actionLabel(saved ? "已保存" : "保存", icon: "arrow.down.to.line")
                        }
                        .buttonStyle(.plain)

                        if let img = cardImage {
                            ShareLink(
                                item: Image(uiImage: img),
                                preview: SharePreview("我的二维码", image: Image(uiImage: img))
                            ) {
                                actionLabel("分享", icon: "square.and.arrow.up")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 26)
                }
                .padding(.vertical, 18)
            }
        }
        .background(AKColor.bg)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { renderCard() }
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
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                AvatarView(url: avatar, name: name.isEmpty ? "我" : name, size: 58)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(name.isEmpty ? "我" : name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: 0x1A1D26))
                            .lineLimit(1)
                        if isPretty {
                            Text("靓")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: 0x7A4A00))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color(hex: 0xFFB020))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                    }
                    Text("\(isPretty ? "靓号" : "AK号")：\(displayNumber)")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: 0xB2B2B2))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)

            Rectangle()
                .fill(Color(hex: 0xE8ECF5))
                .frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: 0xF1F3F6))
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.white)
                    .padding(4)
                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(16)
                } else {
                    ProgressView()
                }
            }
            .frame(height: 234)
            .padding(.horizontal, 20)
            .padding(.top, 14)

            Text("扫一扫上面的二维码，加我为好友")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: 0x5B5B5B))
                .padding(.top, 16)
            Text("aksliao.cn")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: 0xA8ADB6))
                .padding(.top, 4)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func actionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 16))
            Text(text).font(.system(size: 14.5))
        }
        .foregroundColor(AKColor.text)
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
    }

    private func renderCard() {
        let width = max(UIScreen.main.bounds.width - 36, 240)
        let renderer = ImageRenderer(content: card.frame(width: width))
        renderer.scale = 720 / width
        cardImage = renderer.uiImage
    }

    private func save() {
        guard let img = cardImage else { return }
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        saved = true
    }
}
