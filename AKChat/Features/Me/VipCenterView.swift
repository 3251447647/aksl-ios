import SwiftUI

/// 会员中心：身份卡 + 套餐选择 + 权益 + 底部支付条（对齐安卓 VipScreen）
struct VipView: View {
    @EnvironmentObject private var app: AppState
    @State private var data: VipPlansData?
    @State private var selected: Int64 = 0
    @State private var showPay = false
    @State private var password = ""
    @State private var busy = false
    @State private var tip: String?

    private var level: Int { data?.vipLevel ?? app.user?.vipLevel ?? 0 }
    private var days: Int { data?.vipDays ?? app.user?.vipDays ?? 0 }
    private var plans: [VipPlan] { data?.list ?? [] }

    private var isSvip: Bool { level == 2 }
    private var ink: Color { isSvip ? Color(hex: 0xF3D27C) : Color(hex: 0xE9E2FF) }
    private var edge: Color { isSvip ? Color(hex: 0xD4AF37) : Color(hex: 0x9B8CFF) }
    private var identityGradient: [Color] {
        isSvip
            ? [Color(hex: 0x2B2418), Color(hex: 0x0D0B08)]
            : [Color(hex: 0x332A7A), Color(hex: 0x19154A)]
    }

    /// 同等级可能有多张卡（月/季/年），只把最基础的那张标成「当前」
    private var currentPlanId: Int64 {
        guard level > 0, days > 0 else { return 0 }
        return plans.filter { $0.level == level }.min { $0.days < $1.days }?.id ?? 0
    }

    private var selectedPlan: VipPlan? { plans.first { $0.id == selected } }

    private let benefits: [(String, String, String)] = [
        ("star.fill", "靓号折扣", "购买靓号享专属折扣"),
        ("person.3.fill", "群人数上限", "可创建更大规模的群"),
        ("rosette", "专属标识", "昵称旁展示会员标识"),
        ("folder.fill", "更大文件", "单文件上传上限提升"),
        ("headphones", "优先客服", "问题优先受理与处理")
    ]

    var body: some View {
        VStack(spacing: 0) {
            List {
                identityCard
                    .listRowInsets(EdgeInsets(top: 14, leading: 14, bottom: 18, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                sectionTitle("选择会员套餐")
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 10, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                if plans.isEmpty {
                    emptyPlans
                        .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 18, trailing: 14))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(plans.indices, id: \.self) { index in
                        planCard(plans[index])
                            .listRowInsets(EdgeInsets(top: 0, leading: 14,
                                                      bottom: index == plans.count - 1 ? 18 : 12,
                                                      trailing: 14))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }

                sectionTitle("会员权益")
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 10, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                benefitsRow
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 18, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                if let tip {
                    Text(tip)
                        .font(.system(size: 12.5))
                        .foregroundColor(AKColor.muted)
                        .padding(.horizontal, 18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 18, trailing: 14))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            payBar
        }
        .background(AKColor.bg.ignoresSafeArea())
        .reportsDetailPage()
        .navigationTitle("会员中心")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("确认支付", isPresented: $showPay) {
            SecureField("输入支付密码", text: $password)
            Button("取消", role: .cancel) { password = "" }
            Button("确认支付") { Task { await buy() } }
        } message: {
            Text(payMessage)
        }
    }

    @ViewBuilder
    private var emptyPlans: some View {
        if data == nil {
            ProgressView()
                .frame(maxWidth: .infinity)
                .frame(height: 70)
                .akCardRow(top: true, bottom: true)
        } else {
            Text("暂无套餐")
                .font(.system(size: 12.5))
                .foregroundColor(AKColor.hint)
                .frame(maxWidth: .infinity)
                .frame(height: 70)
                .akCardRow(top: true, bottom: true)
        }
    }

    private var payMessage: String {        guard let plan = selectedPlan else { return "" }
        return "\(plan.name ?? "") · \(plan.days) 天 · \(plan.price) K币 · 余额 \(app.user?.coin ?? 0)"
    }

    // MARK: - 身份卡

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: isSvip ? "crown.fill" : "star.fill")
                    .font(.system(size: 22))
                    .foregroundColor(ink)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 6) {
                    Text(level == 2 ? "至尊 SVIP" : (level == 1 ? "VIP 会员" : "普通用户"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ink)
                    Text(days > 0 ? "剩余 \(days) 天" : "尚未开通会员")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 0) {
                statCell("\(app.user?.coin ?? 0)", "K币")
                statDivider
                statCell("\(days)", "剩余天数")
                statDivider
                statCell(level == 2 ? "SVIP" : (level == 1 ? "VIP" : "无"), "当前等级")
            }
            .padding(.top, 18)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: identityGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(edge, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.2))
            .frame(width: 0.5, height: 26)
    }

    private func statCell(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(hex: 0xF7E7B8))
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 区块标题

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(AKColor.muted)
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 套餐卡

    private func planCard(_ plan: VipPlan) -> some View {
        let svip = plan.level == 2
        let cardInk = svip ? Color(hex: 0xF3D27C) : Color(hex: 0xE9E2FF)
        let cardEdge = svip ? Color(hex: 0xD4AF37) : Color(hex: 0x9B8CFF)
        let picked = selected == plan.id
        let tag: (String, Color)? = plan.id == currentPlanId
            ? ("当前", cardEdge)
            : ((svip || (level > 0 && plan.level > level)) ? ("推荐", AKColor.gold) : nil)

        return Button {
            selected = plan.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: svip ? "crown.fill" : "star.fill")
                    .font(.system(size: 20))
                    .foregroundColor(cardInk)
                    .frame(width: 40, height: 40)
                    .background(
                        LinearGradient(colors: svip
                                        ? [Color(hex: 0x2B2418), Color(hex: 0x0D0B08)]
                                        : [Color(hex: 0x332A7A), Color(hex: 0x19154A)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(plan.name ?? "")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AKColor.text)
                        if let tag {
                            Text(tag.0)
                                .font(.system(size: 9.5))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(tag.1)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                    Text("有效期 \(plan.days) 天")
                        .font(.system(size: 12))
                        .foregroundColor(AKColor.sub)
                }
                Spacer(minLength: 8)
                HStack(spacing: 5) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 17))
                        .foregroundColor(Color(hex: 0xE6A23C))
                    Text("\(plan.price)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: 0xE6A23C))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(AKColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(picked ? cardEdge : AKColor.line, lineWidth: picked ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 权益横滑

    private var benefitsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(benefits.indices, id: \.self) { index in
                    let item = benefits[index]
                    let fg: Color = index % 3 == 0 ? AKColor.gold : (index % 3 == 1 ? AKColor.link : AKColor.brand)
                    let bg: Color = index % 3 == 0 ? AKColor.goldSoft : (index % 3 == 1 ? AKColor.blueSoft : AKColor.brandSoft)
                    VStack(spacing: 0) {
                        Image(systemName: item.0)
                            .font(.system(size: 21))
                            .foregroundColor(fg)
                            .frame(width: 40, height: 40)
                            .background(bg)
                            .clipShape(Circle())
                        Text(item.1)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(AKColor.text)
                            .lineLimit(1)
                            .padding(.top, 8)
                        Text(item.2)
                            .font(.system(size: 10))
                            .foregroundColor(AKColor.sub)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.top, 3)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 14)
                    .frame(width: 104)
                    .background(AKColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.horizontal, 14)
        }
    }

    // MARK: - 底部支付条

    private var payBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(AKColor.line).frame(height: 0.5)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    if let plan = selectedPlan {
                        Text(plan.name ?? "")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AKColor.text)
                        Text("\(plan.days) 天 · \(plan.price) K币")
                            .font(.system(size: 11.5))
                            .foregroundColor(AKColor.sub)
                    } else {
                        Text("请选择套餐")
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.sub)
                    }
                }
                Spacer(minLength: 0)
                Button {
                    guard selectedPlan != nil else { return }
                    password = ""
                    showPay = true
                } label: {
                    Text(busy ? "支付中…" : "确认支付")
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 132, height: 42)
                        .background(selectedPlan == nil ? AKColor.placeholder : AKColor.brand)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(busy || selectedPlan == nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            Spacer().frame(height: 6)
        }
        .background(AKColor.card)
    }

    private func load() async {
        do {
            let d = try await APIClient.shared.vipPlans()
            data = d
            if selected == 0 {
                selected = currentPlanId > 0 ? currentPlanId : (d.list.first?.id ?? 0)
            }
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
            tip = "开通成功：\(r.levelName)，剩余 \(r.days) 天"
            if let me = try? await APIClient.shared.me() {
                app.user = me
            }
            await load()
        } catch {
            tip = error.localizedDescription
        }
    }
}
