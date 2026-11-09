import SwiftUI
import UIKit

struct GroupQRData: Decodable {
    let gid: Int64
    let name: String
    let avatar: String
    let groupNo: String
    let isPretty: Int
    let prettyNo: String
    let memberCount: Int
    let qrUrl: String

    enum CodingKeys: String, CodingKey {
        case gid, name, avatar
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
    }
}

/// 群二维码名片：扫码可进群（对齐安卓 GroupQrScreen：卡片 + 保存/分享双按钮）
struct GroupQRCodeView: View {
    let groupId: Int64

    @State private var data: GroupQRData?
    @State private var qrImage: UIImage?
    @State private var errorText: String?
    @State private var saved = false

    private var displayNo: String {
        guard let d = data else { return "" }
        if d.isPretty == 1, !d.prettyNo.isEmpty { return d.prettyNo }
        return d.groupNo
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
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            AvatarView(url: d.avatar, name: d.name, size: 56)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(d.name)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(d.isPretty == 1 ? AKColor.gold : AKColor.text)
                                        .lineLimit(1)
                                    if d.isPretty == 1 {
                                        PrettyBadge(number: d.prettyNo, isGroup: true)
                                    }
                                }
                                Text("群号 \(displayNo.isEmpty ? "\(d.gid)" : displayNo) · \(d.memberCount) 人")
                                    .font(.system(size: 12))
                                    .foregroundColor(AKColor.hint)
                            }
                            Spacer(minLength: 0)
                        }

                        if let qrImage {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 220, height: 220)
                                .padding(10)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        } else {
                            ProgressView().frame(width: 220, height: 220)
                        }

                        Text("扫一扫上面的二维码，加入群聊")
                            .font(.system(size: 12))
                            .foregroundColor(AKColor.hint)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity)
                    .background(AKColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 18)

                    HStack(spacing: 14) {
                        Button {
                            if let qrImage {
                                UIImageWriteToSavedPhotosAlbum(qrImage, nil, nil, nil)
                                saved = true
                            }
                        } label: {
                            actionLabel(saved ? "已保存" : "保存", icon: "arrow.down.to.line")
                        }
                        .buttonStyle(.plain)
                        .disabled(qrImage == nil)

                        if let qrImage {
                            ShareLink(
                                item: Image(uiImage: qrImage),
                                preview: SharePreview("群二维码", image: Image(uiImage: qrImage))
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

    private func load() async {
        do {
            let d: GroupQRData = try await APIClient.shared.get("api/v1/group/qrcode", query: ["id": "\(groupId)"])
            data = d
            if let u = APIClient.fullURL(d.qrUrl) {
                if let (bytes, _) = try? await URLSession.shared.data(from: u), let img = UIImage(data: bytes) {
                    qrImage = img
                }
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}
