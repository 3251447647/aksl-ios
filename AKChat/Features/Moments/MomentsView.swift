import SwiftUI
import PhotosUI
import UIKit
import AVFoundation
import AVKit

struct MomentsView: View {
    @EnvironmentObject private var app: AppState
    @State private var showPublish = false
    @State private var detailMoment: Moment?
    @State private var commentTarget: Moment?
    @State private var commentText = ""
    /** 0=全部动态 1=我的动态 */
    @State private var tab = 0
    @State private var coverItem: PhotosPickerItem?

    /// 顶部封面：自己的朋友圈封面 + 右上角相机 + 右下角署名（对齐安卓）
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
                    LinearGradient(colors: [AKColor.brand, Color(hex: 0x06AD56)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .clipped()

            LinearGradient(stops: [
                .init(color: Color.black.opacity(0.08), location: 0),
                .init(color: .clear, location: 0.55),
                .init(color: Color.black.opacity(0.55), location: 1)
            ], startPoint: .top, endPoint: .bottom)
            .frame(height: 200)
            .allowsHitTesting(false)

            PhotosPicker(selection: $coverItem, matching: .images) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.black.opacity(0.32))
                    .clipShape(Circle())
            }
            .padding(6)

            HStack(spacing: 8) {
                Text(app.user?.displayName ?? "我")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                AvatarView(url: app.user?.avatar, name: app.user?.displayName ?? "我", size: 54)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .frame(height: 200)
        .clipped()
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
                        .font(.system(size: 13, weight: tab == i ? .semibold : .regular))
                        .foregroundColor(tab == i ? AKColor.brand : AKColor.sub)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(tab == i ? AKColor.card : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(AKColor.fill)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 12)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                coverHeader
                tabBar
                if shownMoments.isEmpty {
                    VStack(spacing: 6) {
                        Text(tab == 1 ? "你还没有发过动态" : "还没有好友动态")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AKColor.sub)
                        Text(tab == 1 ? "点右上角发布，发第一条动态吧～" : "点右上角发布，发一条自己的动态")
                            .font(.system(size: 12.5))
                            .foregroundColor(AKColor.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
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
                    .padding(.horizontal, 12)
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
            .padding(.bottom, 16)
        }
        .background(AKColor.bg)
        .navigationTitle("朋友圈")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 18) {
                    NavigationLink {
                        MomentNoticesView()
                    } label: {
                        Image(systemName: "bell").foregroundColor(AKColor.text)
                    }
                    Button { showPublish = true } label: {
                        Image(systemName: "square.and.pencil").foregroundColor(AKColor.text)
                    }
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
            PublishMomentView { content, images, videoUrl, duration, cover in
                await app.publishMoment(content: content, images: images,
                                        videoUrl: videoUrl, duration: duration, cover: cover)
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

/// 一条动态：头像 40 + 右侧整列（名字、时间、正文、三列方图、操作行、互动块），与安卓 MomentItem 同构
struct MomentCard: View {
    let moment: Moment
    let onLike: () -> Void
    let onComment: () -> Void
    /// 详情页点图放大；列表里点整卡进详情，不传
    var onPreview: ((Int) -> Void)? = nil

    @State private var expanded = false
    @State private var playVideo = false

    private var images: [String] { Array(moment.images.prefix(9)) }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(url: moment.avatar, name: moment.nickname ?? "用户", size: 40)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text(moment.nickname ?? "用户")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AKColor.text)
                        .lineLimit(1)
                    if let no = moment.prettyYxid, !no.isEmpty {
                        BadgeView(text: no, color: AKColor.gold, background: AKColor.goldSoft)
                    }
                    if moment.vipLevel > 0 {
                        BadgeView(text: moment.vipLevel >= 2 ? "SVIP" : "VIP")
                    }
                    Spacer(minLength: 0)
                }

                Text(Self.relative(moment.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(AKColor.hint)
                    .padding(.top, 3)

                if let content = moment.content, !content.isEmpty {
                    Text(content)
                        .font(.system(size: 14))
                        .foregroundColor(AKColor.text)
                        .lineSpacing(5)
                        .lineLimit(expanded ? nil : 6)
                        .padding(.top, 6)
                    if content.count > 120 {
                        Button {
                            expanded.toggle()
                        } label: {
                            Text(expanded ? "收起" : "全文")
                                .font(.system(size: 13))
                                .foregroundColor(AKColor.link)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 3)
                    }
                }

                if !images.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                        ForEach(Array(images.enumerated()), id: \.offset) { idx, path in
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
                            .simultaneousGesture(TapGesture().onEnded { onPreview?(idx) })
                        }
                    }
                    .padding(.top, 8)
                }

                if !moment.videoUrl.isEmpty {
                    videoCell.padding(.top, 8)
                }

                Rectangle().fill(AKColor.line).frame(height: 0.6).padding(.top, 6)

                actionRow

                if !moment.likes.isEmpty || !moment.comments.isEmpty {
                    interactions.padding(.top, 8)
                }
            }
        }
        .padding(12)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var videoCell: some View {
        ZStack {
            if let u = APIClient.fullURL(moment.videoCover) {
                AsyncImage(url: u) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else {
                        Color.black.opacity(0.85)
                    }
                }
            } else {
                Color.black.opacity(0.85)
            }
            Image(systemName: "play.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.92))
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { playVideo = true }
        .fullScreenCover(isPresented: $playVideo) {
            MomentVideoPlayer(url: APIClient.fullURL(moment.videoUrl))
        }
    }

    /// 操作行：转发 / 评论 / 点赞，右对齐
    private var actionRow: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Text("转发")
                .font(.system(size: 12))
                .foregroundColor(AKColor.link)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
            Button(action: onComment) {
                HStack(spacing: 3) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 18, weight: .regular))
                    if moment.commentCount > 0 {
                        Text("\(moment.commentCount)").font(.system(size: 12))
                    }
                }
                .foregroundColor(AKColor.muted)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
            }
            .buttonStyle(.plain)
            Button(action: onLike) {
                HStack(spacing: 3) {
                    Image(systemName: moment.liked == 1 ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .regular))
                    if moment.likeCount > 0 {
                        Text("\(moment.likeCount)").font(.system(size: 12))
                    }
                }
                .foregroundColor(moment.liked == 1 ? AKColor.red : AKColor.muted)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
            }
            .buttonStyle(.plain)
        }
    }

    /// 灰底点赞+评论块
    private var interactions: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !moment.likes.isEmpty {
                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.red)
                        .padding(.top, 2)
                    Text(moment.likes.compactMap { $0.name }.joined(separator: "、"))
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.link)
                        .lineSpacing(3)
                }
            }
            if !moment.comments.isEmpty {
                if !moment.likes.isEmpty {
                    Rectangle().fill(AKColor.line).frame(height: 0.6).padding(.vertical, 6)
                }
                ForEach(moment.comments) { c in
                    commentRow(c)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.fill)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func commentRow(_ c: MomentComment) -> some View {
        HStack(alignment: .top, spacing: 8) {
            AvatarView(url: c.avatar, name: c.name ?? "用户", size: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(c.name ?? "用户")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(AKColor.link)
                if let reply = c.replyName, !reply.isEmpty {
                    Text("回复 \(reply)")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.hint)
                }
                if let content = c.content, !content.isEmpty {
                    Text(content)
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.text)
                        .lineSpacing(3)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
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

    let onPublish: (String, [String], String, Int, String) async -> Void
    @State private var videoItem: PhotosPickerItem?
    @State private var videoURL: String = ""
    @State private var videoCover: String = ""
    @State private var videoDuration: Int = 0
    @State private var uploadingVideo = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $text)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(AKColor.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text("\(text.count)/500")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.hint)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                PhotosPicker(selection: $items, maxSelectionCount: 9, matching: .images) {
                    Label("添加图片", systemImage: "photo")
                        .font(.system(size: 14))
                }

                PhotosPicker(selection: $videoItem, matching: .videos) {
                    Label(uploadingVideo ? "视频上传中…" : (videoURL.isEmpty ? "添加视频" : "更换视频"),
                          systemImage: "video")
                        .font(.system(size: 14))
                }
                if !videoCover.isEmpty, let u = APIClient.fullURL(videoCover) {
                    ZStack {
                        AsyncImage(url: u) { phase in
                            if let img = phase.image {
                                img.resizable().scaledToFill()
                            } else {
                                AKColor.fill
                            }
                        }
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if !previews.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                        ForEach(Array(previews.enumerated()), id: \.offset) { idx, data in
                            ZStack(alignment: .topTrailing) {
                                if let image = UIImage(data: data) {
                                    Image(uiImage: image)
                                        .resizable().scaledToFill()
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(1, contentMode: .fill)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                Button {
                                    previews.remove(at: idx)
                                    if idx < items.count { items.remove(at: idx) }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 18, height: 18)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .padding(4)
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
            .onChange(of: videoItem) { item in
                guard let item else { return }
                Task { await uploadVideo(item) }
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

    /// 视频：读数据 → 上传（kind=video）→ 抽首帧当封面（kind=moment）
    private func uploadVideo(_ item: PhotosPickerItem) async {
        uploadingVideo = true
        errorText = nil
        defer { uploadingVideo = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            if data.count > 60 * 1024 * 1024 {
                errorText = "视频不能超过 60MB"
                return
            }
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("moment_\(Int(Date().timeIntervalSince1970)).mov")
            try data.write(to: tmp)
            defer { try? FileManager.default.removeItem(at: tmp) }

            let asset = AVURLAsset(url: tmp)
            let seconds = Int(CMTimeGetSeconds(asset.duration))
            videoDuration = seconds > 0 ? seconds : 0

            if let coverData = Self.coverData(from: asset) {
                let up = try await app.uploadImage(coverData)
                videoCover = up.url
            }

            let upVideo = try await APIClient.shared.upload(
                data: data,
                filename: "moment_\(Int(Date().timeIntervalSince1970)).mp4",
                kind: "video"
            )
            videoURL = upVideo.url
        } catch {
            errorText = "视频上传失败：\(error.localizedDescription)"
        }
    }

    /// 取视频首帧压缩成 jpg
    private static func coverData(from asset: AVURLAsset) -> Data? {
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 720, height: 720)
        guard let cg = try? gen.copyCGImage(at: CMTime(seconds: 0.1, preferredTimescale: 600), actualTime: nil) else {
            return nil
        }
        return UIImage(cgImage: cg).jpegData(compressionQuality: 0.8)
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
        await onPublish(text.trimmingCharacters(in: .whitespacesAndNewlines), urls,
                        videoURL, videoDuration, videoCover)
        dismiss()
    }
}

/// 朋友圈视频播放：全屏播放，点击关闭
struct MomentVideoPlayer: View {
    let url: URL?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let url {
                VideoPlayer(player: AVPlayer(url: url))
                    .ignoresSafeArea()
            } else {
                Text("视频地址无效").foregroundColor(.white)
            }
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Circle())
                    }
                    .padding(14)
                }
                Spacer()
            }
        }
    }
}
