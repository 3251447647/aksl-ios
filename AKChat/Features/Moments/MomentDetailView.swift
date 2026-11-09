import SwiftUI

/// 朋友圈详情：与列表同一张动态卡片 + 底部评论条（对齐安卓 MomentDetailScreen）
struct MomentDetailView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @FocusState private var composing: Bool

    let moment: Moment

    @State private var text = ""
    @State private var sending = false
    @State private var previewBox: URLBox?

    /// 点赞/评论后 AppState 会重新拉列表，这里始终渲染最新一条
    private var current: Moment {
        app.moments.first { $0.id == moment.id } ?? moment
    }

    private var mine: Bool { current.userId == (app.user?.id ?? 0) }

    private var canSend: Bool {
        !sending && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                MomentCard(
                    moment: current,
                    onLike: { Task { await app.likeMoment(current) } },
                    onComment: { composing = true },
                    onPreview: { idx in
                        guard idx < current.images.count,
                              let u = APIClient.fullURL(current.images[idx]) else { return }
                        previewBox = URLBox(url: u)
                    }
                )
                .padding(12)
            }
            .background(AKColor.bg)
            .navigationTitle("动态详情")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BackButton()
                }
                if mine {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                Task {
                                    await APIClient.shared.deleteMoment(id: current.id)
                                    await app.loadMoments()
                                    dismiss()
                                }
                            } label: {
                                Label("删除动态", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis").foregroundColor(AKColor.text)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { composer }
            .fullScreenCover(item: $previewBox) { box in
                MomentImagePreview(url: box.url)
            }
        }
    }

    /// 底部评论条：输入框 + 绿色「发送」，与安卓 CommentBar 同一口径
    private var composer: some View {
        HStack(spacing: 10) {
            TextField("说点什么…", text: $text)
                .font(.system(size: 14))
                .focused($composing)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Button(action: send) {
                Text(sending ? "发送中…" : "发送")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(canSend ? AKColor.brand : AKColor.placeholder)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AKColor.card)
        .overlay(alignment: .top) {
            Rectangle().fill(AKColor.line).frame(height: 0.5)
        }
    }

    private func send() {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !sending else { return }
        Task {
            sending = true
            defer { sending = false }
            await app.commentMoment(current, content: content)
            text = ""
            composing = false
        }
    }
}

private struct URLBox: Identifiable {
    let id = UUID()
    let url: URL
}

private struct MomentImagePreview: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AsyncImage(url: url) { img in
                img.resizable().scaledToFit()
            } placeholder: {
                ProgressView().tint(.white)
            }
            VStack {
                HStack {
                    Button("关闭") { dismiss() }.foregroundColor(.white)
                    Spacer()
                }
                .padding()
                Spacer()
            }
        }
    }
}
