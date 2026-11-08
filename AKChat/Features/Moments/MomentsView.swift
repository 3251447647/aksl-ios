import SwiftUI
import PhotosUI
import UIKit

struct MomentsView: View {
    @EnvironmentObject private var app: AppState
    @State private var showPublish = false
    @State private var detailMoment: Moment?
    @State private var commentTarget: Moment?
    @State private var commentText = ""
    /** 0=全部动态 1=我的动态 */
    @State private var tab = 0
    @State private var coverItem: PhotosPickerItem?

    /// 顶部封面：自己的朋友圈封面 + 右下角相机（对齐安卓）
    private var coverHeader: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let u = APIClient.fullURL(app.momentCover), !app.momentCover.isEmpty {
                    AsyncImage(url: u) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFill()
                        } else {
                            AKColor.fill
                        }
                    }
                } else {
                    LinearGradient(colors: [Color(hex: 0x2F6FD0), Color(hex: 0x9CC6F5)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .frame(height: 160)
            .frame(maxWidth: .infinity)
            .clipped()

            PhotosPicker(selection: $coverItem, matching: .images) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Circle())
            }
            .padding(.top, 10)
            .padding(.trailing, 12)
        }
    }

    private func uploadCover(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        if let up = try? await APIClient.shared.upload(
            data: data,
            filename: "cover_\(Int(Date().timeIntervalSince1970)).jpg",
            kind: "cover"
        ) {
            app.momentCover = up.url
        }
    }

    private var shownMoments: [Moment] {
        guard tab == 1 else { return app.moments }
        let me = app.user?.id ?? 0
        return app.moments.filter { $0.userId == me }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(["全部动态", "我的动态"].enumerated()), id: \.offset) { i, title in
                Button {
                    tab = i
                } label: {
                    Text(title)
                        .font(.system(size: 14, weight: tab == i ? .semibold : .regular))
                        .foregroundColor(tab == i ? AKColor.brand : AKColor.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(tab == i ? AKColor.card : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(AKColor.fill)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                coverHeader
                tabBar
                LazyVStack(spacing: 10) {
                    if tab == 1 && shownMoments.isEmpty {
                        Text("你还没有发过动态")
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.muted)
                            .padding(.top, 60)
                    }
                    ForEach(shownMoments) { moment in
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
            .onChange(of: coverItem) { item in
                guard let item else { return }
                Task { await uploadCover(item) }
            }
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
    @State private var expanded = false

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
                    Text(Self.relative(moment.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(AKColor.muted)
                }
                Spacer()
            }

            if let content = moment.content, !content.isEmpty {
                Text(content)
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.text)
                    .lineLimit(expanded ? nil : 4)
                if !expanded && content.count > 60 {
                    Button {
                        expanded = true
                    } label: {
                        Text("全文")
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.link)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !moment.images.isEmpty {
                let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
                LazyVGrid(columns: cols, spacing: 6) {
                    ForEach(moment.images.prefix(9), id: \.self) { path in
                        AsyncImage(url: APIClient.fullURL(path)) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                AKColor.fill
                            }
                        }
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }

            Rectangle().fill(AKColor.line).frame(height: 0.5).padding(.top, 2)

            HStack(spacing: 20) {
                Spacer()
                Text("转发")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.link)
                Button(action: onComment) {
                    HStack(spacing: 4) {
                        Text("\(moment.commentCount)")
                        Image(systemName: "text.bubble")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(moment.commentCount > 0 ? AKColor.link : AKColor.muted)
                }
                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: moment.liked == 1 ? "heart.fill" : "heart")
                        Text("\(moment.likeCount)")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(moment.liked == 1 ? AKColor.red : AKColor.muted)
                }
            }

            if !moment.likes.isEmpty || !moment.comments.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    if !moment.likes.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 11))
                                .foregroundColor(AKColor.red)
                            Text(moment.likes.compactMap { $0.name }.joined(separator: "、"))
                                .font(.system(size: 12.5))
                                .foregroundColor(AKColor.text)
                                .lineLimit(2)
                        }
                    }
                    if !moment.comments.isEmpty {
                        if !moment.likes.isEmpty {
                            Rectangle().fill(AKColor.line).frame(height: 0.5)
                        }
                        ForEach(moment.comments.prefix(6)) { c in
                            HStack(alignment: .top, spacing: 4) {
                                Text(c.name ?? "成员")
                                    .font(.system(size: 12.5))
                                    .foregroundColor(AKColor.link)
                                Text(c.content ?? "")
                                    .font(.system(size: 12.5))
                                    .foregroundColor(AKColor.text)
                                    .lineLimit(3)
                            }
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

    /// 相对时间：刚刚 / N 分钟前 / N 小时前 / N 天前 / 日期
    static func relative(_ ts: Int64) -> String {
        guard ts > 0 else { return "" }
        let diff = Date().timeIntervalSince1970 - TimeInterval(ts)
        if diff < 60 { return "刚刚" }
        if diff < 3600 { return "\(Int(diff / 60))分钟前" }
        if diff < 86400 { return "\(Int(diff / 3600))小时前" }
        if diff < 86400 * 30 { return "\(Int(diff / 86400))天前" }
        return TimeText.short(ts)
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
