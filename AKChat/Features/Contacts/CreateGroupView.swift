import SwiftUI

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppState

    @State private var name = ""
    @State private var intro = ""
    @State private var selected: Set<Int64> = []
    @State private var creating = false
    @State private var errorText: String?
    @State private var created: CreateGroupResult?

    var body: some View {
        Form {
            Section("群名称") {
                TextField("给群起个名字", text: $name)
            }
            Section("群介绍") {
                TextField("选填", text: $intro, axis: .vertical).lineLimit(1...3)
            }
            Section("选择成员（可选）") {
                ForEach(app.contacts?.friends ?? []) { f in
                    Button {
                        if selected.contains(f.id) { selected.remove(f.id) } else { selected.insert(f.id) }
                    } label: {
                        HStack(spacing: 10) {
                            AvatarView(url: f.avatar, name: f.displayName, size: 34)
                            Text(f.displayName).foregroundColor(AKColor.text)
                            Spacer()
                            Image(systemName: selected.contains(f.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selected.contains(f.id) ? AKColor.brand : AKColor.hint)
                        }
                    }
                }
            }
            if let errorText {
                Text(errorText).font(.system(size: 12)).foregroundColor(AKColor.red)
            }
        }
        .navigationTitle("发起群聊")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(creating ? "创建中…" : "创建") { Task { await create() } }
                    .disabled(creating || name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .task { await app.loadContacts() }
        .background(
            NavigationLink(
                isActive: Binding(get: { created != nil }, set: { if !$0 { created = nil } }),
                destination: {
                    if let g = created {
                        ChatView(convType: "group", convId: g.id, title: g.name ?? name)
                    }
                },
                label: { EmptyView() }
            )
        )
    }

    private func create() async {
        creating = true
        errorText = nil
        defer { creating = false }
        do {
            let result = try await APIClient.shared.createGroup(name: name.trimmingCharacters(in: .whitespaces), intro: intro, members: Array(selected))
            created = result
            await app.refreshConversations()
            await app.loadContacts()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
