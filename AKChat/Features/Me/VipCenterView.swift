import SwiftUI

/// 会员中心：身份卡 + 套餐选择 + K币支付（对齐安卓 VipScreen）
struct VipView: View {
    @State private var data: VipPlansData?
    @State private var selected: Int64 = 0
    @State private var showPay = false
    @State private var password = ""
    @State private var busy = false
    @State private var tip: String?

    private var level: Int { data?.vipLevel ?? 0 }
    private var days: Int { data?.vipDays ?? 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                identityCard
                plansCard
                if let tip {
                    Text(tip).font(.system(size: 12.5)).foregroundColor(AKColor.muted)
                }
                Spacer(minLength: 10)
            }
            .padding(12)
        }
        .background(AKColor.bg.ignoresSafeArea())
        .listStyle(.plain)
        .navigationTitle("会员中心")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("确认支付", isPresented: $showPay) {
            SecureField("输入支付密码", text: $password)
            Button("取消", role: .cancel) { password = "" }
            Button("确认支付") { Task { await buy() } }
        } message: {
            Text("将从 K币余额中扣除 \(selectedPrice) K币")
        }
    }

    private var selectedPlan: VipPlan? {
        (data?.list ?? []).first { $0.id == selected }
    }

    private var selectedPrice: Int { selectedPlan?.price ?? 0 }

    private var identityCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color(hex: 0xE7C066))
                VStack(alignment: .leading, spacing: 3) {
                    Text(level >= 2 ? "至尊 SVIP" : (level == 1 ? "VIP 会员" : "普通用户"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color(hex: 0xF0DCA4))
                    Text(level > 0 ? "有效期剩余 \(days) 天" : "开通会员享专属标识与特权")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.72))
                }
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [Color(hex: 0x2B2A28), Color(hex: 0x141414)],
                               startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var plansCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择套餐").font(.system(size: 14.5, weight: .medium)).foregroundColor(AKColor.text)
            ForEach(data?.list ?? []) { plan in
                Button {
                    selected = plan.id
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(plan.name ?? "会员")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AKColor.text)
                            Text("\(plan.days) 天").font(.system(size: 12)).foregroundColor(AKColor.muted)
                        }
                        Spacer()
                        Text("\(plan.price) K币")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: 0xC9A44C))
                        Image(systemName: selected == plan.id ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 18))
                            .foregroundColor(selected == plan.id ? AKColor.brand : AKColor.placeholder)
                    }
                    .padding(13)
                    .background(selected == plan.id ? AKColor.brandSoft : AKColor.cardAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Button {
                if selected == 0, let first = data?.list.first { selected = first.id }
                guard selected != 0 else { tip = "请选择套餐"; return }
                password = ""
                showPay = true
            } label: {
                Text(busy ? "支付中…" : "立即开通")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(AKColor.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
            }
            .disabled(busy)

            Text("开通后立即生效，到期自动失效；使用 K币 支付。")
                .font(.system(size: 11.5))
                .foregroundColor(AKColor.hint)
        }
        .padding(14)
        .background(AKColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func load() async {
        do {
            let d = try await APIClient.shared.vipPlans()
            data = d
            if selected == 0, let first = d.list.first { selected = first.id }
        } catch {
            tip = error.localizedDescription
        }
    }

    private func buy() async {
        let pwd = password.trimmingCharacters(in: .whitespaces)
        password = ""
        guard !pwd.isEmpty else { tip = "请输入支付密码"; return }
        busy = true
        defer { busy = false }
        do {
            let r = try await APIClient.shared.buyVip(planId: selected, payPassword: pwd)
            tip = "开通成功：\(r.levelName ?? "会员")，剩余 \(r.days) 天"
            await load()
        } catch {
            tip = error.localizedDescription
        }
    }
}
