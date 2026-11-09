import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

struct GroupQRData: Decodable {
    let gid: Int64
    let name: String
    let avatar: String
    let groupNo: String
    let isPretty: Int
    let prettyNo: String
    let memberCount: Int
    let qrUrl: String
    let content: String

    enum CodingKeys: String, CodingKey {
        case gid, name, avatar, content
        case groupNo = "group_no"
        case isPretty = "is_pretty"
        case prettyNo = "pretty_no"
        case memberCount = "member_count"
        case qrUrl = "qr_url"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gid = (try? c.decode(Int64.self, forKey: .gid)) ?? 0
        name = (try? c.decode(String.self, forKey: .name)) ?? "群聊"
        avatar = (try? c.decode(String.self, forKey: .avatar)) ?? ""
        groupNo = (try? c.decode(String.self, forKey: .groupNo)) ?? ""
        isPretty = (try? c.decode(Int.self, forKey: .isPretty)) ?? 0
        prettyNo = (try? c.decode(String.self, forKey: .prettyNo)) ?? ""
        memberCount = (try? c.decode(Int.self, forKey: .memberCount)) ?? 0
        qrUrl = (try? c.decode(String.self, forKey: .qrUrl)) ?? ""
        content = (try? c.decode(String.self, forKey: .content)) ?? ""
    }
}

/// 群二维码页：整张分享卡（头像 + 群名 + 靓号标 + 群号 + 二维码 + 提示语），保存/分享都用这张
/// 版式对齐安卓 GroupQrCard.kt（720×1000 白卡）
struct GroupQRCodeView: View {
    let groupId: Int64

    @State private var data: GroupQRData?
    @State private var qrImage: UIImage?
    @State private var cardImage: UIImage?
    @State private var errorText: String?
    @State private var saved = false

    private var displayNo: String {
        guard let d = data else { return "" }
        if d.isPretty == 1, !d.prettyNo.isEmpty { return d.prettyNo }
        return d.groupNo.isEmpty ? "\(d.gid)" : d.groupNo
    }

    private var site: String {
        guard let d = data, let u = URL(string: d.content), let host = u.host, !host.isEmpty else {
            return "aksliao.cn"
        }
        return host
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let errorText {
                    Text(errorText)
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.red)
                        .padding(.bottom, 12)
                }
                if let d = data {
                    GroupQrCardView(
                        name: d.name,
                        groupNo: displayNo,
                        isPretty: d.isPretty == 1 && !d.prettyNo.isEmpty,
                        avatar: d.avatar,
                        qr: qrImage,
                        site: site
                    )
                    .padding(.horizontal, 18)

                    HStack(spacing: 14) {
                        Button {
                            if let img = cardImage {
                                UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                                saved = true
                            }
                        } label: {
                            actionLabel(saved ? "已保存" : "保存", icon: "arrow.down.to.line")
                        }
                        .buttonStyle(.plain)
                        .disabled(cardImage == nil)

                        if let img = cardImage {
                            ShareLink(
                                item: Image(uiImage: img),
                                preview: SharePreview("群二维码", image: Image(uiImage: img))
                            ) {
                                actionLabel("分享", icon: "square.and.arrow.up")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 26)
                } else if errorText == nil {
                    ProgressView().padding(.top, 40)
                }
            }
            .padding(.vertical, 18)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .reportsDetailPage()
        .navigationTitle("群二维码")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
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

    private func renderCard(width: CGFloat) {
        guard let d = data, width > 0 else { return }
        let view = GroupQrCardView(
            name: d.name,
            groupNo: displayNo,
            isPretty: d.isPretty == 1 && !d.prettyNo.isEmpty,
            avatar: d.avatar,
            qr: qrImage,
            site: site
        )
        .frame(width: width)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 720 / width
        if let image = renderer.uiImage {
            cardImage = image
        }
    }

    private func load() async {
        do {
            let d: GroupQRData = try await APIClient.shared.get("api/v1/group/qrcode", query: ["id": "\(groupId)"])
            data = d
            qrImage = GroupQrCode.image(content: d.content)
            if qrImage == nil, let u = APIClient.fullURL(d.qrUrl),
               let (bytes, _) = try? await URLSession.shared.data(from: u),
               let img = UIImage(data: bytes) {
                qrImage = img
            }
            errorText = nil
            renderCard(width: max(UIScreen.main.bounds.width - 36, 240))
        } catch {
            errorText = error.localizedDescription
        }
    }
}

/// 720×1000 比例的群二维码分享卡
struct GroupQrCardView: View {
    let name: String
    let groupNo: String
    let isPretty: Bool
    let avatar: String
    let qr: UIImage?
    let site: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                AvatarView(url: avatar, name: name.isEmpty ? "群聊" : name, size: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(name.isEmpty ? "群聊" : name)
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
                    Text("群号：\(groupNo.isEmpty ? "-" : groupNo)")
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
                if let qr {
                    Image(uiImage: qr)
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

            Text("扫一扫二维码，加入群聊")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: 0x5B5B5B))
                .padding(.top, 16)
            Text(site)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: 0xA8ADB6))
                .padding(.top, 4)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

enum GroupQrCode {
    /// 本地编码二维码（与安卓一致：优先用接口返回的 content 本地生成）
    static func image(content: String) -> UIImage? {
        guard !content.isEmpty else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(content.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
