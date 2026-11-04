import SwiftUI
import PhotosUI
import UIKit

struct GroupNoticesView: View {
    let groupId: Int64
    @State private var notices: [GroupNotice] = []
    @State private var canManage = false
    @State private var showEditor = false
    @State private var loading = true

    var body: some View {
        List {
            if notices.isEmpty && !loading {
                Text("暂无群公告").font(.system(size: 13)).foregroundColor(AKColor.muted)
            }
            ForEach(notices) { n in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(n.publisherName ?? "群公告")
                            .font(.system(size: 12)).foregroundColor(AKColor.muted)
                        Spacer()
                        Text(TimeText.short(n.createdAt))
                            .font(.system(size: 11)).foregroundColor(AKColor.hint)
                    }
                    Text(n.content ?? "")
                        .font(.system(size: 14))
                        .foregroundColor(AKColor.text)
                    if !n.imageList.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(n.imageList, id: \.self) { path in
                                    AsyncImage(url: APIClient.fullURL(path)) { phase in
                                        if let image = phase.image {
                                            image.resizable().scaledToFill()
                                        } else {
                                            AKColor.fill
                                        }
                                    }
                                    .frame(width: 90, height: 90)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                    Text("已读 \(n.readCount)/\(n.totalMembers)")
                        .font(.system(size: 11)).foregroundColor(AKColor.hint)
                }
                .padding(.vertical, 4)
            }
        }
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
            GroupNoticeEditor(groupId: groupId) { await load() }
        }
        .refreshable { await load() }
        .task { await load() }
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

private struct GroupNoticeEditor: View {
    @Environment(\.dismiss) private var dismiss
    let groupId: Int64
    let onSaved: () async -> Void

    @State private var text = ""
    @State private var items: [PhotosPickerItem] = []
    @State private var previews: [Data] = []
    @State private var saving = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $text)
                    .frame(minHeight: 140)
                    .padding(8)
                    .background(AKColor.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                PhotosPicker(selection: $items, maxSelectionCount: 9, matching: .images) {
                    Label("添加图片", systemImage: "photo")
                }

                if !previews.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(previews.enumerated()), id: \.offset) { _, data in
                                if let image = UIImage(data: data) {
                                    Image(uiImage: image).resizable().scaledToFill()
                                        .frame(width: 70, height: 70).clipped()
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
            .navigationTitle("发布群公告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "发布中…" : "发布") { Task { await save() } }
                        .disabled(saving || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    private func save() async {
        saving = true
        defer { saving = false }
        var urls: [String] = []
        for data in previews {
            do {
                let uploaded = try await APIClient.shared.upload(data: data, filename: "notice_\(Int(Date().timeIntervalSince1970)).jpg", kind: "chat")
                urls.append(uploaded.url)
            } catch {
                errorText = "图片上传失败：\(error.localizedDescription)"
                return
            }
        }
        let imagesJSON = (try? JSONSerialization.data(withJSONObject: urls)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        await APIClient.shared.saveGroupNotice(gid: groupId, id: 0, content: text.trimmingCharacters(in: .whitespacesAndNewlines), imagesJSON: imagesJSON)
        await onSaved()
        dismiss()
    }
}
