import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @AppStorage("ak.notify.sound") private var sound = true
    @AppStorage("ak.notify.vibrate") private var vibrate = true
    @State private var showLogout = false
    @State private var showDelete = false

    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

    var body: some View {
        Form {
            Section("消息通知") {
                Toggle("声音", isOn: $sound)
                Toggle("震动", isOn: $vibrate)
                Button("打开系统通知设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Text("横幅样式、免打扰与会话通知开关由系统「设置 → 通知 → AK商聊」控制。")
                    .font(.system(size: 11))
                    .foregroundColor(AKColor.muted)
            }
            Section("账号") {
                NavigationLink("隐私与安全") { PrivacySettingsView() }
                NavigationLink("我的收藏") { FavoritesView() }
                NavigationLink("黑名单") { BlacklistView() }
            }
            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text(version).foregroundColor(AKColor.muted)
                }
                Link("关于我们", destination: URL(string: "https://www.aksliao.cn/about.php")!)
                Link("联系客服", destination: URL(string: "https://www.aksliao.cn/service.php")!)
                Link("用户协议与隐私政策", destination: URL(string: "https://www.aksliao.cn/register.php")!)
            }
            Section {
                Button(role: .destructive) {
                    showLogout = true
                } label: {
                    Text("退出登录")
                }
                Button(role: .destructive) {
                    showDelete = true
                } label: {
                    Text("注销账号")
                }
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .alert("退出登录？", isPresented: $showLogout) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) { app.logout() }
        }
        .alert("确定注销账号？", isPresented: $showDelete) {
            Button("取消", role: .cancel) {}
            Button("确认注销", role: .destructive) {
                Task {
                    await APIClient.shared.deleteAccount()
                    app.logout()
                }
            }
        } message: {
            Text("注销后账号与聊天记录无法恢复。")
        }
    }
}
