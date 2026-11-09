import SwiftUI

/// 悬浮球：iOS 没有系统级悬浮窗，用应用内可拖动小球替代（点开回到最近会话）
struct FloatingBubble: View {
    @EnvironmentObject private var app: AppState
    /// 归一化位置（-1…1），默认贴右侧中部偏下
    @AppStorage("bubbleX") private var bx: Double = 0.86
    @AppStorage("bubbleY") private var by: Double = 0.62
    @State private var drag: CGSize = .zero
    @State private var dragging = false

    var onTap: () -> Void

    var body: some View {
        GeometryReader { geo in
            let x = (bx * 0.5 + 0.5) * geo.size.width + drag.width
            let y = (by * 0.5 + 0.5) * geo.size.height + drag.height
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(LinearGradient(colors: [AKColor.brand, AKColor.brandDark],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 54, height: 54)
                    .overlay(
                        Text("AK")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 6, y: 2)
                if app.unreadTotal > 0 {
                    Text(app.unreadTotal > 99 ? "99+" : "\(app.unreadTotal)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(AKColor.red)
                        .clipShape(Capsule())
                        .offset(x: 4, y: -4)
                }
            }
            .position(x: x, y: y)
            .gesture(
                DragGesture()
                    .onChanged { v in
                        dragging = true
                        drag = v.translation
                    }
                    .onEnded { v in
                        let nx = (bx * 0.5 + 0.5) * geo.size.width + v.translation.width
                        let ny = (by * 0.5 + 0.5) * geo.size.height + v.translation.height
                        // 吸附到左右两侧，纵向夹在安全范围内
                        bx = (nx < geo.size.width / 2 ? 0.06 : 0.94) * 2 - 1
                        by = max(-0.82, min(0.86, (ny / geo.size.height) * 2 - 1))
                        drag = .zero
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { dragging = false }
                    }
            )
            .onTapGesture {
                if !dragging { onTap() }
            }
        }
    }
}
