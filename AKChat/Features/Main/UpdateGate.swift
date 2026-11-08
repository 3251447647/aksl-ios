import SwiftUI

/// 启动时检查最新版本：服务端标记强制更新时弹不可关闭的提示
struct UpdateGate: ViewModifier {
    @State private var info: AppVersionInfo?

    private var currentCode: Int {
        Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") ?? 0
    }

    private var needsUpdate: Bool {
        guard let info, info.latestCode > currentCode else { return false }
        return info.force == 1 || info.latestCode >= info.minSupported && info.minSupported > currentCode
    }

    func body(content: Content) -> some View {
        content
            .task { await check() }
            .sheet(isPresented: Binding(
                get: { needsUpdate },
                set: { _ in }
            )) {
                VStack(spacing: 14) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 42))
                        .foregroundColor(AKColor.brand)
                    Text("发现新版本")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AKColor.text)
                    if let info, !info.latestName.isEmpty {
                        Text("最新版本 \(info.latestName)")
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.muted)
                    }
                    ScrollView {
                        Text(info?.changelog.isEmpty == false ? (info?.changelog ?? "") : "修复已知问题，提升稳定性。")
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.sub)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 220)
                    if let u = URL(string: info?.url ?? ""), (info?.url ?? "").hasPrefix("http") {
                        Link(destination: u) {
                            Text("立即更新")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(AKColor.brand)
                                .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                        }
                    }
                }
                .padding(22)
                .presentationDetents([.medium])
                .interactiveDismissDisabled(true)
            }
    }

    private func check() async {
        guard info == nil else { return }
        if let v = try? await APIClient.shared.appVersion(), v.latestCode > currentCode {
            info = v
        }
    }
}

extension View {
    func updateGate() -> some View { modifier(UpdateGate()) }
}
