import SwiftUI

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppState

    @State private var keyword = ""
    @State private var results: [SearchUser] = []
    @State private var searching = false
    @State private var tipText: String?
    @State private var added: Set<Int64> = []

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("AK号 / 靓号 / 邮箱", text: $keyword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(AKColor.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Button(searching ? "搜索中…" : "搜索") {
                    Task { await search() }
                }
                .foregroundColor(AKColor.brand)
                .disabled(searching || keyword.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)

            if let tipText {
                Text(tipText).font(.system(size: 12)).foregroundColor(AKColor.muted).padding(.bottom, 8)
            }

            List(results) { user in
                HStack(spacing: 12) {
                    AvatarView(url: user.avatar, name: user.nickname ?? "用户", size: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.nickname ?? "用户").foregroundColor(AKColor.text)
                        Text("AK号 \(user.yxId ?? "")").font(.system(size: 11)).foregroundColor(AKColor.muted)
                    }
                    Spacer()
                    if user.isFriend == 1 {
                        Text("已是好友").font(.system(size: 12)).foregroundColor(AKColor.muted)
                    } else if added.contains(user.id) {
                        Text("已申请").font(.system(size: 12)).foregroundColor(AKColor.muted)
                    } else {
                        Button("添加") {
                            Task { await add(user) }
                        }
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(AKColor.brand)
                        .clipShape(Capsule())
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("添加好友")
        .navigationBarTitleDisplayMode(.inline)
        .background(AKColor.bg)
    }

    private func search() async {
        searching = true
        tipText = nil
        defer { searching = false }
        do {
            results = try await APIClient.shared.searchUsers(keyword: keyword.trimmingCharacters(in: .whitespaces)).users
            if results.isEmpty { tipText = "没有找到用户" }
        } catch {
            results = []
            tipText = error.localizedDescription
        }
    }

    private func add(_ user: SearchUser) async {
        await APIClient.shared.addFriend(toUid: user.id, message: "你好，我想加你为好友")
        added.insert(user.id)
    }
}
