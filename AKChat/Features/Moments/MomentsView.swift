import SwiftUI
import PhotosUI
import UIKit
import AVFoundation
import AVKit

struct MomentsView: View {
    /// 他人朋友圈：>0 且不是本人时只拉该用户的动态（对齐安卓 MomentsScreen 的 otherUid）
    var uid: Int64 = 0
    var ownerName: String = ""
    var ownerAvatar: String? = nil
    var ownerVip: Int = 0
    var ownerIsPretty: Int = 0
    var ownerPrettyNo: String = ""

    @EnvironmentObject private var app: AppState
    @State private var showPublish = false
    @State private var commentTarget: Moment?
    @State private var deleteTarget: Moment?
    @State private var previewBox: MomentImageBox?
    /** 点赞乐观状态：调用接口期间先按本地状态渲染，列表刷新后以服务端为准 */
    @State private var likeOverrides: [Int64: MomentLikeOverride] = [:]
    @State private var liking: Set<Int64> = []
    @State private var repostTarget: Moment?
    /** 0=全部动态 1=我的动态 */
    @State private var tab = 0
    @State private var mineMoments: [Moment] = []
    @State private var mineLoading = false
    @State private var coverItem: PhotosPickerItem?
    /// 他人朋友圈的动态与封面（不写进全局 app.moments，避免污染首页动态流）
    @State private var otherMoments: [Moment] = []
    @State private var otherCover = ""
    @State private var otherLoading = false
    /// 朋友圈未读角标：缓存一份，避免每次 body 都 first(where:) 扫会话列表
    @State private var momentUnread = 0

    /// 是否在看别人的朋友圈
    private var isOtherFeed: Bool { uid > 0 && uid != (app.user?.id ?? 0) }

    private var shownMoments: [Moment] {
        if isOtherFeed { return otherMoments }
        return tab == 1 ? mineMoments : app.moments
    }

    private var displayCover: String { isOtherFeed ? otherCover : app.momentCover }

    /// 顶部封面：自己的朋友圈封面 + 右上角相机 + 右下角署名（对齐安卓）
    private var coverHeader: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if APIClient.fullURL(displayCover) != nil {
                    AKImage(url: displayCover,
                            size: CGSize(width: UIScreen.main.bounds.width, height: 200),
                            contentMode: .fill)
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

            if !isOtherFeed {
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
        }
        .frame(height: 200)
        .clipped()
    }

    /// 他人朋友圈顶部资料条（对齐安卓 MomentOwnerHeader）
    private var ownerHeader: some View {
        HStack(spacing: 12) {
            AvatarView(url: ownerAvatar, name: ownerName.isEmpty ? "TA" : ownerName, size: 52)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(ownerName.isEmpty ? "TA" : ownerName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AKColor.text)
                        .lineLimit(1)
                    if ownerIsPretty == 1, !ownerPrettyNo.isEmpty {
                        PrettyBadge(number: ownerPrettyNo)
                    }
                    if ownerVip > 0 { VipBadge(level: ownerVip) }
                }
                if otherLoading && otherMoments.isEmpty {
                    Text("加载中…")
                        .font(.system(size: 11))
                        .foregroundColor(AKColor.muted)
                } else if !ownerPrettyNo.isEmpty {
                    Text("靓号 \(ownerPrettyNo)")
                        .font(.system(size: 11))
                        .foregroundColor(AKColor.muted)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AKColor.card)
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

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(["全部动态", "我的动态"].enumerated()), id: \.offset) { i, title in
                Button {
                    tab = i
                    if i == 1 { Task { await loadMine() } }
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
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    coverHeader
                    if isOtherFeed {
                        ownerHeader
                    } else {
                        tabBar
                    }
                    if shownMoments.isEmpty {
                        VStack(spacing: 6) {
                            Text(emptyTitle)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AKColor.sub)
                            Text(emptyHint)
                                .font(.system(size: 12.5))
                                .foregroundColor(AKColor.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 320)
                    }
                    ForEach(shownMoments) { moment in
                        MomentCard(
                            moment: moment,
                            isMine: moment.userId == (app.user?.id ?? 0),
                            onLike: { Task { await like(moment) } },
                            onComment: { commentTarget = moment },
                            onDelete: { deleteTarget = moment },
                            onPreview: { index in
                                previewBox = MomentImageBox(images: moment.images, index: index)
                            },
                            likeOverride: likeOverrides[moment.id],
                            onRepost: { repostTarget = moment }
                        )
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.bottom, 90)
            }
            .background(AKColor.bg)

            if !isOtherFeed {
                Button {
                    showPublish = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(AKColor.brand)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.18), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 18)
                .padding(.bottom, 24)
            }
        }
        .reportsDetailPage()
        .navigationTitle(isOtherFeed ? (ownerName.isEmpty ? "朋友圈" : "\(ownerName) 的朋友圈") : "朋友圈")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if !isOtherFeed {
                    noticeEntry
                }
            }
        }
        .refreshable { await refresh() }
        .onChange(of: coverItem) { item in
            guard let item else { return }
            Task { await uploadCover(item) }
        }
        .task {
            if isOtherFeed {
                await loadOther()
            } else {
                syncUnread()
                let t = AKPerf.start()
                await app.loadMoments()
                AKPerf.log("moments.load", since: t, "\(app.moments.count) 条动态")
            }
        }
        .onChange(of: app.conversations) { _ in
            if !isOtherFeed { syncUnread() }
        }
        .fullScreenCover(item: $previewBox) { box in
            MomentImagePager(images: box.images, start: box.index)
        }
        .sheet(item: $commentTarget, onDismiss: {
            if isOtherFeed { Task { await loadOther() } }
        }) { m in
            MomentReplySheet(moment: m)
                .environmentObject(app)
        }
        .sheet(item: $repostTarget) { m in
            RepostMomentSheet(moment: m) {
                await app.loadMoments()
                if tab == 1 { await loadMine() }
                if isOtherFeed { await loadOther() }
            }
        }
        .navigationDestination(isPresented: $showPublish) {
            PublishMomentView { content, images, videoUrl, duration, cover in
                await app.publishMoment(content: content, images: images,
                                        videoUrl: videoUrl, duration: duration, cover: cover)
                if tab == 1 { await loadMine() }
            }
            .reportsDetailPage()
            .restoresSwipeBack()
        }
        .alert("删除动态", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("删除", role: .destructive) {
                guard let target = deleteTarget else { return }
                deleteTarget = nil
                Task {
                    await APIClient.shared.deleteMoment(id: target.id)
                    await refresh()
                }
            }
            Button("取消", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("确定删除这条动态吗？点赞和评论将一并清除，此操作不可恢复。")
        }
    }

    private func like(_ moment: Moment) async {
        guard !liking.contains(moment.id) else { return }
        liking.insert(moment.id)
        let base = MomentLikeOverride.current(moment, local: likeOverrides[moment.id])
        likeOverrides[moment.id] = base.toggled(uid: app.user?.id ?? 0,
                                                name: app.user?.displayName ?? "我")
        if isOtherFeed {
            await APIClient.shared.likeMoment(id: moment.id)
            await loadOther()
        } else {
            await app.likeMoment(moment)
            if tab == 1 { await loadMine() }
        }
        likeOverrides.removeValue(forKey: moment.id)
        liking.remove(moment.id)
    }

    private func refresh() async {
        let t = AKPerf.start()
        if isOtherFeed {
            await loadOther()
        } else {
            await app.loadMoments()
            if tab == 1 { await loadMine() }
        }
        AKPerf.log("moments.refresh", since: t, "\(shownMoments.count) 条动态")
    }

    private func syncUnread() {
        momentUnread = app.conversations.first { $0.convType == "moment" }?.unread ?? 0
    }

    private func loadMine() async {
        guard !mineLoading else { return }
        mineLoading = true
        defer { mineLoading = false }
        let t = AKPerf.start()
        if let data = try? await APIClient.shared.moments(mine: 1) {
            mineMoments = data.list
        }
        AKPerf.log("moments.mine", since: t, "\(mineMoments.count) 条动态")
    }

    /// 只拉该用户的动态（服务端 /moments?uid= 只回该用户，封面也是对方的）
    private func loadOther() async {
        guard isOtherFeed, !otherLoading else { return }
        otherLoading = true
        defer { otherLoading = false }
        let t = AKPerf.start()
        if let data = try? await APIClient.shared.moments(uid: uid) {
            otherMoments = data.list
            otherCover = data.cover
        }
        AKPerf.log("moments.other", since: t, "\(otherMoments.count) 条动态")
    }

    private var emptyTitle: String {
        if isOtherFeed { return "TA 还没有发过动态" }
        return tab == 1 ? "你还没有发过动态" : "还没有好友动态"
    }

    private var emptyHint: String {
        if isOtherFeed { return "过段时间再来看看吧～" }
        return tab == 1 ? "点击右下角 + 号，发第一条动态吧～" : "点击右下角 + 号，发一条自己的动态"
    }

    /// 右上角朋友圈消息入口（他人朋友圈不显示，对齐安卓）
    private var noticeEntry: some View {
        NavigationLink {
            MomentNoticesView()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell").foregroundColor(AKColor.text)
                if momentUnread > 0 {
                    Text("\(min(momentUnread, 99))")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 3)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(AKColor.red)
                        .clipShape(Capsule())
                        .offset(x: 8, y: -7)
                }
            }
        }
    }
}

/// 列表内图片全屏预览（支持左右切换与 1/N）
struct MomentImageBox: Identifiable {
    let id = UUID()
    let images: [String]
    let index: Int
}

struct MomentImagePager: View {
    let images: [String]
    @State private var index: Int
    @Environment(\.dismiss) private var dismiss

    init(images: [String], start: Int) {
        self.images = images
        _index = State(initialValue: min(max(start, 0), max(images.count - 1, 0)))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(images.indices, id: \.self) { i in
                    ZStack {
                        ProgressView().tint(.white)
                        AKImage(url: images[i],
                                size: UIScreen.main.bounds.size,
                                contentMode: .fit,
                                placeholder: .clear)
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

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
                }
                .padding(14)
                Spacer()
                Text("\(index + 1)/\(images.count)")
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(.bottom, 30)
            }
        }
    }
}

/// 点赞的本地覆盖值：接口返回前先按它渲染，刷新后丢弃
struct MomentLikeOverride: Equatable {
    var liked: Int
    var likeCount: Int
    var likes: [MomentLike]

    static func current(_ moment: Moment, local: MomentLikeOverride?) -> MomentLikeOverride {
        local ?? MomentLikeOverride(liked: moment.liked,
                                       likeCount: moment.likeCount,
                                       likes: moment.likes)
    }

    /// 与安卓 toggleLike 同一口径：心形取反、计数保底 0、名单按 uid 增删
    func toggled(uid: Int64, name: String) -> MomentLikeOverride {
        let turnOn = liked != 1
        var next = likes.filter { $0.uid != uid }
        if turnOn {
            next.append(MomentLike(uid: uid, name: name))
        }
        return MomentLikeOverride(liked: turnOn ? 1 : 0,
                                  likeCount: max(0, likeCount + (turnOn ? 1 : -1)),
                                  likes: next)
    }
}

/// 一条动态：头像 40 + 右侧整列（名字、时间、正文、图片、视频、操作行、互动块），与安卓 MomentItem 同构
struct MomentCard: View {
    let moment: Moment
    var isMine: Bool = false
    let onLike: () -> Void
    let onComment: () -> Void
    var onDelete: (() -> Void)? = nil
    /// 点图放大；列表与详情都传
    var onPreview: ((Int) -> Void)? = nil
    /// 点赞乐观覆盖：列表与详情共用
    var likeOverride: MomentLikeOverride? = nil
    var onRepost: (() -> Void)? = nil

    @State private var expanded = false
    @State private var playVideo = false

    private var images: [String] { Array(moment.images.prefix(9)) }
    private var liked: Bool { (likeOverride?.liked ?? moment.liked) == 1 }
    private var likeCount: Int { likeOverride?.likeCount ?? moment.likeCount }
    private var likeList: [MomentLike] { likeOverride?.likes ?? moment.likes }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(url: moment.avatar, name: moment.nickname ?? "用户", size: 40)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text(moment.nickname ?? "用户")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AKColor.text)
                        .lineLimit(1)
                    if let no = moment.prettyYxid, !no.isEmpty {
                        PrettyBadge(number: no)
                    }
                    if moment.vipLevel > 0 {
                        VipBadge(level: moment.vipLevel)
                    }
                    Spacer(minLength: 0)
                }

                Text(Self.relative(moment.createdAt))
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.hint)
                    .padding(.top, 2)

                if let content = moment.content, !content.isEmpty {
                    Text(content)
                        .font(.system(size: 15))
                        .foregroundColor(AKColor.text)
                        .lineSpacing(7)
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
                    imageGrid.padding(.top, 8)
                }

                if !moment.videoUrl.isEmpty {
                    videoCell.padding(.top, 8)
                }

                Rectangle().fill(AKColor.line).frame(height: 0.6).padding(.top, 8)

                actionRow

                if !likeList.isEmpty || !moment.comments.isEmpty {
                    interactions.padding(.top, 8)
                }
            }
        }
        .padding(12)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    /// 图片网格：1 张 66% 宽、2-4 张两列、5 张以上三列（对齐安卓 MomentImageGrid）
    @ViewBuilder
    private var imageGrid: some View {
        if images.count == 1 {
            tile(path: images[0], index: 0, side: 231)
                .frame(width: 210, height: 231)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            let cols = images.count <= 4 ? 2 : 3
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: cols),
                      spacing: 3) {
                ForEach(Array(images.enumerated()), id: \.offset) { idx, path in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(tile(path: path, index: idx, side: cols == 2 ? 170 : 110))
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
    }

    /// side：目标展示边长（pt），只用于选择解码像素
    private func tile(path: String, index: Int, side: CGFloat) -> some View {
        AKImage(url: path, size: side)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture { onPreview?(index) }
    }

    private var videoCell: some View {
        ZStack {
            if !moment.videoCover.isEmpty {
                AKImage(url: moment.videoCover,
                        size: CGSize(width: 210, height: 240),
                        placeholder: Color.black.opacity(0.85))
            } else {
                /* 没封面直接黑底：视频地址交给图片解码器也画不出帧，不白花一次下载 */
                Color.black.opacity(0.85)
            }
            Circle()
                .fill(Color.black.opacity(0.55))
                .frame(width: 44, height: 44)
                .overlay(
                    Text("▶")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                )
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(Self.durationText(moment.duration))
                        .font(.system(size: 10.5))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.black.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .padding(6)
                }
            }
        }
        .frame(width: 210, height: 240)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { playVideo = true }
        .fullScreenCover(isPresented: $playVideo) {
            MomentVideoPlayer(url: APIClient.fullURL(moment.videoUrl))
        }
    }

    /// 操作行：转发 / 评论 / 点赞 / 更多（自己的动态），右对齐
    private var actionRow: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Button {
                onRepost?()
            } label: {
                Text("转发")
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.link)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
            }
            .buttonStyle(.plain)
            .disabled(onRepost == nil)
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
                    Image(systemName: liked ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .regular))
                    if likeCount > 0 {
                        Text("\(likeCount)").font(.system(size: 12))
                    }
                }
                .foregroundColor(liked ? AKColor.red : AKColor.muted)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
            }
            .buttonStyle(.plain)
            if isMine, let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18))
                        .foregroundColor(AKColor.muted)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 灰底点赞+评论块
    private var interactions: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !likeList.isEmpty {
                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.red)
                        .padding(.top, 2)
                    Text(likeList.compactMap { $0.name }.joined(separator: "、"))
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.link)
                        .lineSpacing(3)
                }
            }
            if !moment.comments.isEmpty {
                if !likeList.isEmpty {
                    Rectangle().fill(AKColor.line).frame(height: 0.6).padding(.vertical, 6)
                }
                ForEach(moment.comments) { c in
                    commentRow(c)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.fill)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func commentRow(_ c: MomentComment) -> some View {
        HStack(alignment: .top, spacing: 8) {
            AvatarView(url: c.avatar, name: c.name ?? "用户", size: 24)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text((c.name ?? "").isEmpty ? "用户" : (c.name ?? "用户"))
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
        .padding(.horizontal, 2)
    }

    /// 相对时间：刚刚 / N 分钟前 / N 小时前 / N 天前 / 日期
    static func relative(_ ts: Int64) -> String {
        guard ts > 0 else { return "" }
        let diff = Date().timeIntervalSince1970 - TimeInterval(ts)
        if diff < 60 { return "刚刚" }
        if diff < 3600 { return "\(Int(diff / 60)) 分钟前" }
        if diff < 86400 { return "\(Int(diff / 3600)) 小时前" }
        if diff < 86400 * 30 { return "\(Int(diff / 86400)) 天前" }
        return TimeText.short(ts)
    }

    static func durationText(_ sec: Int) -> String {
        let s = max(sec, 0)
        return "\(s / 60):" + String(format: "%02d", s % 60)
    }
}

/// 发布动态：文字 1000 字 + 9 图 + 30 秒/30MB 视频，图片与视频互斥（对齐安卓 PublishMomentScreen）
private struct PublishMomentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppState

    @State private var text = ""
    @State private var items: [PhotosPickerItem] = []
    @State private var previews: [Data] = []
    @State private var publishing = false
    @State private var errorText: String?
    @State private var showEmoji = false

    let onPublish: (String, [String], String, Int, String) async -> Void

    @State private var videoItem: PhotosPickerItem?
    @State private var videoURL: String = ""
    @State private var videoCover: String = ""
    @State private var videoDuration: Int = 0
    @State private var uploadingVideo = false

    private let maxLen = 1000
    private let emojis = ["😀", "😄", "😁", "😆", "😅", "😂", "🙂", "😉",
                          "😍", "🥰", "😘", "😎", "🤔", "😭", "😡", "🥳",
                          "👍", "👏", "🙏", "💪", "❤️", "🔥", "🎉", "🌹"]

    private var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !previews.isEmpty
            || !videoURL.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .font(.system(size: 15))
                        .frame(height: 160)
                        .padding(6)
                        .background(AKColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(AKColor.line, lineWidth: 0.8)
                        )
                        .onChange(of: text) { value in
                            if value.count > maxLen { text = String(value.prefix(maxLen)) }
                        }
                    if text.isEmpty {
                        Text("这一刻的想法…")
                            .font(.system(size: 15))
                            .foregroundColor(AKColor.placeholder)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }

                HStack {
                    Button {
                        showEmoji.toggle()
                    } label: {
                        Text("😊 表情")
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.link)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AKColor.fill)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                    Text("\(text.count)/\(maxLen)")
                        .font(.system(size: 11.5))
                        .foregroundColor(text.count > maxLen - 100 ? AKColor.red : AKColor.placeholder)
                }

                if showEmoji {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 8),
                              spacing: 2) {
                        ForEach(emojis, id: \.self) { e in
                            Button {
                                if text.count + e.count <= maxLen { text += e }
                            } label: {
                                Text(e)
                                    .font(.system(size: 20))
                                    .frame(height: 36)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(6)
                    .background(AKColor.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if !videoURL.isEmpty || uploadingVideo {
                    videoPreview
                } else {
                    imageGrid
                    HStack {
                        Text("\(previews.count)/9 张图片")
                            .font(.system(size: 11.5))
                            .foregroundColor(AKColor.placeholder)
                        Spacer(minLength: 0)
                        PhotosPicker(selection: $videoItem, matching: .videos) {
                            Text(uploadingVideo ? "读取视频中…" : "＋ 视频")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(uploadingVideo ? AKColor.muted : AKColor.link)
                        }
                        .disabled(uploadingVideo)
                    }
                    if previews.isEmpty {
                        Text("视频动态仅支持 1 个视频（30 秒内、30MB 内），与图片不能同时发布")
                            .font(.system(size: 11))
                            .foregroundColor(AKColor.hint)
                            .lineSpacing(3)
                    }
                }

                if let errorText {
                    Text(errorText).font(.system(size: 12)).foregroundColor(AKColor.red)
                }
            }
            .padding(16)
        }
        .background(AKColor.card)
        .navigationTitle("发表动态")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await publish() }
                } label: {
                    Text(publishing ? "发表中…" : "发表")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(AKColor.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(publishing || uploadingVideo || !hasContent)
            }
        }
        .onChange(of: videoItem) { item in
            guard let item else { return }
            Task { await uploadVideo(item) }
        }
        .onChange(of: items) { list in
            Task { await loadImages(list) }
        }
    }

    private var videoPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if APIClient.fullURL(videoCover) != nil {
                        AKImage(url: videoCover,
                                size: CGSize(width: 150, height: 150),
                                placeholder: Color.black)
                    } else {
                        Color.black
                    }
                }
                .frame(width: 150, height: 150)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 38, height: 38)
                        .overlay(Text("▶").font(.system(size: 16)).foregroundColor(.white))
                )

                Button {
                    videoItem = nil
                    videoURL = ""
                    videoCover = ""
                    videoDuration = 0
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(3)
            }
            Text("视频 \(videoDuration) 秒 · 仅支持 30 秒内的视频")
                .font(.system(size: 11.5))
                .foregroundColor(AKColor.placeholder)
            Button {
                videoItem = nil
                videoURL = ""
                videoCover = ""
                videoDuration = 0
            } label: {
                Text("移除后可重新选择图片")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.link)
            }
            .buttonStyle(.plain)
        }
    }

    private var imageGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(100), spacing: 8), count: 3),
                  alignment: .leading, spacing: 8) {
            ForEach(Array(previews.enumerated()), id: \.offset) { idx, data in
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            AKColor.fill
                        }
                    }
                    .frame(width: 100, height: 100)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Button {
                        previews.remove(at: idx)
                        if idx < items.count { items.remove(at: idx) }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(3)
                }
            }
            if previews.count < 9 {
                PhotosPicker(selection: $items, maxSelectionCount: 9, matching: .images) {
                    Image(systemName: "plus")
                        .font(.system(size: 20))
                        .foregroundColor(AKColor.muted)
                        .frame(width: 100, height: 100)
                        .background(AKColor.fill)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    private func loadImages(_ list: [PhotosPickerItem]) async {
        var dataList: [Data] = []
        for item in list {
            if let data = try? await item.loadTransferable(type: Data.self) {
                dataList.append(data)
            }
        }
        await MainActor.run {
            previews = dataList
            if !dataList.isEmpty {
                videoItem = nil
                videoURL = ""
                videoCover = ""
                videoDuration = 0
            }
        }
    }

    /// 视频：30MB / 30 秒校验 → 上传 → 抽首帧当封面（kind=moment）
    private func uploadVideo(_ item: PhotosPickerItem) async {
        uploadingVideo = true
        errorText = nil
        defer { uploadingVideo = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            if data.count > 30 * 1024 * 1024 {
                errorText = "视频不能超过 30MB（当前 \(data.count / 1024 / 1024)MB）"
                return
            }
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("moment_\(Int(Date().timeIntervalSince1970)).mov")
            try data.write(to: tmp)
            defer { try? FileManager.default.removeItem(at: tmp) }

            let asset = AVURLAsset(url: tmp)
            let seconds = Int(CMTimeGetSeconds(asset.duration))
            if seconds <= 0 {
                errorText = "无法读取视频时长，请换一个视频"
                return
            }
            if seconds > 30 {
                errorText = "视频时长需在 30 秒以内（当前 \(seconds) 秒）"
                return
            }
            videoDuration = seconds

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
            items = []
            previews = []
        } catch {
            errorText = "视频上传失败：\(error.localizedDescription)"
        }
    }

    /// 取视频首帧压缩成 jpg
    private static func coverData(from asset: AVURLAsset) -> Data? {
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 1080, height: 1080)
        guard let cg = try? gen.copyCGImage(at: CMTime(seconds: 0.2, preferredTimescale: 600),
                                           actualTime: nil) else {
            return nil
        }
        return UIImage(cgImage: cg).jpegData(compressionQuality: 0.85)
    }

    private func publish() async {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if content.isEmpty && previews.isEmpty && videoURL.isEmpty {
            errorText = "请输入内容或添加图片/视频"
            return
        }
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
        await onPublish(content, urls, videoURL, videoDuration, videoCover)
        dismiss()
    }
}

/// 朋友圈评论弹层：身份卡 + 500 字输入（对齐安卓 MomentReplySheet）
private struct MomentReplySheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    let moment: Moment
    @State private var text = ""
    @State private var sending = false

    private var myName: String { app.user?.displayName ?? "我" }
    private var myNo: String { app.user?.prettyYxid ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("发表评论")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AKColor.text)
                    Text("友善交流，理性发言")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.hint)
                }
                Spacer(minLength: 0)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AKColor.muted)
                        .frame(width: 32, height: 32)
                        .background(AKColor.fill)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 9) {
                AvatarView(url: app.user?.avatar, name: myName, size: 38)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(myName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AKColor.text)
                        if !myNo.isEmpty { PrettyBadge(number: myNo) }
                        if (app.user?.vipLevel ?? 0) > 0 {
                            VipBadge(level: app.user?.vipLevel ?? 0)
                        }
                    }
                    Text(myNo.isEmpty ? "AK商聊用户" : "AK号 \(myNo)")
                        .font(.system(size: 11))
                        .foregroundColor(myNo.isEmpty ? AKColor.hint : AKColor.gold)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                LinearGradient(colors: [AKColor.brandSoft, AKColor.goldSoft.opacity(0.65)],
                               startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(size: 14))
                    .frame(height: 120)
                    .padding(6)
                    .background(AKColor.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onChange(of: text) { value in
                        if value.count > 500 { text = String(value.prefix(500)) }
                    }
                if text.isEmpty {
                    Text("说点什么…")
                        .font(.system(size: 13.5))
                        .foregroundColor(AKColor.placeholder)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }

            HStack {
                Spacer(minLength: 0)
                Text("\(text.count)/500")
                    .font(.system(size: 11))
                    .foregroundColor(AKColor.placeholder)
            }

            Button {
                Task { await send() }
            } label: {
                Text(sending ? "发送中…" : "发送")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(sending ? AKColor.hint : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        LinearGradient(colors: sending
                                        ? [AKColor.fill, AKColor.fill]
                                        : [AKColor.brand, Color(hex: 0x6C5CF0)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(sending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(18)
        .presentationDetents([.height(430), .large])
        .presentationDragIndicator(.hidden)
    }

    private func send() async {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !sending else { return }
        sending = true
        defer { sending = false }
        await app.commentMoment(moment, content: content)
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
