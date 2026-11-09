import SwiftUI

/// 邀请好友入群：与安卓 InviteFriendsScreen.kt 逐项对齐（自绘顶栏 / 搜索 / 多选行 / 底部邀请栏）。
/// 安卓的 invitable 响应带 yx_id、vip_level、group_name，iOS Core 的 InvitableFriend 缺这些字段，
/// 这里用文件内 DTO 直接解码同一接口，不改 Core。
struct InviteMembersView: View {
    let groupId: Int64

    @Environment(\.dismiss) private var dismiss
    @State private var info: InviteInfo?
    @State private var keyword = ""
    @State private var selected: Set<Int64> = []
    @State private var sending = false
    @State private var toastText: String?

    private var all: [InviteFriendDTO] { info?.list ?? [] }

    /// 安卓：按 name / nickname / yx_id 忽略大小写包含匹配，关键词先 trim
    private var shown: [InviteFriendDTO] {
        let k = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { return all }
        return all.filter {
            ($0.name ?? "").range(of: k, options: .caseInsensitive) != nil
                || ($0.nickname ?? "").range(of: k, options: .caseInsensitive) != nil
                || ($0.yxId ?? "").range(of: k, options: .caseInsensitive) != nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            searchBar
            content
        }
        .background(AKColor.bg.ignoresSafeArea())
        .overlay(alignment: .bottom) { toastView }
        .navigationBarHidden(true)
        .restoresSwipeBack()
        .task { await load() }
    }

    // MARK: - 顶栏（44 返回位 + 居中标题 16 + 群名 10.5，上下 4）

    private var topBar: some View {
        HStack(spacing: 0) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 21))
                    .foregroundColor(AKColor.text)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(spacing: 0) {
                Text("邀请好友")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AKColor.text)
                if !(info?.groupName ?? "").isEmpty {
                    Text(info?.groupName ?? "")
                        .font(.system(size: 10.5))
                        .foregroundColor(AKColor.hint)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.vertical, 4)
        .background(AKColor.card.ignoresSafeArea(edges: .top))
    }

    // MARK: - 搜索（外层 14/8，内框圆角 10、填充色，内边距 11/8，图标 16 + 7）

    private var searchBar: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(AKColor.hint)
            ZStack(alignment: .leading) {
                if keyword.isEmpty {
                    Text("搜索好友昵称 / AK号")
                        .font(.system(size: 13.5))
                        .foregroundColor(AKColor.hint)
                }
                TextField("", text: $keyword)
                    .font(.system(size: 13.5))
                    .foregroundColor(AKColor.text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(AKColor.fill)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(AKColor.card)
    }

    // MARK: - 列表 / 空态（安卓只有三种：无权限、没有好友、其它走列表 + 底栏）

    @ViewBuilder
    private var content: some View {
        if let info, info.canInvite != 1 {
            hintBox("群主已关闭成员邀请，暂无邀请权限")
        } else if let info, info.list.isEmpty {
            hintBox("没有可邀请的好友了")
        } else {
            listArea
            bottomBar
        }
    }

    private var listArea: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(shown) { f in
                    friendRow(f)
                    Rectangle()
                        .fill(AKColor.line)
                        .frame(height: 0.6)
                        .padding(.leading, 76)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AKColor.card)
    }

    private func hintBox(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(AKColor.hint)
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 行（勾选圈 20/17、间距 11、头像 40 圆、名字 15 + VIP、AK号 11.5、16/9）

    private func friendRow(_ f: InviteFriendDTO) -> some View {
        let checked = selected.contains(f.id)
        let title = f.name ?? ""
        return Button {
            if checked {
                selected.remove(f.id)
            } else {
                selected.insert(f.id)
            }
        } label: {
            HStack(spacing: 11) {
                ZStack {
                    Circle()
                        .fill(checked ? AKColor.brand : AKColor.line)
                        .frame(width: 20, height: 20)
                    if checked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .fill(AKColor.card)
                            .frame(width: 17, height: 17)
                    }
                }

                AvatarView(url: f.avatar, name: title, size: 40)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 3) {
                        Text(title)
                            .font(.system(size: 15))
                            .foregroundColor(AKColor.text)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if f.vipLevel > 0 {
                            VipBadge(level: f.vipLevel)
                        }
                    }
                    if let yxId = f.yxId, !yxId.isEmpty {
                        Text("AK号 \(yxId)")
                            .font(.system(size: 11.5))
                            .foregroundColor(AKColor.hint)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 底栏（已选 N 人 13；按钮 13.5 白字，圆角 20，22/9）

    private var bottomBar: some View {
        HStack(spacing: 0) {
            Text("已选 \(selected.count) 人")
                .font(.system(size: 13))
                .foregroundColor(AKColor.sub)
            Spacer(minLength: 6)
            Button {
                guard !selected.isEmpty, !sending else { return }
                Task { await invite() }
            } label: {
                Text(selected.isEmpty ? "邀请" : "邀请 \(selected.count) 人")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 9)
                    .background(selected.isEmpty ? AKColor.line : AKColor.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AKColor.card.ignoresSafeArea(edges: .bottom))
    }

    // MARK: - Toast

    private var toastView: some View {
        Group {
            if let toastText {
                Text(toastText)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color(hex: 0x1A1D26).opacity(0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 40)
                    .padding(.bottom, 28)
                    .allowsHitTesting(false)
            }
        }
    }

    private func showToast(_ message: String) {
        toastText = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if toastText == message { toastText = nil }
        }
    }

    // MARK: - 数据

    private func load() async {
        guard let data: InviteInfo = try? await APIClient.shared.get(
            "api/v1/group/invitable",
            query: ["id": String(groupId)]
        ) else { return }
        info = data
    }

    /// 安卓：一次提交全部 uids，成功 toast「邀请已发出」并返回；失败留在本页 toast 服务端文案
    private func invite() async {
        guard !selected.isEmpty else { return }
        sending = true
        defer { sending = false }
        do {
            let msg = try await APIClient.shared.postRaw(
                "api/v1/group/invite",
                body: ["id": groupId, "uids": Array(selected)]
            )
            showToast(msg.isEmpty ? "邀请已发出" : msg)
            try? await Task.sleep(nanoseconds: 900_000_000)
            dismiss()
        } catch {
            showToast(error.localizedDescription)
        }
    }
}

// MARK: - 接口模型（同 /api/v1/group/invitable，补 Core 缺的字段）

private struct InviteFriendDTO: Decodable, Identifiable {
    let id: Int64
    let name: String?
    let nickname: String?
    let avatar: String?
    let yxId: String?
    let vipLevel: Int

    enum CodingKeys: String, CodingKey {
        case id, name, nickname, avatar
        case yxId = "yx_id"
        case vipLevel = "vip_level"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        name = try? c.decode(String.self, forKey: .name)
        nickname = try? c.decode(String.self, forKey: .nickname)
        avatar = try? c.decode(String.self, forKey: .avatar)
        yxId = try? c.decode(String.self, forKey: .yxId)
        vipLevel = (try? c.decode(Int.self, forKey: .vipLevel)) ?? 0
    }
}

private struct InviteInfo: Decodable {
    let list: [InviteFriendDTO]
    let canInvite: Int
    let groupName: String?

    enum CodingKeys: String, CodingKey {
        case list
        case canInvite = "can_invite"
        case groupName = "group_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decode([InviteFriendDTO].self, forKey: .list)) ?? []
        canInvite = (try? c.decode(Int.self, forKey: .canInvite)) ?? 0
        groupName = try? c.decode(String.self, forKey: .groupName)
    }
}
