import SwiftUI

/// 安卓式导航栏：返回箭头 + 居中标题 + 右侧操作，替代 iOS 系统导航栏
struct AKNavBar<Right: View>: View {
    let title: String
    let onBack: () -> Void
    var right: (() -> Right)? = nil

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AKColor.text)
                .lineLimit(1)
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AKColor.text)
                        .frame(width: 34, height: 34)
                }
                Spacer()
                if let right {
                    right()
                } else {
                    Color.clear.frame(width: 34, height: 34)
                }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 46)
        .frame(maxWidth: .infinity)
        .background(AKColor.card)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AKColor.line).frame(height: 0.5)
        }
    }
}

/// 一个通用包装：隐藏系统导航栏 + 自绘头部 + 内容
struct AKPage<Content: View, Right: View>: View {
    let title: String
    @Environment(\.dismiss) private var dismiss
    var right: (() -> Right)? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            AKNavBar(title: title, onBack: { dismiss() }, right: right)
            content()
        }
        .background(AKColor.bg.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}
