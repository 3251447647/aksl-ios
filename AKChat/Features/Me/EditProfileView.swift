import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppState

    @State private var nickname = ""
    @State private var bio = ""
    @State private var saving = false

    var body: some View {
        Form {
            Section("昵称") {
                TextField("昵称", text: $nickname)
            }
            Section("个性签名") {
                TextField("介绍一下自己", text: $bio, axis: .vertical)
                    .lineLimit(2...4)
            }
            Section {
                Button(saving ? "保存中…" : "保存") {
                    Task {
                        saving = true
                        await app.updateProfile(nickname: nickname, bio: bio)
                        saving = false
                        dismiss()
                    }
                }
                .disabled(saving || nickname.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("编辑资料")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            nickname = app.user?.nickname ?? ""
            bio = app.user?.bio ?? ""
        }
    }
}
