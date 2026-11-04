import SwiftUI

struct InviteMembersView: View {
    let groupId: Int64
    @Environment(\.dismiss) private var dismiss

    @State private var list: [InvitableFriend] = []
    @State private var selected: Set<Int64> = []
    @State private var tipText: String?
    @State private var sending = false

    var body: some View {
        List {
            ForEach(list) { f in
                Button {
                    if selected.contains(f.id) { selected.remove(f.id) } else { selected.insert(f.id) }
                } label: {
                    HStack(spacing: 10) {
                        AvatarView(url: f.avatar, name: f.displayName, size: 38)
                        Text(f.displayName).foregroundColor(AKColor.text)
                        Spacer()
                        Image(systemName: selected.contains(f.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selected.contains(f.id) ? AKColor.brand : AKColor.hint)
                    }
                }
            }
            if list.isEmpty {
                Text("没有可邀请的好友").font(.system(size: 13)).foregroundColor(AKColor.muted)
            }
        }
        .navigationTitle("邀请好友进群")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(sending ? "邀请中…" : "邀请(\(selected.count))") {
                    Task { await invite() }
                }
                .disabled(sending || selected.isEmpty)
            }
        }
        .task {
            if let data = try? await APIClient.shared.invitable(gid: groupId) {
                list = data.list
                if data.canInvite == 0 {
                    tipText = "当前没有邀请权限"
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let tipText {
                Text(tipText).font(.system(size: 12)).foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.black.opacity(0.7)).clipShape(Capsule())
                    .padding(.bottom, 18)
            }
        }
    }

    private func invite() async {
        sending = true
        defer { sending = false }
        await APIClient.shared.inviteMembers(gid: groupId, uids: Array(selected))
        tipText = "邀请已发送"
        dismiss()
    }
}
