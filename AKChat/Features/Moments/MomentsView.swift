import SwiftUI
import PhotosUI
import UIKit

struct MomentsView: View {
    @EnvironmentObject private var app: AppState
    @State private var showPublish = false
    @State private var detailMoment: Moment?
    @State private var commentTarget: Moment?
    @State private var commentText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    if app.moments.isEmpty {
                        Text("还没有动态，点右上角发布一条")
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.muted)
                            .padding(.top, 60)
                    }
                    ForEach(app.moments) { moment in
                        MomentCard(
                            moment: moment,
                            onLike: { Task { await app.likeMoment(moment) } },
                            onComment: {
                                commentTarget = moment
                                commentText = ""
                            }
                        )
                        .onTapGesture { detailMoment = moment }
                        .contextMenu {
                            if moment.userId == (app.user?.id ?? 0) {
                                Button(role: .destructive) {
                                    Task {
                                        await APIClient.shared.deleteMoment(id: moment.id)
                                        await app.loadMoments()
                                    }
                                } label: {
                                    Label("删除动态", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(12)
            }
            .background(AKColor.bg)
            .navigationTitle("广场")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        MomentNoticesView()
                    } label: {
                        Image(systemName: "bell").foregroundColor(AKColor.text)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showPublish = true } label: {
                        Image(systemName: "square.and.pencil").foregroundColor(AKColor.text)
                    }
                }
            }
            .refreshable { await app.loadMoments() }
            .task { await app.loadMoments() }
            .sheet(item: $detailMoment) { m in
                MomentDetailView(moment: m)
            }
            .sheet(isPresented: $showPublish) {
                PublishMomentView { content, images in
                    await app.publishMoment(content: content, images: images)
                }
            }
            .alert("评论", isPresented: Binding(
                get: { commentTarget != nil },
                set: { if !$0 { commentTarget = nil } }
            )) {
                TextField("说点什么…", text: $commentText)
                Button("取消", role: .cancel) { commentTarget = nil }
                Button("发送") {
                    if let target = commentTarget {
                        Task { await app.commentMoment(target, content: commentText) }
                    }
                    commentTarget = nil
                }
            }
        }
    }
}

private struct MomentCard: View {
    let moment: Moment
    let onLike: () -> Void
    let onComment: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                AvatarView(url: moment.avatar, name: moment.nickname ?? "用户", size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(moment.nickname ?? "用户")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AKColor.text)
                        if moment.vipLevel > 0 {
                            BadgeView(text: moment.vipLevel >= 2 ? "SVIP" : "VIP")
                        }
                        if let no = moment.prettyYxid, !no.isEmpty {
                            BadgeView(text: no, color: AKColor.link, background: AKColor.blueSoft)
                        }
                    }
                    Text(TimeText.short(moment.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(AKColor.muted)
                }
                Spacer()
            }

            if let content = moment.content, !content.isEmpty {
                Text(content)
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.text)
                    .textSelection(.enabled)
            }

            if !moment.images.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 6)], spacing: 6) {
                    ForEach(moment.images.prefix(9), id: \.self) { path in
                        AsyncImage(url: APIClient.fullURL(path)) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                AKColor.fill
                            }
                        }
                        .frame(height: 100)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }

            HStack(spacing: 18) {
                Button(action: onLike) {
                    Label("\(moment.likeCount)", systemImage: moment.liked == 1 ? "heart.fill" : "heart")
                        .font(.system(size: 12))
                        .foregroundColor(moment.liked == 1 ? AKColor.red : AKColor.muted)
                }
                Button(action: onComment) {
                    Label("\(moment.commentCount)", systemImage: "text.bubble")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.muted)
                }
            }

            if !moment.likes.isEmpty {
                Text("赞：" + moment.likes.compactMap { $0.name }.joined(separator: "、"))
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.sub)
            }
            if !moment.comments.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(moment.comments.prefix(6)) { c in
                        Text("\(c.name ?? "用户")：\(c.content ?? "")")
                            .font(.system(size: 12))
                            .foregroundColor(AKColor.sub)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(12)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct PublishMomentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppState

    @State private var text = ""
    @State private var items: [PhotosPickerItem] = []
    @State private var previews: [Data] = []
    @State private var publishing = false
    @State private var errorText: String?

    let onPublish: (String, [String]) async -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $text)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(AKColor.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                PhotosPicker(selection: $items, maxSelectionCount: 9, matching: .images) {
                    Label("添加图片", systemImage: "photo")
                        .font(.system(size: 14))
                }

                if !previews.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(previews.enumerated()), id: \.offset) { _, data in
                                if let image = UIImage(data: data) {
                                    Image(uiImage: image)
                                        .resizable().scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                }

                if let errorText {
                    Text(errorText).font(.system(size: 12)).foregroundColor(AKColor.red)
                }
                Spacer()
            }
            .padding(14)
            .navigationTitle("发布动态")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(publishing ? "发布中…" : "发布") {
                        Task { await publish() }
                    }
                    .disabled(publishing || (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && items.isEmpty))
                }
            }
            .onChange(of: items) { list in
                Task {
                    var dataList: [Data] = []
                    for item in list {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            dataList.append(data)
                        }
                    }
                    previews = dataList
                }
            }
        }
    }

    private func publish() async {
        publishing = true
        errorText = nil
        defer { publishing = false }

        var urls: [String] = []
        for data in previews {
            do {
                let uploaded = try await app.uploadImage(data)
                urls.append(uploaded.url)
            } catch {
                errorText = "图片上传失败：\(error.localizedDescription)"
                return
            }
        }
        await onPublish(text.trimmingCharacters(in: .whitespacesAndNewlines), urls)
        dismiss()
    }
}
