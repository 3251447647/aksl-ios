import SwiftUI

/// 聊天记录搜索：全局或指定会话内搜索（对齐安卓 MessageSearchScreen）
struct MessageSearchView: View {
    /// 传空字符串表示全局搜索
    var scopeType: String = ""
    var scopeId: Int64 = 0
    var scopeTitle: String = ""

    @State private var keyword = ""
    @State private var hits: [SearchMsgHit] = []
    @State private var searching = false
    @State private var searched = false
    @State private var hasMore = false
    @State private var page = 1
    @State private var nextBeforeId: Int64 = 0
    @State private var nextBeforeTs: Int64 = 0
    @State private var errorText: String?

    private var titleText: String {
        scopeId > 0 ? "搜索 \(scopeTitle)" : "搜索聊天记录"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(AKColor.hint)
                TextField("搜索聊天记录", text: $keyword)
                    .font(.system(size: 14))
                    .submitLabel(.search)
                    .onSubmit { Task { await search(reset: true) } }
                if !keyword.isEmpty {
                    Button {
                        keyword = ""
                        hits = []
                        searched = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AKColor.placeholder)
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(AKColor.fill)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if let errorText {
                Text(errorText).font(.system(size: 12)).foregroundColor(AKColor.red)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
            }

            List {
                ForEach(hits) { hit in
                    NavigationLink {
                        ChatView(convType: hit.convType, convId: hit.convId, title: hit.convName)
                    } label: {
                        HStack(spacing: 11) {
                            AvatarView(url: hit.convAvatar, name: hit.convName, size: 40)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(hit.subtitle)
                                        .font(.system(size: 14.5, weight: .medium))
                                        .foregroundColor(AKColor.text)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(TimeText.short(hit.createdAt))
                                        .font(.system(size: 11))
                                        .foregroundColor(AKColor.hint)
                                }
                                Text(hit.recalled == 1 ? "消息已撤回" : hit.digest)
                                    .font(.system(size: 12.5))
                                    .foregroundColor(AKColor.sub)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if hasMore {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .onAppear { Task { await search(reset: false) } }
                } else if searched && hits.isEmpty {
                    Text("没有找到相关聊天记录")
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.hint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle(titleText)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func search(reset: Bool) async {
        let kw = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty else { return }
        if searching { return }
        searching = true
        defer { searching = false }
        do {
            let d = try await APIClient.shared.searchMessages(
                keyword: kw,
                convType: scopeType,
                convId: scopeId,
                page: reset ? 1 : page,
                beforeId: reset ? 0 : nextBeforeId,
                beforeTs: reset ? 0 : nextBeforeTs
            )
            if reset {
                hits = d.list
                page = d.page
            } else {
                let exist = Set(hits.map { $0.id })
                hits += d.list.filter { !exist.contains($0.id) }
            }
            hasMore = d.hasMore == 1
            nextBeforeId = d.nextBeforeId
            nextBeforeTs = d.nextBeforeTs
            searched = true
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }
}
