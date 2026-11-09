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

/// 群公告：列表 → 详情（我已知晓）→ 发布/编辑/删除；列表里的已读/已确认人数可点开名单
/// 结构对齐安卓 GroupNoticeListScreen.kt / GroupNoticeDetailScreen.kt / GroupNoticeEditScreen.kt
struct GroupNoticesView: View {
    let groupId: Int64

    @State private var notices: [GroupNoticeItem] = []
    @State private var canManage = false
    @State private var loading = true
    @State private var showEditor = false
    @State private var ackTarget: Int64 = 0
    @State private var acks: GroupNoticeAcks?
    @State private var ackTab = 0

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
                        NavigationLink {
                            GroupNoticeDetailView(groupId: groupId, notice: n, canManage: canManage) {
                                Task { await load() }
                            }
                        } label: {
                            row(n)
                        }
                        .buttonStyle(.plain)
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
        .toolbar {
            if canManage {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showEditor = true } label: { Image(systemName: "square.and.pencil") }
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            GroupNoticeEditor(groupId: groupId, initial: nil) { await load() }
        }
        .sheet(isPresented: Binding(get: { ackTarget > 0 }, set: { if !$0 { ackTarget = 0; acks = nil } })) {
            ackSheet
        }
        .refreshable { await load() }
        .task { await load() }
    }

    private func row(_ n: GroupNoticeItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if n.isTop == 1 || n.needAck == 1 || (n.myAck != 1 && n.needAck == 1) {
                HStack(spacing: 6) {
                    if n.isTop == 1 { BadgeView(text: "置顶", color: AKColor.link, background: AKColor.blueSoft) }
                    if n.needAck == 1 { BadgeView(text: "需确认", color: AKColor.gold, background: AKColor.goldSoft) }
                    Spacer(minLength: 0)
                    if n.needAck == 1 && n.myAck != 1 {
                        Circle().fill(AKColor.red).frame(width: 6, height: 6)
                    }
                }
            }
            Text((n.content ?? "").isEmpty ? "（空公告）" : (n.content ?? ""))
                .font(.system(size: 14))
                .foregroundColor(AKColor.text)
                .lineSpacing(3)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !n.imageList.isEmpty {
                NoticeImageGrid(paths: n.imageList, size: 62, spacing: 5, corners: 8)
            }
            HStack(spacing: 6) {
                Text("\((n.publisherName ?? "").isEmpty ? "群成员" : (n.publisherName ?? "")) · \(TimeText.full(n.createdAt))")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.hint)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Button {
                    ackTab = n.needAck == 1 ? 1 : 0
                    acks = nil
                    ackTarget = n.id
                    Task { await loadAcks(n.id) }
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 已读 / 已确认名单

    private var ackSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("已读与确认")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AKColor.text)
                .padding(.horizontal, 18)
                .padding(.top, 18)
            HStack(spacing: 18) {
                ackTabButton("已读 \(acks?.readCount ?? 0)", index: 0)
                ackTabButton("已确认 \(acks?.ackCount ?? 0)", index: 1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            Rectangle().fill(AKColor.line).frame(height: 0.5).padding(.top, 6)

            let list = ackTab == 0 ? (acks?.readList ?? []) : (acks?.ackList ?? [])
            if list.isEmpty {
                Text(ackTab == 0 ? "还没有人读过" : "还没有人确认")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.hint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
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
                                Text(TimeText.full(u.at))
                                    .font(.system(size: 11))
                                    .foregroundColor(AKColor.hint)
                            }
                            .padding(.horizontal, 18)
                            .frame(height: 52)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .background(AKColor.card.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }

    private func ackTabButton(_ text: String, index: Int) -> some View {
        Button {
            ackTab = index
        } label: {
            VStack(spacing: 5) {
                Text(text)
                    .font(.system(size: 13.5, weight: ackTab == index ? .semibold : .regular))
                    .foregroundColor(ackTab == index ? AKColor.text : AKColor.hint)
                Rectangle()
                    .fill(ackTab == index ? AKColor.brand : Color.clear)
                    .frame(width: 28, height: 2)
            }
        }
        .buttonStyle(.plain)
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

    private func loadAcks(_ id: Int64) async {
        if let data: GroupNoticeAcks = try? await APIClient.shared.get(
            "api/v1/group/notice/acks", query: ["id": "\(id)"]
        ) {
            acks = data
        }
    }
}

/// 公告图片缩略（4 列折行），列表卡片与详情共用
struct NoticeImageGrid: View {
    let paths: [String]
    var size: CGFloat
    var spacing: CGFloat
    var corners: CGFloat

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(size), spacing: spacing, alignment: .leading), count: 4),
            alignment: .leading,
            spacing: spacing
        ) {
            ForEach(Array(paths.prefix(9)), id: \.self) { path in
                AsyncImage(url: APIClient.fullURL(path)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        AKColor.fill
                    }
                }
                .frame(width: size, height: size)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: corners, style: .continuous))
            }
        }
    }
}

/// 公告详情：全文 + 九宫格图片 + 我已知晓；群主/管理员可编辑、删除
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 12) {
                    if notice.isTop == 1 {
                        BadgeView(text: "置顶", color: AKColor.link, background: AKColor.blueSoft)
                    }
                    Text(notice.content ?? "")
                        .font(.system(size: 15))
                        .foregroundColor(AKColor.text)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !notice.imageList.isEmpty {
                        NoticeImageGrid(paths: notice.imageList, size: 92, spacing: 6, corners: 8)
                    }
                    Rectangle().fill(AKColor.line).frame(height: 0.5)
                    HStack(spacing: 8) {
                        AvatarView(url: nil, name: notice.publisherName ?? "群成员", size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text((notice.publisherName ?? "").isEmpty ? "群成员" : (notice.publisherName ?? ""))
                                .font(.system(size: 13))
                                .foregroundColor(AKColor.text)
                            Text(TimeText.full(notice.createdAt))
                                .font(.system(size: 11))
                                .foregroundColor(AKColor.hint)
                        }
                        Spacer(minLength: 6)
                        Text(notice.needAck == 1 ? "\(notice.ackCount) 人已确认" : "\(notice.readCount) 人已读")
                            .font(.system(size: 12))
                            .foregroundColor(AKColor.hint)
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
        .navigationTitle("公告详情")
        .navigationBarTitleDisplayMode(.inline)
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
        .sheet(isPresented: $showEditor) {
            GroupNoticeEditor(groupId: groupId, initial: notice) {
                await reload()
                await onChanged()
            }
        }
        .confirmationDialog("删除后群成员将看不到这条公告", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) { Task { await remove() } }
            Button("取消", role: .cancel) {}
        }
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

/// 发布 / 编辑群公告：正文 1~600 字 + 最多 9 张图；置顶/需确认/弹窗/新成员可见沿用原公告的值
private struct GroupNoticeEditor: View {
    @Environment(\.dismiss) private var dismiss
    let groupId: Int64
    let initial: GroupNoticeItem?
    let onSaved: () async -> Void

    @State private var text: String = ""
    @State private var images: [String] = []
    @State private var items: [PhotosPickerItem] = []
    @State private var saving = false
    @State private var uploading = false
    @State private var errorText: String?

    private let cell: CGFloat = 74

    var body: some View {
        NavigationStack {
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
                                PhotosPicker(selection: $items, maxSelectionCount: 9, matching: .images) {
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
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
            .background(AKColor.bg.ignoresSafeArea())
            .navigationTitle(initial == nil ? "发布群公告" : "编辑群公告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "发布中" : "发布") { Task { await save() } }
                        .disabled(saving || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let initial {
                    text = initial.content ?? ""
                    images = initial.imageList
                }
            }
            .onChange(of: items) { _ in
                Task { await appendPicked() }
            }
        }
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
                "is_top": initial?.isTop ?? 0,
                "need_ack": initial?.needAck ?? 0,
                "popup": initial?.popup ?? 0,
                "send_to_new": initial?.sendToNew ?? 0,
            ])
            await onSaved()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
