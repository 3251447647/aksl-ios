import SwiftUI

/// 靓号商城：个人 / 群双 tab + 分类 + 双列卡片 + 支付密码弹层（对齐安卓 PrettyShopScreen）
struct PrettyNumbersView: View {
    @EnvironmentObject private var app: AppState
    var kind: String = "user"

    @State private var tab = 0
    @State private var categories: [PrettyCategory] = []
    @State private var selected: Int64 = 0
    @State private var numbers: [PrettyNumberItem] = []
    @State private var loading = true
    @State private var error: String?
    @State private var info: String?
    @State private var buyTarget: PrettyNumberItem?
    @State private var payPassword = ""
    @State private var payError: String?

    private var coin: Int64 { app.user?.coin ?? 0 }
    private var myPretty: String { app.user?.prettyYxid ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            categoryRow
            content
        }
        .background(AKColor.bg)
        .reportsDetailPage()
        .navigationTitle("靓号商城")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    Text("🪙").font(.system(size: 12))
                    Text("\(coin)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AKColor.gold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AKColor.goldSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .onAppear {
            if kind == "group" { tab = 1 }
        }
        .task { await loadAll() }
        .sheet(item: $buyTarget) { target in
            buySheet(target)
        }
    }

    // MARK: - 个人 / 群

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach([0, 1], id: \.self) { i in
                Button {
                    guard tab != i else { return }
                    tab = i
                    selected = 0
                    if i == 0 {
                        Task { await loadNumbers() }
                    } else {
                        numbers = []
                    }
                } label: {
                    VStack(spacing: 0) {
                        Text(i == 0 ? "个人靓号" : "群靓号")
                            .font(.system(size: 14.5, weight: i == tab ? .semibold : .regular))
                            .foregroundColor(i == tab ? AKColor.brand : AKColor.muted)
                            .padding(.vertical, 10)
                        Rectangle()
                            .fill(i == tab ? AKColor.brand : Color.clear)
                            .frame(width: 28, height: 3)
                            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .background(AKColor.card)
    }

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "全部", id: 0)
                if tab == 0 {
                    ForEach(categories) { c in
                        chip(title: c.count > 0 ? "\(c.name) \(c.count)" : c.name, id: c.id)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(AKColor.card)
    }

    private func chip(title: String, id: Int64) -> some View {
        Button {
            selected = id
            Task { await loadNumbers() }
        } label: {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(selected == id ? .white : AKColor.sub)
                .padding(.horizontal, 15)
                .padding(.vertical, 7)
                .background(selected == id ? AKColor.brand : AKColor.fill)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 列表

    @ViewBuilder
    private var content: some View {
        if tab == 1 {
            VStack(spacing: 8) {
                Text("群靓号暂未开放")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.hint)
                Text("请使用网页版购买群靓号")
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.placeholder)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if loading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if numbers.isEmpty {
            VStack(spacing: 6) {
                Text(info ?? "暂无可购买的靓号")
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.hint)
                if let error {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.red)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(numbers) { item in
                        numberCard(item)
                    }
                }
                .padding(12)
                if let info {
                    Text(info)
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.brand)
                        .padding(.bottom, 12)
                }
                if let error {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.red)
                        .padding(.bottom, 12)
                }
            }
        }
    }

    private func numberCard(_ item: PrettyNumberItem) -> some View {
        let tag = Self.tagOf(item.number)
        return VStack(spacing: 0) {
            LinearGradient(colors: [AKColor.red, Color(hex: 0xF06B6B)],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 4)

            VStack(spacing: 0) {
                HStack {
                    Text(tag ?? "靓")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(tag == nil ? Color(hex: 0x6C63FF) : Color(hex: 0xFF8A3D))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Spacer(minLength: 0)
                }
                Text(item.number)
                    .font(.system(size: 25, weight: .bold))
                    .foregroundColor(AKColor.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.top, 6)
                Text(Self.isRepeat(item.number) ? "重复" : "精选")
                    .font(.system(size: 10))
                    .foregroundColor(AKColor.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(AKColor.redSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.top, 6)
                HStack(spacing: 3) {
                    Text("🪙").font(.system(size: 11))
                    Text("\(item.price)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AKColor.gold)
                }
                .padding(.top, 8)
                Button {
                    payPassword = ""
                    payError = nil
                    buyTarget = item
                } label: {
                    Text("立即抢购")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            LinearGradient(colors: [Color(hex: 0x43C463), Color(hex: 0x2FA84F)],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
            .padding(12)
        }
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 购买弹层

    private func buySheet(_ target: PrettyNumberItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("确认购买")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AKColor.text)
                Spacer(minLength: 0)
                Button {
                    buyTarget = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AKColor.muted)
                        .frame(width: 30, height: 30)
                        .background(AKColor.fill)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Text(target.number)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(AKColor.red)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 6)

            Text("价格 \(target.price) K币 · 余额 \(coin)")
                .font(.system(size: 13))
                .foregroundColor(AKColor.hint)
                .frame(maxWidth: .infinity, alignment: .center)

            if !myPretty.isEmpty {
                Text("你当前靓号 \(myPretty) 将被回收")
                    .font(.system(size: 12.5))
                    .foregroundColor(Color(hex: 0xE8743B))
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            SecureField("请输入支付密码", text: $payPassword)
                .keyboardType(.numberPad)
                .font(.system(size: 15))
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(AKColor.fill)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onChange(of: payPassword) { value in
                    payPassword = String(value.filter { $0.isNumber }.prefix(6))
                }
                .padding(.top, 4)

            if let payError {
                Text(payError)
                    .font(.system(size: 12))
                    .foregroundColor(AKColor.red)
            }

            HStack(spacing: 10) {
                Button {
                    buyTarget = nil
                } label: {
                    Text("取消")
                        .font(.system(size: 15))
                        .foregroundColor(AKColor.hint)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(AKColor.fill)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await buy(target) }
                } label: {
                    Text("确认支付")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(
                            LinearGradient(colors: [AKColor.brand, AKColor.brandDark],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)
        }
        .padding(18)
        .presentationDetents([.height(330)])
    }

    // MARK: - 数据

    private func loadAll() async {
        loading = true
        defer { loading = false }
        if let cats = try? await APIClient.shared.prettyCategories() {
            categories = cats
        }
        await loadNumbers()
    }

    private func loadNumbers() async {
        guard tab == 0 else { return }
        loading = true
        defer { loading = false }
        do {
            numbers = try await APIClient.shared.prettyList(categoryId: selected, kind: "user")
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func buy(_ target: PrettyNumberItem) async {
        guard payPassword.count >= 4 else {
            payError = "请输入支付密码"
            return
        }
        payError = nil
        do {
            try await APIClient.shared.buyPretty(id: target.id, payPassword: payPassword)
            buyTarget = nil
            info = "购买成功：\(target.number)"
            if let me = try? await APIClient.shared.me() {
                app.user = me
            }
            await loadNumbers()
        } catch {
            payError = error.localizedDescription
        }
    }

    // MARK: - 号码标签

    private static func isRepeat(_ s: String) -> Bool {
        s.count >= 4 && Set(s).count <= 2
    }

    private static func tagOf(_ s: String) -> String? {
        let set = Set(s)
        if set.count == 1 { return "豹子号" }
        if isSequence(s) { return "连号" }
        if set.count == 2 { return "重复" }
        return nil
    }

    private static func isSequence(_ s: String) -> Bool {
        let chars = Array(s)
        guard chars.count >= 3 else { return false }
        var up = true
        var down = true
        for i in 1..<chars.count {
            guard let prev = Int(String(chars[i - 1])), let cur = Int(String(chars[i])) else {
                return false
            }
            if cur - prev != 1 { up = false }
            if cur - prev != -1 { down = false }
        }
        return up || down
    }
}
