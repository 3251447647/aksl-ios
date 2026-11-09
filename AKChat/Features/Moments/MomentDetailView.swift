import SwiftUI

/// 朋友圈详情：与列表同一张动态卡片 + 底部评论条（对齐安卓 MomentDetailScreen）
struct MomentDetailView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @FocusState private var composing: Bool

    let moment: Moment

    @State private var text = ""
    @State private var sending = false
    @State private var previewBox: MomentImageBox?
    @State private var showDelete = false
    @State private var gone = false

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
            Group {
                if gone {
                    goneState
                } else {
                    ScrollView {
                        MomentCard(
                            moment: current,
                            isMine: mine,
                            onLike: { Task { await app.likeMoment(current) } },
                            onComment: { composing = true },
                            onDelete: { showDelete = true },
                            onPreview: { idx in
                                previewBox = MomentImageBox(images: current.images, index: idx)
                            }
                        )
                        .padding(12)
                    }
                }
            }
            .background(AKColor.bg)
            .reportsDetailPage()
            .navigationTitle("动态详情")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BackButton()
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !gone { composer }
            }
            .fullScreenCover(item: $previewBox) { box in
                MomentImagePager(images: box.images, start: box.index)
            }
            .alert("删除动态", isPresented: $showDelete) {
                Button("删除", role: .destructive) {
                    Task {
                        await APIClient.shared.deleteMoment(id: current.id)
                        await app.loadMoments()
                        gone = true
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("确定删除这条动态吗？点赞和评论将一并清除，此操作不可恢复。")
            }
        }
    }

    private var goneState: some View {
        VStack(spacing: 6) {
            Text("该动态已不存在")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AKColor.sub)
            Text("它可能已被作者删除")
                .font(.system(size: 12.5))
                .foregroundColor(AKColor.hint)
            Button {
                dismiss()
            } label: {
                Text("返回消息列表")
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.brand)
                    .padding(.top, 8)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 30)
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
                .onChange(of: text) { value in
                    if value.count > 500 { text = String(value.prefix(500)) }
                }
            Text("\(text.count)/500")
                .font(.system(size: 10.5))
                .foregroundColor(AKColor.placeholder)
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
