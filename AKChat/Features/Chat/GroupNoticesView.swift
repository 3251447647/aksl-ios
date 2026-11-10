import SwiftUI
import PhotosUI

/// 群公告条目：字段与安卓 GroupNoticeDto 一一对应（含 popup / send_to_new，编辑时要原样带回去）
struct GroupNoticeItem: Decodable, Identifiable, Equatable {
    let id: Int64
    let content: String?
    let images: String?
    let isTop: Int
    let needAck: Int
    let popup: Int
    let sendToNew: Int
    let publisherId: Int64
    let publisherName: String?
    let createdAt: Int64
    let readCount: Int
    let ackCount: Int
    let totalMembers: Int
    let myRead: Int
    let myAck: Int
    let canManage: Int

    enum CodingKeys: String, CodingKey {
        case id, content, images, popup
        case isTop = "is_top"
        case needAck = "need_ack"
        case sendToNew = "send_to_new"
        case publisherId = "publisher_id"
        case publisherName = "publisher_name"
        case createdAt = "created_at"
        case readCount = "read_count"
        case ackCount = "ack_count"
        case totalMembers = "total_members"
        case myRead = "my_read"
        case myAck = "my_ack"
        case canManage = "can_manage"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        content = try? c.decode(String.self, forKey: .content)
        images = try? c.decode(String.self, forKey: .images)
        isTop = (try? c.decode(Int.self, forKey: .isTop)) ?? 0
        needAck = (try? c.decode(Int.self, forKey: .needAck)) ?? 0
        popup = (try? c.decode(Int.self, forKey: .popup)) ?? 0
        sendToNew = (try? c.decode(Int.self, forKey: .sendToNew)) ?? 0
        publisherId = (try? c.decode(Int64.self, forKey: .publisherId)) ?? 0
        publisherName = try? c.decode(String.self, forKey: .publisherName)
        createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
        readCount = (try? c.decode(Int.self, forKey: .readCount)) ?? 0
        ackCount = (try? c.decode(Int.self, forKey: .ackCount)) ?? 0
        totalMembers = (try? c.decode(Int.self, forKey: .totalMembers)) ?? 0
        myRead = (try? c.decode(Int.self, forKey: .myRead)) ?? 0
        myAck = (try? c.decode(Int.self, forKey: .myAck)) ?? 0
        canManage = (try? c.decode(Int.self, forKey: .canManage)) ?? 0
    }

    var imageList: [String] {
        guard let images, let data = images.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [String] else { return [] }
        return Array(arr.prefix(9))
    }
}

struct GroupNoticeListResp: Decodable {
    let list: [GroupNoticeItem]
    let canManage: Int

    enum CodingKeys: String, CodingKey {
        case list
        case canManage = "can_manage"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decode([GroupNoticeItem].self, forKey: .list)) ?? []
        canManage = (try? c.decode(Int.self, forKey: .canManage)) ?? 0
    }
}

struct GroupNoticeAckUser: Decodable, Identifiable {
    let uid: Int64
    let name: String?
    let avatar: String?
    let at: Int64

    var id: Int64 { uid }
}

struct GroupNoticeAcks: Decodable {
    let readList: [GroupNoticeAckUser]
    let ackList: [GroupNoticeAckUser]
    let readCount: Int
    let ackCount: Int

    enum CodingKeys: String, CodingKey {
        case readList = "read_list"
        case ackList = "ack_list"
        case readCount = "read_count"
        case ackCount = "ack_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        readList = (try? c.decode([GroupNoticeAckUser].self, forKey: .readList)) ?? []
        ackList = (try? c.decode([GroupNoticeAckUser].self, forKey: .ackList)) ?? []
        readCount = (try? c.decode(Int.self, forKey: .readCount)) ?? 0
        ackCount = (try? c.decode(Int.self, forKey: .ackCount)) ?? 0
    }
}

/// 群公告时间：对齐安卓 noticeTime，固定「yyyy年M月d日 HH:mm」（北京时间）
enum GroupNoticeTime {
    static func full(_ ts: Int64) -> String {
        guard ts > 0 else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)!
        f.dateFormat = "yyyy年M月d日 HH:mm"
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }
}

/// 群公告：列表 → 详情（我已知晓）→ 发布/编辑/删除；列表里的已读/已确认人数可点开名单
/// 对齐安卓 GroupNoticeListScreen.kt / GroupNoticeDetailScreen.kt / GroupNoticeEditScreen.kt
struct GroupNoticesView: View {
    let groupId: Int64

    @State private var notices: [GroupNoticeItem] = []
    @State private var canManage = false
    @State private var loading = true
    @State private var showEditor = false
    @State private var selected: GroupNoticeItem?
    @State private var ackPage: AckPageTarget?

    private struct AckPageTarget: Equatable {
        let noticeId: Int64
        let tab: Int
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 9) {
                if loading && notices.isEmpty {
                    ProgressView().padding(.top, 60)
                } else if notices.isEmpty {
                    Text("还没有群公告")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.hint)
                        .padding(.top, 60)
                } else {
                    ForEach(notices) { n in
                        row(n)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .reportsDetailPage()
        .navigationTitle("群公告")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if canManage {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showEditor = true } label: { Image(systemName: "square.and.pencil") }
                }
            }
        }
        .navigationDestination(isPresented: $showEditor) {
            GroupNoticeEditor(groupId: groupId, initial: nil) { await load() }
                .reportsDetailPage()
                .restoresSwipeBack()
        }
        .navigationDestination(isPresented: Binding(
            get: { selected != nil },
            set: { if !$0 { selected = nil } }
        )) {
            if let n = selected {
                GroupNoticeDetailView(
                    groupId: groupId,
                    notice: n,
                    canManage: canManage || n.canManage == 1
                ) { await load() }
                    .restoresSwipeBack()
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { ackPage != nil },
            set: { if !$0 { ackPage = nil } }
        )) {
            if let target = ackPage {
                GroupNoticeAcksPage(noticeId: target.noticeId, initialTab: target.tab)
                    .restoresSwipeBack()
            }
        }
        .refreshable { await load() }
        .task { await load() }
    }

    private func row(_ n: GroupNoticeItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                if n.isTop == 1 || n.needAck == 1 {
                    HStack(spacing: 6) {
                        if n.isTop == 1 {
                            noticePill("置顶", color: AKColor.link, background: AKColor.blueSoft)
                        }
                        if n.needAck == 1 {
                            noticePill("需确认", color: AKColor.gold, background: AKColor.goldSoft)
                        }
                        Spacer(minLength: 0)
                        if n.needAck == 1 && n.myAck != 1 {
                            Circle().fill(AKColor.red).frame(width: 6, height: 6)
                        }
                    }
                    .padding(.bottom, 7)
                }

                AKLinkText(
                    text: (n.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "（空公告）" : (n.content ?? ""),
                    color: AKColor.text,
                    fontSize: 14,
                    lineHeight: 21
                )
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)

                if !n.imageList.isEmpty {
                    NoticeImageGrid(paths: n.imageList, size: 62, spacing: 5, corners: 8)
                        .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { selected = n }

            HStack(spacing: 6) {
                Text("\((n.publisherName ?? "").isEmpty ? "群成员" : (n.publisherName ?? "")) · \(GroupNoticeTime.full(n.createdAt))")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.hint)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Button {
                    ackPage = AckPageTarget(noticeId: n.id, tab: 0)
                } label: {
                    Text(n.needAck == 1 ? "\(n.ackCount) 人已确认" : "\(n.readCount) 人已读")
                        .font(.system(size: 11.5))
                        .foregroundColor(n.needAck == 1 && n.myAck != 1 ? AKColor.link : AKColor.hint)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func noticePill(_ text: String, color: Color, background: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    // MARK: - 数据

    private func load() async {
        loading = true
        defer { loading = false }
        if let data: GroupNoticeListResp = try? await APIClient.shared.get(
            "api/v1/group/notices", query: ["gid": "\(groupId)"]
        ) {
            notices = data.list
            canManage = data.canManage == 1
        }
    }
}

/// 已读 / 已确认名单：安卓是底部弹层，iOS 统一走 push 页
struct GroupNoticeAcksPage: View {
    let noticeId: Int64

    @State private var acks: GroupNoticeAcks? = nil
    @State private var tab: Int

    init(noticeId: Int64, initialTab: Int = 0) {
        self.noticeId = noticeId
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 18) {
                tabButton("已读 \(acks?.readCount ?? 0)", index: 0)
                tabButton("已确认 \(acks?.ackCount ?? 0)", index: 1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            Rectangle().fill(AKColor.line).frame(height: 0.5).padding(.top, 6)

            let list = tab == 0 ? (acks?.readList ?? []) : (acks?.ackList ?? [])
            if list.isEmpty {
                Text(tab == 0 ? "还没有人读过" : "还没有人确认")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.hint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(list) { u in
                            HStack(spacing: 10) {
                                AvatarView(url: u.avatar, name: u.name ?? "成员", size: 36)
                                Text((u.name ?? "").isEmpty ? "成员" : (u.name ?? ""))
                                    .font(.system(size: 14))
                                    .foregroundColor(AKColor.text)
                                    .lineLimit(1)
                                Spacer(minLength: 6)
                                Text(GroupNoticeTime.full(u.at))
                                    .font(.system(size: 11))
                                    .foregroundColor(AKColor.hint)
                            }
                            .padding(.horizontal, 18)
                            .frame(height: 52)
                        }
                    }
                }
            }
        }
        .background(AKColor.card.ignoresSafeArea())
        .reportsDetailPage()
        .navigationTitle("已读与确认")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { BackButton() }
        }
        .task { await load() }
    }

    private func tabButton(_ text: String, index: Int) -> some View {
        Button {
            tab = index
        } label: {
            VStack(spacing: 5) {
                Text(text)
                    .font(.system(size: 13.5, weight: tab == index ? .semibold : .regular))
                    .foregroundColor(tab == index ? AKColor.text : AKColor.hint)
                Rectangle()
                    .fill(tab == index ? AKColor.brand : Color.clear)
                    .frame(width: 28, height: 2)
            }
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        if let data: GroupNoticeAcks = try? await APIClient.shared.get(
            "api/v1/group/notice/acks", query: ["id": "\(noticeId)"]
        ) {
            acks = data
        }
    }
}

/// 公告图片缩略（4 列折行），列表卡片、详情、进群弹窗共用
struct NoticeImageGrid: View {
    let paths: [String]
    var size: CGFloat
    var spacing: CGFloat
    var corners: CGFloat
    /// true 时按可用宽度均分（详情页用），false 时固定 size（列表/弹窗用）
    var flexible: Bool = false
    var onTap: ((Int) -> Void)? = nil

    private var columns: [GridItem] {
        let item = flexible
            ? GridItem(.flexible(), spacing: spacing)
            : GridItem(.fixed(size), spacing: spacing, alignment: .leading)
        return Array(repeating: item, count: 4)
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
            ForEach(Array(paths.prefix(9).enumerated()), id: \.offset) { index, path in
                Group {
                    if flexible {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(thumbnail(path))
                            .clipped()
                    } else {
                        thumbnail(path)
                            .frame(width: size, height: size)
                            .clipped()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: corners, style: .continuous))
                .contentShape(Rectangle())
                .allowsHitTesting(onTap != nil)
                .onTapGesture { onTap?(index) }
            }
        }
    }

    @ViewBuilder
    private func thumbnail(_ path: String) -> some View {
        AsyncImage(url: APIClient.fullURL(path)) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                AKColor.fill
            }
        }
    }
}

/// 公告详情：全文 + 九宫格图片 + 我已知晓；群主/管理员可编辑、删除、看已读名单
struct GroupNoticeDetailView: View {
    let groupId: Int64
    @State var notice: GroupNoticeItem
    let canManage: Bool
    let onChanged: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var acking = false
    @State private var showEditor = false
    @State private var confirmDelete = false
    @State private var errorText: String?
    @State private var preview: PreviewImage? = nil
    @State private var showAcks = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 12) {
                    if notice.isTop == 1 {
                        Text("置顶")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AKColor.link)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(AKColor.blueSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    AKLinkText(
                        text: notice.content ?? "",
                        color: AKColor.text,
                        fontSize: 15,
                        lineHeight: 23
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if !notice.imageList.isEmpty {
                        NoticeImageGrid(paths: notice.imageList, size: 92, spacing: 6, corners: 8, flexible: true) { index in
                            openPreview(at: index)
                        }
                    }
                    Rectangle().fill(AKColor.line).frame(height: 0.5)
                    HStack(spacing: 8) {
                        AvatarView(url: nil, name: notice.publisherName ?? "群成员", size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text((notice.publisherName ?? "").isEmpty ? "群成员" : (notice.publisherName ?? ""))
                                .font(.system(size: 13))
                                .foregroundColor(AKColor.text)
                            Text(GroupNoticeTime.full(notice.createdAt))
                                .font(.system(size: 11))
                                .foregroundColor(AKColor.hint)
                        }
                        Spacer(minLength: 6)
                        if canManage {
                            Button { showAcks = true } label: {
                                countText.contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        } else {
                            countText
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AKColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if let errorText {
                    Text(errorText)
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.red)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .reportsDetailPage()
        .navigationTitle("公告详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { ackBar }
        .toolbar {
            if canManage {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        Button { showEditor = true } label: { Image(systemName: "square.and.pencil") }
                        Button { confirmDelete = true } label: { Image(systemName: "trash") }
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showEditor) {
            GroupNoticeEditor(groupId: groupId, initial: notice) {
                await reload()
                await onChanged()
            }
            .reportsDetailPage()
            .restoresSwipeBack()
        }
        .navigationDestination(isPresented: $showAcks) {
            GroupNoticeAcksPage(noticeId: notice.id)
                .restoresSwipeBack()
        }
        .alert("删除公告", isPresented: $confirmDelete) {
            Button("删除", role: .destructive) { Task { await remove() } }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后群成员将看不到这条公告，确定删除吗？")
        }
        .fullScreenCover(item: $preview) { item in
            MediaPagerView(items: item.items, index: item.index)
        }
    }

    private var countText: some View {
        Text(notice.needAck == 1 ? "\(notice.ackCount) 人已确认" : "\(notice.readCount) 人已读")
            .font(.system(size: 12))
            .foregroundColor(AKColor.hint)
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
    }

    private var ackBar: some View {
        let acked = notice.myAck == 1 || notice.needAck != 1
        return Button {
            Task { await ack() }
        } label: {
            Text(notice.myAck == 1 ? "已确认" : "我已知晓")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(acked ? AKColor.hint : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(acked ? AKColor.fill : AKColor.brand)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(acked || acking)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AKColor.card)
    }

    private func openPreview(at index: Int) {
        let urls = notice.imageList.compactMap { APIClient.fullURL($0) }
        guard !urls.isEmpty else { return }
        preview = PreviewImage(
            items: urls.map { PreviewMedia(url: $0, isVideo: false, message: nil) },
            index: min(index, urls.count - 1)
        )
    }

    private func ack() async {
        acking = true
        defer { acking = false }
        await APIClient.shared.ackGroupNotice(id: notice.id)
        await reload()
        await onChanged()
    }

    private func remove() async {
        await APIClient.shared.deleteGroupNotice(gid: groupId, id: notice.id)
        await onChanged()
        dismiss()
    }

    /// 确认/编辑后重新拉一次列表，刷新本条数据
    private func reload() async {
        guard let data: GroupNoticeListResp = try? await APIClient.shared.get(
            "api/v1/group/notices", query: ["gid": "\(groupId)"]
        ) else { return }
        if let fresh = data.list.first(where: { $0.id == notice.id }) {
            notice = fresh
        }
    }
}

/// 发布 / 编辑群公告：正文 1~600 字 + 最多 9 张图 + 四个发布开关
private struct GroupNoticeEditor: View {
    @Environment(\.dismiss) private var dismiss
    let groupId: Int64
    let initial: GroupNoticeItem?
    let onSaved: () async -> Void

    @State private var text: String = ""
    @State private var images: [String] = []
    @State private var items: [PhotosPickerItem] = []
    @State private var isTop = false
    @State private var needAck = false
    @State private var popup = false
    @State private var sendToNew = false
    @State private var saving = false
    @State private var uploading = false
    @State private var errorText: String?

    private let cell: CGFloat = 74

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $text)
                        .font(.system(size: 14))
                        .foregroundColor(AKColor.text)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 150)
                        .onChange(of: text) { value in
                            if value.count > 600 { text = String(value.prefix(600)) }
                        }
                    Text("\(text.count)/600")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.hint)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Text("添加照片")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.sub)
                        .padding(.top, 4)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(cell), spacing: 6, alignment: .leading), count: 4),
                        alignment: .leading,
                        spacing: 6
                    ) {
                        ForEach(images, id: \.self) { path in
                            ZStack(alignment: .topTrailing) {
                                AsyncImage(url: APIClient.fullURL(path)) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        AKColor.fill
                                    }
                                }
                                .frame(width: cell, height: cell)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                Button {
                                    images.removeAll { $0 == path }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 18, height: 18)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if images.count < 9 {
                            PhotosPicker(selection: $items,
                                         maxSelectionCount: max(1, 9 - images.count),
                                         matching: .images) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AKColor.fill)
                                    if uploading {
                                        Text("上传中").font(.system(size: 11)).foregroundColor(AKColor.hint)
                                    } else {
                                        Image(systemName: "plus")
                                            .font(.system(size: 22))
                                            .foregroundColor(AKColor.placeholder)
                                    }
                                }
                                .frame(width: cell, height: cell)
                            }
                        }
                    }

                    if let errorText {
                        Text(errorText).font(.system(size: 12)).foregroundColor(AKColor.red)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AKColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(spacing: 0) {
                    switchRow("进群弹窗提醒", isOn: $popup)
                    Rectangle().fill(AKColor.line).frame(height: 0.5)
                    switchRow("需要成员确认", isOn: $needAck)
                    Rectangle().fill(AKColor.line).frame(height: 0.5)
                    switchRow("置顶公告", isOn: $isTop)
                    Rectangle().fill(AKColor.line).frame(height: 0.5)
                    switchRow("新成员可见", isOn: $sendToNew)
                }
                .padding(.horizontal, 14)
                .background(AKColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .navigationTitle(initial == nil ? "发布群公告" : "编辑群公告")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { BackButton() }
            ToolbarItem(placement: .confirmationAction) {
                Button(saving ? "发布中" : "发布") { Task { await save() } }
                    .disabled(saving || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            if let initial {
                text = initial.content ?? ""
                images = initial.imageList
                isTop = initial.isTop == 1
                needAck = initial.needAck == 1
                popup = initial.popup == 1
                sendToNew = initial.sendToNew == 1
            }
        }
        .onChange(of: items) { _ in
            Task { await appendPicked() }
        }
    }

    private func switchRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(AKColor.text)
        }
        .tint(AKColor.brand)
        .frame(height: 50)
    }

    private func appendPicked() async {
        guard !items.isEmpty else { return }
        uploading = true
        defer {
            uploading = false
            items = []
        }
        for item in items {
            if images.count >= 9 { break }
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            do {
                let up = try await APIClient.shared.upload(
                    data: data,
                    filename: "notice_\(Int(Date().timeIntervalSince1970))_\(images.count).jpg",
                    kind: "chat"
                )
                if images.count < 9 { images.append(up.url) }
            } catch {
                errorText = "图片上传失败：\(error.localizedDescription)"
            }
        }
    }

    private func save() async {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard body.count >= 1, body.count <= 600 else {
            errorText = "公告内容需为 1~600 字"
            return
        }
        saving = true
        defer { saving = false }
        let json = (try? JSONSerialization.data(withJSONObject: images)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        do {
            _ = try await APIClient.shared.postRaw("api/v1/group/notice", body: [
                "gid": groupId,
                "id": initial?.id ?? 0,
                "content": body,
                "images": json,
                "is_top": isTop ? 1 : 0,
                "need_ack": needAck ? 1 : 0,
                "popup": popup ? 1 : 0,
                "send_to_new": sendToNew ? 1 : 0,
            ])
            await onSaved()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
