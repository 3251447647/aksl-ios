import SwiftUI
import PhotosUI

/// 建群额度（对齐安卓 GroupCreateInfoResp）
struct GroupCreateInfo: Decodable {
    let vipLabel: String?
    let maxMember: Int
    let maxGroupCount: Int
    let myGroupCount: Int
    let canCreate: Int

    enum CodingKeys: String, CodingKey {
        case vipLabel = "vip_label"
        case maxMember = "max_member"
        case maxGroupCount = "max_group_count"
        case myGroupCount = "my_group_count"
        case canCreate = "can_create"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        vipLabel = try? c.decode(String.self, forKey: .vipLabel)
        maxMember = (try? c.decode(Int.self, forKey: .maxMember)) ?? 0
        maxGroupCount = (try? c.decode(Int.self, forKey: .maxGroupCount)) ?? 0
        myGroupCount = (try? c.decode(Int.self, forKey: .myGroupCount)) ?? 0
        canCreate = (try? c.decode(Int.self, forKey: .canCreate)) ?? 1
    }
}

/// 发起群聊：建群额度横幅 + 群头像/群名称/群简介 + 勾选成员，底部固定「创建群聊」
struct CreateGroupView: View {
    @EnvironmentObject private var app: AppState

    @State private var name = ""
    @State private var intro = ""
    @State private var avatarUrl = ""
    @State private var avatarItem: PhotosPickerItem?
    @State private var uploading = false
    @State private var info: GroupCreateInfo?
    @State private var selected: Set<Int64> = []
    @State private var creating = false
    @State private var toastText: String?
    @State private var created: CreateGroupResult?

    private var friends: [ContactFriend] { app.contacts?.friends ?? [] }
    private var canCreate: Bool { info?.canCreate != 0 }
    private var maxMember: Int { info?.maxMember ?? 0 }
    private var canSubmit: Bool {
        !creating && canCreate && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    banner
                    editCard
                    memberHeader
                    memberList
                }
                .padding(.bottom, 16)
            }
            bottomBar
        }
        .background(AKColor.bg)
        .overlay(alignment: .bottom) { toastView }
        .reportsDetailPage()
        .navigationTitle("创建群聊")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
        .task {
            await app.loadContacts()
            await loadInfo()
        }
        .onChange(of: avatarItem) { item in
            guard let item else { return }
            Task { await uploadAvatar(item) }
        }
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

    private var editCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 2) {
                PhotosPicker(selection: $avatarItem, matching: .images) {
                    ZStack {
                        AvatarView(url: avatarUrl.isEmpty ? nil : avatarUrl,
                                   name: name.isEmpty ? "群" : name, size: 84)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        if uploading {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 84, height: 84)
                            Text("上传中")
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 84, height: 84)
                }
                .buttonStyle(.plain)
                Text("点击设置群头像（选填）")
                    .font(.system(size: 12.5))
                    .foregroundColor(AKColor.hint)
                    .padding(.top, 8)
                Text("建议使用正方形图片")
                    .font(.system(size: 10.5))
                    .foregroundColor(AKColor.placeholder)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)

            HStack(spacing: 0) {
                Text("群名称")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AKColor.sub)
                Text(" *")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.red)
                Spacer()
                Text("\(name.count)/20")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.hint)
            }
            TextField("请输入群名称", text: $name)
                .font(.system(size: 14))
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(AKColor.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(AKColor.line, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onChange(of: name) { value in
                    if value.count > 20 { name = String(value.prefix(20)) }
                }
                .padding(.top, 6)

            HStack(spacing: 0) {
                Text("群简介")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AKColor.sub)
                Spacer()
                Text("\(intro.count)/200")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.hint)
            }
            .padding(.top, 14)

            TextField("介绍一下这个群吧…", text: $intro, axis: .vertical)
                .font(.system(size: 14))
                .lineLimit(3...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(minHeight: 78, alignment: .topLeading)
                .background(AKColor.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(AKColor.line, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onChange(of: intro) { value in
                    if value.count > 200 { intro = String(value.prefix(200)) }
                }
                .padding(.top, 6)
        }
        .padding(16)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    private var memberHeader: some View {
        HStack(spacing: 0) {
            Text("选择成员（可选，已选 \(selected.count)）")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AKColor.sub)
            Spacer()
            if maxMember > 0 {
                Text("默认群上限 \(maxMember) 人（含你）")
                    .font(.system(size: 11.5))
                    .foregroundColor(AKColor.hint)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var memberList: some View {
        VStack(spacing: 0) {
            if friends.isEmpty {
                Text("还没有好友，先去添加好友吧")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.hint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 44)
            } else {
                ForEach(Array(friends.enumerated()), id: \.element.id) { idx, f in
                    friendRow(f)
                    if idx < friends.count - 1 {
                        Rectangle().fill(AKColor.line).frame(height: 0.6)
                    }
                }
            }
        }
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 12)
    }

    private func friendRow(_ f: ContactFriend) -> some View {
        let on = selected.contains(f.id)
        return Button {
            if on {
                selected.remove(f.id)
            } else if let cap = maxMember > 0 ? maxMember - 1 : nil, selected.count >= cap {
                showToast("普通群默认上限 \(maxMember) 人，VIP/SVIP 可在群管理内升级")
            } else {
                selected.insert(f.id)
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(on ? AKColor.brand : AKColor.line)
                        .frame(width: 20, height: 20)
                    if on {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                AvatarView(url: f.avatar, name: f.displayName, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(akNameColor(vipLevel: f.vipLevel, isPretty: 0, isGroup: false))
                        .lineLimit(1)
                    if let yx = f.yxId, !yx.isEmpty {
                        Text("AK号 \(yx)")
                            .font(.system(size: 11.5))
                            .foregroundColor(AKColor.hint)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var banner: some View {
        let label = info?.vipLabel ?? "普通"
        let colors: [Color] = {
            switch label {
            case "SVIP": return [Color(hex: 0xFFD86B), Color(hex: 0xE8642F)]
            case "VIP": return [Color(hex: 0x10B981), Color(hex: 0x06AD56)]
            default: return [AKColor.sub, Color(hex: 0x4B5563)]
            }
        }()
        let maxCount = info?.maxGroupCount ?? 0
        let used = info?.myGroupCount ?? 0
        let progress = maxCount > 0 ? min(max(Double(used) / Double(maxCount), 0), 1) : 0
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("建群人数规则")
                    .font(.system(size: 11.5))
                    .foregroundColor(Color.white.opacity(0.8))
                Text("普通群默认 \(info?.maxMember ?? 0) 人 · VIP/SVIP 可在群管理升级")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                if info == nil {
                    Text("正在加载建群额度…")
                        .font(.system(size: 11.5))
                        .foregroundColor(Color.white.opacity(0.8))
                        .padding(.top, 5)
                } else if maxCount > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.33))
                            Capsule().fill(Color.white)
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 4)
                    .padding(.top, 5)
                    Text("已创建 \(used)/\(maxCount) 个群")
                        .font(.system(size: 11.5))
                        .foregroundColor(.white)
                        .padding(.top, 5)
                } else {
                    Text("已创建 \(used) 个群 · 无数量上限")
                        .font(.system(size: 11.5))
                        .foregroundColor(.white)
                        .padding(.top, 5)
                }
            }
            Spacer(minLength: 0)
            Text(label == "SVIP" ? "SV" : (label == "VIP" ? "V" : "普"))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(Color.white.opacity(0.2))
                .clipShape(Circle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(12)
    }

    private var bottomBar: some View {
        Button {
            Task { await create() }
        } label: {
            Text(creating ? "创建中…" : (canCreate ? "创建群聊" : "群数量已达上限"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(canSubmit ? .white : AKColor.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(canSubmit ? AKColor.brand : AKColor.line)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AKColor.card)
    }

    private func create() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard canCreate else {
            showToast("群数量已达上限，升级会员可提升群人数")
            return
        }
        guard !trimmed.isEmpty else {
            showToast("请输入群名称")
            return
        }
        guard trimmed.count <= 20 else {
            showToast("群名称最多 20 个字")
            return
        }
        guard intro.trimmingCharacters(in: .whitespaces).count <= 200 else {
            showToast("群简介最多 200 个字")
            return
        }
        guard !uploading else {
            showToast("头像上传中，请稍候")
            return
        }
        if maxMember > 0 && selected.count + 1 > maxMember {
            showToast("当前 \(info?.vipLabel ?? "普通") 等级最多创建 \(maxMember) 人的群")
            return
        }
        creating = true
        defer { creating = false }
        do {
            let result: CreateGroupResult = try await APIClient.shared.post("api/v1/group/create", body: [
                "name": trimmed,
                "intro": intro.trimmingCharacters(in: .whitespaces),
                "members": Array(selected),
                "avatar": avatarUrl,
            ])
            created = result
            await app.refreshConversations()
            await app.loadContacts()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    private func loadInfo() async {
        info = try? await APIClient.shared.get("api/v1/group/create-info")
    }

    private func uploadAvatar(_ item: PhotosPickerItem) async {
        defer { avatarItem = nil }
        uploading = true
        defer { uploading = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let up = try await APIClient.shared.upload(
                data: data,
                filename: "group_\(Int(Date().timeIntervalSince1970)).jpg",
                kind: "group"
            )
            avatarUrl = up.url
        } catch {
            showToast("头像上传失败，请重试")
        }
    }

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
                    .padding(.bottom, 90)
            }
        }
    }

    private func showToast(_ message: String) {
        toastText = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if toastText == message { toastText = nil }
        }
    }
}
