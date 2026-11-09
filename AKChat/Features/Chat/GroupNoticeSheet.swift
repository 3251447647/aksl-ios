import SwiftUI

/// 进群时的群公告弹窗：居中悬浮卡片，必须点「我已知晓」才算确认
/// 结构对齐安卓 GroupNoticeSheet.kt：群头像 + 群名 + 「群公告」标 → 正文 → 三列配图 → 渐变确认按钮 → 查看群资料
struct GroupNoticePopup: View {
    let notice: GroupNotice?
    let onClose: () -> Void
    var groupName: String = ""
    var groupAvatar: String? = nil
    var onOpenProfile: (() -> Void)? = nil

    private var images: [String] { notice?.imageList ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                AvatarView(url: groupAvatar, name: groupName.isEmpty ? "群聊" : groupName, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(groupName.isEmpty ? "群公告" : groupName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AKColor.text)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(AKColor.gold)
                            Image(systemName: "megaphone.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.white)
                        }
                        .frame(width: 16, height: 16)
                        Text("群公告")
                            .font(.system(size: 11.5))
                            .foregroundColor(AKColor.gold)
                    }
                }
                Spacer(minLength: 0)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text((notice?.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                         ? "暂无公告" : (notice?.content ?? ""))
                        .font(.system(size: 14))
                        .lineSpacing(8)
                        .foregroundColor(AKColor.text)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !images.isEmpty {
                        NoticeImageGrid(paths: Array(images.prefix(9)), size: 72, spacing: 5, corners: 8)
                            .contentShape(Rectangle())
                            .onTapGesture { onOpenProfile?() }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 300)
            .padding(14)
            .background(AKColor.fill)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.top, 14)

            Button(action: onClose) {
                Text("我已知晓")
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        LinearGradient(
                            colors: [AKColor.brand, Color(hex: 0x06AD56)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 16)

            Button {
                onOpenProfile?()
            } label: {
                Text("查看群资料")
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.hint)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: 360)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 24)
    }
}
