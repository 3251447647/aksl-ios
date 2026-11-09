import SwiftUI
import PhotosUI
import UIKit

/// 群公告：列表 → 详情（我已知晓）→ 发布/编辑/删除，与安卓保持一致
struct GroupNoticesView: View {
    let groupId: Int64

    @State private var notices: [GroupNotice] = []
    @State private var canManage = false
    @State private var loading = true
    @State private var showEditor = false

    var body: some View {
        List {
            if loading && notices.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else if notices.isEmpty {
                Text("还没有群公告")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.hint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
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
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                Color.clear
                    .frame(height: 10)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AKColor.bg.ignoresSafeArea())
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
        .refreshable { await load() }
        .task { await load() }
    }

    @ViewBuilder
    private func row(_ n: GroupNotice) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if n.isTop == 1 || n.needAck == 1 {
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
                Text(n.needAck == 1 ? "\(n.ackCount) 人已确认" : "\(n.readCount) 人已读")
                    .font(.system(size: 11.5))
                    .foregroundColor(n.needAck == 1 && n.myAck != 1 ? AKColor.link : AKColor.hint)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func load() async {
        loading = true
        defer { loading = false }
        if let data = try? await APIClient.shared.groupNotices(gid: groupId) {
            notices = data.list
            canManage = data.canManage == 1
        }
    }
}

/// 公告图片缩略（4 列折行），列表卡片与详情共用
private struct NoticeImageGrid: View {
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
            ForEach(paths, id: \.self) { path in
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
    @State var notice: GroupNotice
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
        guard let data = try? await APIClient.shared.groupNotices(gid: groupId) else { return }
        if let fresh = data.list.first(where: { $0.id == notice.id }) {
            notice = fresh
        }
    }
}

/// 发布 / 编辑群公告：正文 + 最多 9 张图（弹窗与需确认由服务端固定开启）
private struct GroupNoticeEditor: View {
    @Environment(\.dismiss) private var dismiss
    let groupId: Int64
    let initial: GroupNotice?
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
                    images = Array(initial.imageList.prefix(9))
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
        saving = true
        defer { saving = false }
        let json = (try? JSONSerialization.data(withJSONObject: images)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        await APIClient.shared.saveGroupNotice(
            gid: groupId,
            id: initial?.id ?? 0,
            content: text.trimmingCharacters(in: .whitespacesAndNewlines),
            imagesJSON: json
        )
        await onSaved()
        dismiss()
    }
}
