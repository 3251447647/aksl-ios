import SwiftUI

/// 朋友圈详情：大图、点赞、全部评论、删除自己的动态
struct MomentDetailView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    let moment: Moment

    @State private var comments: [MomentComment]
    @State private var liked: Bool
    @State private var likeCount: Int
    @State private var text = ""
    @State private var sending = false
    @State private var previewBox: URLBox?
    @State private var error: String?

    init(moment: Moment) {
        self.moment = moment
        _comments = State(initialValue: moment.comments)
        _liked = State(initialValue: moment.liked == 1)
        _likeCount = State(initialValue: moment.likeCount)
    }

    private var mine: Bool { moment.userId == (app.user?.id ?? 0) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    if let content = moment.content, !content.isEmpty {
                        Text(content)
                            .font(.system(size: 15))
                            .foregroundColor(AKColor.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !moment.images.isEmpty {
                        imageGrid
                    }
                    likeRow
                    commentList
                    if let error {
                        Text(error).font(.system(size: 12)).foregroundColor(AKColor.red)
                    }
                }
                .padding(14)
            }
            .background(AKColor.bg)
            .navigationTitle("动态详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                if mine {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                Task {
                                    await APIClient.shared.deleteMoment(id: moment.id)
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

    private var header: some View {
        HStack(spacing: 10) {
            AsyncImage(url: APIClient.fullURL(moment.avatar)) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                AKColor.fill
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(moment.nickname ?? "用户")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AKColor.text)
                Text(Self.timeText(moment.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(AKColor.muted)
            }
            Spacer()
        }
    }

    private var imageGrid: some View {
        let cols = moment.images.count == 1 ? 1 : (moment.images.count == 2 ? 2 : 3)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: cols), spacing: 4) {
            ForEach(moment.images, id: \.self) { path in
                AsyncImage(url: APIClient.fullURL(path)) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    AKColor.fill
                }
                .frame(height: cols == 1 ? 220 : 108)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture {
                    if let u = APIClient.fullURL(path) { previewBox = URLBox(url: u) }
                }
            }
        }
    }

    private var likeRow: some View {
        HStack(spacing: 8) {
            Button {
                Task {
                    await APIClient.shared.likeMoment(id: moment.id)
                    liked.toggle()
                    likeCount += liked ? 1 : -1
                    await app.loadMoments()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: liked ? "heart.fill" : "heart")
                    Text(likeCount > 0 ? "\(likeCount)" : "赞")
                }
                .font(.system(size: 12))
                .foregroundColor(liked ? AKColor.red : AKColor.sub)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AKColor.fill)
                .clipShape(Capsule())
            }
            Spacer()
        }
    }

    private var commentList: some View {
        VStack(alignment: .leading, spacing: 6) {
            if comments.isEmpty {
                Text("还没有评论").font(.system(size: 12)).foregroundColor(AKColor.muted)
            }
            ForEach(comments) { c in
                HStack(alignment: .top, spacing: 4) {
                    Text(c.name ?? "用户")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AKColor.link)
                    Text(c.content ?? "")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.text)
                    Spacer()
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("评论…", text: $text)
                .font(.system(size: 14))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Button {
                let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !content.isEmpty, !sending else { return }
                Task {
                    sending = true
                    defer { sending = false }
                    await APIClient.shared.commentMoment(id: moment.id, content: content)
                    text = ""
                    await app.loadMoments()
                    let now = Int64(Date().timeIntervalSince1970)
                    comments.append(MomentComment(
                        id: now,
                        uid: app.user?.id ?? 0,
                        name: app.user?.nickname,
                        avatar: app.user?.avatar,
                        content: content,
                        replyName: nil,
                        canDelete: 1,
                        createdAt: now
                    ))
                }
            } label: {
                Text("发送")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AKColor.placeholder : AKColor.brand)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AKColor.card)
    }

    static func timeText(_ ts: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: date)
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
