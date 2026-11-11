import SwiftUI

/// 转发动态：500 字以内可留空评论 + 原动态引用预览（对齐安卓 PublishMomentScreen 的 repost 模式）
struct RepostMomentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let moment: Moment
    let onDone: () async -> Void

    @State private var text = ""
    @State private var sending = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $text)
                            .font(.system(size: 15))
                            .frame(height: 140)
                            .padding(6)
                            .background(AKColor.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(AKColor.line, lineWidth: 0.8)
                            )
                            .onChange(of: text) { value in
                                if value.count > 500 { text = String(value.prefix(500)) }
                            }
                        if text.isEmpty {
                            Text("说点什么…（可留空）")
                                .font(.system(size: 15))
                                .foregroundColor(AKColor.placeholder)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }

                    HStack {
                        Spacer(minLength: 0)
                        Text("\(text.count)/500")
                            .font(.system(size: 11))
                            .foregroundColor(text.count > 450 ? AKColor.red : AKColor.placeholder)
                    }

                    preview

                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 12))
                            .foregroundColor(AKColor.red)
                    }
                }
                .padding(14)
            }
            .background(AKColor.bg)
            .navigationTitle("转发动态")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AKColor.muted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await send() }
                    } label: {
                        Text(sending ? "转发中…" : "转发")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(AKColor.brand)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .disabled(sending)
                }
            }
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(moment.nickname ?? "用户")：")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(AKColor.link)
            if let content = moment.content, !content.isEmpty {
                Text(content)
                    .font(.system(size: 13.5))
                    .foregroundColor(AKColor.text)
                    .lineSpacing(4)
                    .lineLimit(4)
            }
            if !moment.images.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(moment.images.prefix(3).enumerated()), id: \.element) { _, path in
                        AKImage(url: path, size: 56, placeholder: AKColor.fill)
                            .frame(width: 56, height: 56)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.fill)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func send() async {
        guard !sending else { return }
        sending = true
        defer { sending = false }
        do {
            _ = try await APIClient.shared.postRaw(
                "api/v1/moments/repost",
                body: [
                    "moment_id": moment.id,
                    "content": text.trimmingCharacters(in: .whitespacesAndNewlines)
                ]
            )
            await onDone()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
