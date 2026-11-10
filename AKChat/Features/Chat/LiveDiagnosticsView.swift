import SwiftUI

/// 直播链路的快照，诊断面板每秒刷新一次。
struct LiveDiagnosticsInfo {
    var shareMode = "未共享"
    var sfuRoom = ""
    var localIdentity = ""
    var connectionState = "unknown"
    var screenTrackReceived = false
    var lastFrameAge: TimeInterval?
    var mediaInterrupted = false
    var pipActive = false

    var problems: [String] {
        var items: [String] = []
        if mediaInterrupted {
            items.append("媒体连接已断开，点画面上的「点击重连」")
        }
        if shareMode != "未共享", !screenTrackReceived, !pipActive {
            if let age = lastFrameAge, age > 3 {
                items.append("屏幕轨已订阅，但最近 3 秒没有新帧（主播已切后台或编码卡住）")
            } else if lastFrameAge == nil {
                items.append("共享中，但还没收到第一帧画面")
            }
        }
        return items
    }
}

/// 隐藏诊断面板：长按直播间标题打开。
struct LiveDiagnosticsView: View {
    let snapshot: () -> LiveDiagnosticsInfo

    @Environment(\.dismiss) private var dismiss
    @State private var info = LiveDiagnosticsInfo()
    @State private var copied = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let dangerColor = Color(hex: 0xFF5B6B)
    private let okColor = Color(hex: 0x37C871)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if info.problems.isEmpty {
                        hintBlock("链路正常：主播正在出帧", color: okColor)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(info.problems.enumerated()), id: \.offset) { _, text in
                                Text(text)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(dangerColor)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(dangerColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    group("共享") {
                        row("模式", info.shareMode)
                        row("画面轨", info.screenTrackReceived ? "已收到" : "未收到",
                            ok: info.screenTrackReceived)
                        row("最近一帧", ageText(info.lastFrameAge),
                            ok: (info.lastFrameAge ?? .infinity) <= 3)
                        row("画中画", info.pipActive ? "开启" : "关闭")
                    }

                    group("媒体房间") {
                        row("SFU 房间", info.sfuRoom.isEmpty ? "-" : info.sfuRoom)
                        row("本机 identity", info.localIdentity.isEmpty ? "-" : info.localIdentity)
                        row("连接状态", info.connectionState)
                        row("连接中断", info.mediaInterrupted ? "是" : "否",
                            ok: !info.mediaInterrupted)
                    }

                    Text("诊断每秒刷新一次；长按任意位置可复制全文发给开发者。")
                        .font(.system(size: 10.5))
                        .foregroundColor(AKColor.text.opacity(0.45))
                        .padding(.top, 4)
                }
                .padding(16)
            }
            .background(AKColor.bg.ignoresSafeArea())
            .navigationTitle("直播链路诊断")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(copied ? "已复制" : "复制") {
                        UIPasteboard.general.string = plainText
                        copied = true
                    }
                }
            }
            .onAppear { info = snapshot() }
            .onReceive(timer) { _ in info = snapshot() }
        }
        .preferredColorScheme(.dark)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AKColor.text.opacity(0.6))
            VStack(alignment: .leading, spacing: 5) {
                content()
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AKColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func row(_ label: String, _ value: String, ok: Bool? = nil) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if let ok {
                Circle()
                    .fill(ok ? okColor : dangerColor)
                    .frame(width: 6, height: 6)
                    .padding(.top, 5)
            }
            Text(label)
                .font(.system(size: 11.5))
                .foregroundColor(AKColor.text.opacity(0.55))
                .frame(width: 108, alignment: .leading)
            Text(value)
                .font(.system(size: 11.5))
                .foregroundColor(AKColor.text)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func hintBlock(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(color)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func ageText(_ age: TimeInterval?) -> String {
        guard let age else { return "无记录" }
        if age < 1 { return "刚刚" }
        if age < 60 { return String(format: "%.1f 秒前", age) }
        return "\(Int(age / 60)) 分钟前"
    }

    private var plainText: String {
        var lines: [String] = ["AK商聊 直播诊断 \(Date())"]
        lines.append("模式: \(info.shareMode) 画面轨: \(info.screenTrackReceived) 最近一帧: \(ageText(info.lastFrameAge))")
        lines.append("画中画: \(info.pipActive)")
        lines.append("SFU: \(info.sfuRoom) 本机: \(info.localIdentity) 连接: \(info.connectionState)")
        lines.append("连接中断: \(info.mediaInterrupted)")
        lines.append("问题: \(info.problems.isEmpty ? "无" : info.problems.joined(separator: "；"))")
        return lines.joined(separator: "\n")
    }
}
