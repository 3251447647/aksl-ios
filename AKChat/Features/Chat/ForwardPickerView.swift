import SwiftUI

struct ForwardPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let messages: [Message]

    @State private var contacts: ContactsData?
    @State private var keyword = ""
    @State private var selected: Set<String> = []
    @State private var sending = false
    @State private var error: String?
    @State private var done = false

    private var friends: [ContactFriend] {
        let list = contacts?.friends ?? []
        guard !keyword.isEmpty else { return list }
        return list.filter { $0.displayName.localizedCaseInsensitiveContains(keyword) }
    }

    private var groups: [ContactGroup] {
        let list = contacts?.groups ?? []
        guard !keyword.isEmpty else { return list }
        return list.filter { ($0.name ?? "").localizedCaseInsensitiveContains(keyword) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(AKColor.muted)
                    TextField("搜索好友或群聊", text: $keyword)
                        .textInputAutocapitalization(.never)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(12)

                List {
                    if !friends.isEmpty {
                        Section("好友") {
                            ForEach(friends) { friend in
                                row(key: "private:\(friend.id)",
                                    name: friend.displayName,
                                    avatar: friend.avatar,
                                    subtitle: friend.yxId ?? "",
                                    badge: friend.isPretty == 1 ? friend.prettyNo : nil)
                            }
                        }
                    }
                    if !groups.isEmpty {
                        Section("群聊") {
                            ForEach(groups) { group in
                                row(key: "group:\(group.id)",
                                    name: group.name ?? "群聊",
                                    avatar: group.avatar,
                                    subtitle: "\(group.memberCount) 人",
                                    badge: group.prettyNo)
                            }
                        }
                    }
                    if let error {
                        Text(error).font(.system(size: 12)).foregroundColor(AKColor.red)
                    }
                }
                .listStyle(.plain)

                if !selected.isEmpty {
                    Button {
                        Task { await forward() }
                    } label: {
                        Text(sending ? "发送中…" : "发送给 \(selected.count) 个会话")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(AKColor.brand)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .background(AKColor.bg)
            .navigationTitle("转发")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .task {
                if let data = try? await APIClient.shared.contacts() {
                    contacts = data
                }
            }
            .alert("已转发", isPresented: $done) {
                Button("好") { dismiss() }
            }
        }
    }

    private func row(key: String, name: String, avatar: String?, subtitle: String, badge: String?) -> some View {
        Button {
            if selected.contains(key) {
                selected.remove(key)
            } else {
                selected.insert(key)
            }
        } label: {
            HStack(spacing: 10) {
                AvatarView(url: avatar, name: name, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(name).font(.system(size: 14)).foregroundColor(AKColor.text)
                        if let badge, !badge.isEmpty, badge != "0" {
                            BadgeView(text: badge)
                        }
                    }
                    if !subtitle.isEmpty {
                        Text(subtitle).font(.system(size: 11)).foregroundColor(AKColor.muted)
                    }
                }
                Spacer()
                Image(systemName: selected.contains(key) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selected.contains(key) ? AKColor.brand : AKColor.hint)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func forward() async {
        guard !selected.isEmpty, !sending else { return }
        sending = true
        defer { sending = false }
        var failed = 0
        for key in selected {
            let parts = key.split(separator: ":")
            guard parts.count == 2, let convId = Int64(parts[1]) else { continue }
            let convType = String(parts[0])
            for msg in messages {
                do {
                    try await APIClient.shared.forwardMessage(message: msg, convType: convType, convId: convId)
                } catch {
                    failed += 1
                }
            }
        }
        if failed > 0 {
            error = "有 \(failed) 条转发失败，请重试"
        } else {
            done = true
        }
    }
}
