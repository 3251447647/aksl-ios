import SwiftUI

/// 关于与版本更新：当前版本 + 检查更新（iOS 通过浏览器下载，不做站内安装）
struct AboutUpdateView: View {
    @State private var info: AppVersionInfo?
    @State private var checking = false
    @State private var errorText: String?
    @State private var checkedAt: Date?

    private var currentVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private var hasUpdate: Bool {
        guard let info, let cur = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else { return false }
        return info.latestCode > (Int(cur) ?? 0)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("当前版本")
                    Spacer()
                    Text(currentVersion).foregroundColor(AKColor.muted)
                }
                Button {
                    Task { await check() }
                } label: {
                    HStack {
                        Text("检查更新")
                        Spacer()
                        if checking { ProgressView() }
                    }
                }
                .disabled(checking)
            }

            if let errorText {
                Section { Text(errorText).font(.system(size: 13)).foregroundColor(AKColor.red) }
            }

            if let info {
                Section("最新版本") {
                    HStack {
                        Text("版本号")
                        Spacer()
                        Text(info.latestName.isEmpty ? "\(info.latestCode)" : info.latestName)
                            .foregroundColor(AKColor.muted)
                    }
                    if !info.changelog.isEmpty {
                        Text(info.changelog)
                            .font(.system(size: 13))
                            .foregroundColor(AKColor.text)
                    }
                    if hasUpdate {
                        if let u = URL(string: info.url), !info.url.isEmpty {
                            Link("前往下载", destination: u)
                                .foregroundColor(AKColor.brand)
                        }
                    } else if checkedAt != nil {
                        Text("已是最新版本").font(.system(size: 13)).foregroundColor(AKColor.hint)
                    }
                }
            }
        }
        .navigationTitle("关于与更新")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if info == nil { await check() }
        }
    }

    private func check() async {
        checking = true
        defer { checking = false }
        do {
            info = try await APIClient.shared.appVersion()
            errorText = nil
            checkedAt = Date()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
