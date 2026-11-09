import SwiftUI

/// 统一返回按钮：替代系统「Back」文字
struct BackButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(AKColor.text)
        }
    }
}
