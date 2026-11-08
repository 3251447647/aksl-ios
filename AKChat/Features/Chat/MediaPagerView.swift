import SwiftUI
import UIKit

/// 多图查看器：左右滑动切换、支持缩放与保存（对齐安卓 MediaPager）
struct PreviewImage: Identifiable {
    let id = UUID()
    let urls: [URL]
    let index: Int
}

struct MediaPagerView: View {
    let urls: [URL]
    @State private var index: Int
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var saved = false

    init(urls: [URL], index: Int) {
        self.urls = urls
        _index = State(initialValue: max(0, min(index, max(0, urls.count - 1))))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(urls.enumerated()), id: \.offset) { i, u in
                    AsyncImage(url: u) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFit()
                                .scaleEffect(i == index ? scale : 1)
                                .gesture(
                                    MagnificationGesture()
                                        .onChanged { v in scale = min(max(v, 1), 4) }
                                        .onEnded { _ in if scale < 1.05 { scale = 1 } }
                                )
                        } else {
                            ProgressView().tint(.white)
                        }
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: index) { _ in scale = 1 }

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(14)
                    }
                    Spacer()
                    if urls.count > 1 {
                        Text("\(index + 1)/\(urls.count)")
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .padding(.trailing, 16)
                    }
                }
                Spacer()
                Button {
                    Task { await saveCurrent() }
                } label: {
                    Text(saved ? "已保存" : "保存图片")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .frame(height: 40)
                        .background(Color.white.opacity(0.16))
                        .clipShape(Capsule())
                }
                .padding(.bottom, 28)
            }
        }
        .statusBarHidden(true)
    }

    private func saveCurrent() async {
        guard index < urls.count else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: urls[index]),
              let img = UIImage(data: data) else { return }
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        saved = true
    }
}
