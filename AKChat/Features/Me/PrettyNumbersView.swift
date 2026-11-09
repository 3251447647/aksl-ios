import SwiftUI

struct PrettyNumbersView: View {
    @EnvironmentObject private var app: AppState
    var kind: String = "user"

    @State private var categories: [PrettyCategory] = []
    @State private var selected: Int64 = 0
    @State private var numbers: [PrettyNumberItem] = []
    @State private var loading = true
    @State private var error: String?
    @State private var info: String?
    @State private var buyTarget: PrettyNumberItem?
    @State private var payPassword = ""

    var body: some View {
        VStack(spacing: 0) {
            if !categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip(title: "全部", id: 0)
                        ForEach(categories) { c in
                            chip(title: c.name.isEmpty ? "分类\(c.id)" : c.name, id: c.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .background(AKColor.card)
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    if loading {
                        ProgressView().padding(.top, 40)
                    }
                    ForEach(numbers) { item in
                        row(item)
                    }
                    if !loading && numbers.isEmpty {
                        Text("该分类暂时没有可购买的靓号")
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.muted)
                            .padding(.top, 40)
                    }
                    if let info {
                        Text(info).font(.system(size: 12)).foregroundColor(AKColor.brand)
                    }
                    if let error {
                        Text(error).font(.system(size: 12)).foregroundColor(AKColor.red)
                    }
                }
                .padding(14)
            }
        }
        .background(AKColor.bg)
        .listStyle(.plain)
        .navigationTitle(kind == "group" ? "群靓号" : "个人靓号")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadAll() }
        .alert("购买靓号", isPresented: Binding(
            get: { buyTarget != nil },
            set: { if !$0 { buyTarget = nil } }
        )) {
            SecureField("支付密码", text: $payPassword)
            Button("取消", role: .cancel) { buyTarget = nil }
            Button("确认购买") {
                if let target = buyTarget {
                    Task { await buy(target) }
                }
            }
        } message: {
            if let target = buyTarget {
                Text("\(target.number) · \(target.price) K币")
            }
        }
    }

    private func chip(title: String, id: Int64) -> some View {
        Button {
            selected = id
            Task { await loadNumbers() }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: selected == id ? .semibold : .regular))
                .foregroundColor(selected == id ? .white : AKColor.sub)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(selected == id ? AKColor.brand : AKColor.fill)
                .clipShape(Capsule())
        }
    }

    private func row(_ item: PrettyNumberItem) -> some View {
        HStack(spacing: 12) {
            Text(item.number)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(AKColor.gold)
                .frame(minWidth: 96, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(item.price) K币").font(.system(size: 13)).foregroundColor(AKColor.text)
                Text("当前余额 \(Int(app.user?.coin ?? 0)) K币")
                    .font(.system(size: 11)).foregroundColor(AKColor.muted)
            }
            Spacer()
            Button {
                payPassword = ""
                buyTarget = item
            } label: {
                Text("购买")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(AKColor.brand)
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func loadAll() async {
        loading = true
        defer { loading = false }
        do {
            categories = try await APIClient.shared.prettyCategories()
        } catch {
            self.error = error.localizedDescription
        }
        await loadNumbers()
    }

    private func loadNumbers() async {
        loading = true
        defer { loading = false }
        do {
            numbers = try await APIClient.shared.prettyList(categoryId: selected, kind: kind)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func buy(_ target: PrettyNumberItem) async {
        buyTarget = nil
        do {
            try await APIClient.shared.buyPretty(id: target.id, payPassword: payPassword)
            info = "购买成功：\(target.number)"
            if let me = try? await APIClient.shared.me() {
                await MainActor.run { app.user = me }
            }
            await loadNumbers()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
