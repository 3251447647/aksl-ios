import SwiftUI
import UIKit

/// 强制更新弹窗：只认服务端 iOS 专用版本字段（ios_*），ios_force=1 才拦截
struct UpdateGate: ViewModifier {
    @State private var info: AppVersionInfo?

    private var currentCode: Int {
        Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") ?? 0
    }

    private var blocked: Bool {
        guard let info else { return false }
        return info.iosForce == 1 && info.iosLatestCode > currentCode
    }

    /// 更新地址可能是 https 的 IPA 直链，也可能是 itms-services:// 的 OTA 清单
    private var updateURL: URL? {
        let raw = (info?.iosUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = raw.lowercased()
        guard lower.hasPrefix("http") || lower.hasPrefix("itms-services://") || lower.hasPrefix("itms-apps://"),
              let url = URL(string: raw) else { return nil }
        return url
    }

    func body(content: Content) -> some View {
        content
            .task { await check() }
            .sheet(isPresented: Binding(get: { blocked }, set: { _ in })) {
                VStack(spacing: 14) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 42))
                        .foregroundColor(AKColor.brand)
                    Text("请更新到新版本")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AKColor.text)
                    if let info, !info.iosLatestName.isEmpty {
                        Text("最新版本 \(info.iosLatestName)")
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.muted)
                    }
                    ScrollView {
                        Text((info?.iosChangelog.isEmpty == false ? (info?.iosChangelog ?? "") : "修复已知问题，提升稳定性。"))
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.sub)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 220)
                    if let u = updateURL {
                        Button {
                            UIApplication.shared.open(u)
                        } label: {
                            Text("前往下载")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(AKColor.brand)
                                .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(22)
                .presentationDetents([.medium])
                .interactiveDismissDisabled(true)
            }
    }

    private func check() async {
        guard info == nil else { return }
        info = try? await APIClient.shared.appVersion()
    }
}

extension View {
    func updateGate() -> some View { modifier(UpdateGate()) }
}
