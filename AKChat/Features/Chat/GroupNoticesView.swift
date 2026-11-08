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
            if notices.isEmpty && !loading {
                Text("暂无群公告")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.muted)
            }
            ForEach(notices) { n in
                NavigationLink {
                    GroupNoticeDetailView(groupId: groupId, notice: n, canManage: canManage) {
                        Task { await load() }
                    }
                } label: {
                    row(n)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("群公告")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canManage {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showEditor = true } label: { Image(systemName: "plus") }
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
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                if n.isTop == 1 { BadgeView(text: "置顶", color: AKColor.link, background: AKColor.blueSoft) }
                if n.needAck == 1 { BadgeView(text: "需确认", color: AKColor.gold, background: AKColor.goldSoft) }
                Spacer()
            }
            Text(n.content ?? "")
                .font(.system(size: 14))
                .foregroundColor(AKColor.text)
                .lineLimit(3)
            if !n.imageList.isEmpty {
                HStack(spacing: 6) {
                    ForEach(n.imageList.prefix(4), id: \.self) { path in
                        AsyncImage(url: APIClient.fullURL(path)) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                AKColor.fill
                            }
                        }
                        .frame(width: 68, height: 68)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            HStack {
                Text("\(n.publisherName ?? "群成员") · \(TimeText.short(n.createdAt))")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.hint)
                    .lineLimit(1)
                Spacer()
                Text(n.needAck == 1 ? "\(n.ackCount) 人已确认" : "\(n.readCount) 人已读")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.hint)
            }
        }
        .padding(.vertical, 6)
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
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    if notice.isTop == 1 || notice.needAck == 1 {
                        HStack(spacing: 6) {
                            if notice.isTop == 1 { BadgeView(text: "置顶", color: AKColor.link, background: AKColor.blueSoft) }
                            if notice.needAck == 1 { BadgeView(text: "需确认", color: AKColor.gold, background: AKColor.goldSoft) }
                            Spacer()
                        }
                    }
                    Text(notice.content ?? "")
                        .font(.system(size: 14.5))
                        .foregroundColor(AKColor.text)
                    if !notice.imageList.isEmpty {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                            ForEach(notice.imageList, id: \.self) { path in
                                AsyncImage(url: APIClient.fullURL(path)) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        AKColor.fill
                                    }
                                }
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    Text("\(notice.publisherName ?? "群成员") · \(TimeText.short(notice.createdAt))　\(notice.needAck == 1 ? "\(notice.ackCount) 人已确认" : "\(notice.readCount) 人已读")")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.hint)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AKColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if let errorText {
                    Text(errorText).font(.system(size: 12)).foregroundColor(AKColor.red)
                }

                if notice.needAck == 1 {
                    Button {
                        Task { await ack() }
                    } label: {
                        Text(notice.myAck == 1 ? "已确认" : "我已知晓")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(notice.myAck == 1 ? AKColor.muted : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(notice.myAck == 1 ? AKColor.fill : AKColor.brand)
                            .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                    }
                    .disabled(notice.myAck == 1 || acking)
                }

                if canManage {
                    Button {
                        confirmDelete = true
                    } label: {
                        Text("删除公告")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AKColor.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(AKColor.redSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                    }
                }
            }
            .padding(14)
        }
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
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    TextEditor(text: $text)
                        .frame(minHeight: 150)
                        .padding(8)
                        .background(AKColor.fill)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Text("\(text.count)/600")
                        .font(.system(size: 11.5))
                        .foregroundColor(AKColor.hint)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    PhotosPicker(selection: $items, maxSelectionCount: 9, matching: .images) {
                        Label("添加照片", systemImage: "photo")
                            .font(.system(size: 14))
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                        ForEach(images, id: \.self) { path in
                            ZStack(alignment: .topTrailing) {
                                AsyncImage(url: APIClient.fullURL(path)) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        AKColor.fill
                                    }
                                }
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
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
                                .padding(3)
                            }
                        }
                    }

                    if let errorText {
                        Text(errorText).font(.system(size: 12)).foregroundColor(AKColor.red)
                    }
                }
                .padding(14)
            }
            .navigationTitle(initial == nil ? "发布群公告" : "编辑群公告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "发布中…" : "发布") { Task { await save() } }
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
        items = []
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
