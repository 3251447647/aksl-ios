import SwiftUI

struct FriendRequestsView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        List {
            if app.friendRequests.isEmpty {
                Text("暂无好友申请")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.muted)
            }
            ForEach(app.friendRequests) { req in
                HStack(spacing: 12) {
                    AvatarView(url: req.avatar, name: req.nickname ?? "用户", size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(req.nickname ?? "用户")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AKColor.text)
                        Text(req.message?.isEmpty == false ? req.message! : "请求添加你为好友")
                            .font(.system(size: 12))
                            .foregroundColor(AKColor.muted)
                            .lineLimit(1)
                    }
                    Spacer()
                    if req.status == 0 {
                        Button("接受") {
                            Task { await app.handleFriendRequest(req, pass: true) }
                        }
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(AKColor.brand)
                        .clipShape(Capsule())

                        Button("拒绝") {
                            Task { await app.handleFriendRequest(req, pass: false) }
                        }
                        .font(.system(size: 13))
                        .foregroundColor(AKColor.muted)
                    } else {
                        Text(req.status == 1 ? "已添加" : "已拒绝")
                            .font(.system(size: 12))
                            .foregroundColor(AKColor.muted)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("新的朋友")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await app.loadFriendRequests() }
        .task { await app.loadFriendRequests() }
    }
}
