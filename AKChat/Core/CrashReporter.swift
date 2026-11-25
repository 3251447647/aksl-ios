import Foundation
import UIKit
import Darwin

/// 崩溃兜底记录 + 静默上报（与安卓 CrashLog 对齐）：
/// - 安装 NSSetUncaughtExceptionHandler 与 signal 处理器，把崩溃现场写入 Documents/last_crash.txt；
/// - 下次启动时若已登录，静默 POST /api/v1/log/crash，成功后删除文件；
/// - 任何一步失败都只影响上报本身，不弹窗、不阻塞启动。
enum CrashReporter {
    private static let fileName = "last_crash.txt"
    /// 与服务端 yx_crash_log.stack（TEXT，接口截 16000）对齐，本地先截一刀，避免请求体过大
    private static let maxStackChars = 12000

    /// signal 处理器里不能做会分配内存的操作（不能拼 String、不能用 FileManager），
    /// 所以路径与缓冲区在 install 时提前准备好，回调里只调 open/write/close。
    private static var signalPath: UnsafeMutablePointer<CChar>?
    private static var signalBuffer: UnsafeMutablePointer<CChar>?
    /// NSException 已经写过完整堆栈：随后 abort 触发的 SIGABRT 不能再把文件刷成一行「signal 6」
    private static var exceptionRecorded = false
    /// 设备串在 install 时（主线程）先算好：崩溃回调里不再碰 UIDevice
    private static var cachedDevice: String?

    private static var fileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(fileName)
    }

    // MARK: - 安装

    /// 在 didFinishLaunching 最前面调用，尽量覆盖启动早期的崩溃
    static func install() {
        /* 先在正常上下文里把静态变量初始化一遍（全局变量首次访问带锁），
           signal 处理器里再读就不会走到惰性初始化逻辑 */
        exceptionRecorded = false
        if signalBuffer == nil {
            let buf = UnsafeMutablePointer<CChar>.allocate(capacity: 160)
            buf.initialize(repeating: 0, count: 160)
            signalBuffer = buf
        }
        if let path = fileURL?.path, signalPath == nil {
            signalPath = strdup(path)
        }
        _ = deviceLabel()
        let onException: @convention(c) (NSException) -> Void = handleException
        NSSetUncaughtExceptionHandler(onException)
        /* 只接管常见的致命信号；写文件失败也照旧走系统默认处理 */
        let handler: @convention(c) (Int32) -> Void = handleSignal
        for sig in [SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGTRAP] {
            _ = signal(sig, handler)
        }
    }

    // MARK: - 记录

    /// 未捕获 Objective-C 异常：能拿到完整符号堆栈，是定位问题的主要来源
    static func recordException(_ exception: NSException) {
        var lines: [String] = []
        lines.append("time: \(formattedNow())")
        lines.append("version: \(versionLabel())")
        lines.append("device: \(deviceLabel())")
        lines.append("exception: \(exception.name.rawValue)")
        lines.append("reason: \(exception.reason ?? "")")
        let symbols = exception.callStackSymbols
        if !symbols.isEmpty {
            lines.append("stack:")
            lines.append(contentsOf: symbols)
        }
        let text = String(lines.joined(separator: "\n").prefix(maxStackChars))
        guard let url = fileURL else { return }
        try? text.write(to: url, atomically: true, encoding: .utf8)
        exceptionRecorded = true
    }

    /// signal 处理器里可用：固定缓冲 + open/write，不做 Swift 字符串与集合分配
    static func recordSignal(_ sig: Int32) {
        /* 异常处理器刚写过完整堆栈，不要用简化内容覆盖 */
        guard !exceptionRecorded else { return }
        guard let path = signalPath, let buf = signalBuffer else { return }
        let fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o600)
        guard fd >= 0 else { return }
        let n = snprintf(buf, 160, "signal %d\n", sig)
        if n > 0 {
            _ = write(fd, buf, Int(n))
        }
        close(fd)
    }

    // MARK: - 读取 / 清理

    /// 上次启动是否留下崩溃文件；只取前 maxStackChars 个字符
    static func pendingCrash() -> String? {
        guard let url = fileURL,
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxStackChars))
    }

    static func clear() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - 上报

    /// 启动时调用一次：无登录态 / 无崩溃文件 / 上报失败都静默返回。
    /// 请求放在 detached task 里，绝不占用启动路径。
    static func reportPendingIfNeeded() {
        guard SessionStore.shared.token?.isEmpty == false else { return }
        guard let stack = pendingCrash() else { return }
        /* 版本与设备信息在调用线程读好再进后台，避免后台线程触碰 UIKit */
        let body: [String: Any] = [
            "version": versionLabel(),
            "device": deviceLabel(),
            "stack": stack,
        ]
        Task.detached(priority: .background) {
            do {
                _ = try await APIClient.shared.postRaw("api/v1/log/crash", body: body)
                /* 只有服务端确认成功才删本地文件；失败保留，下次启动重试 */
                clear()
            } catch {
                /* 静默：上报失败不影响启动，也不打扰用户 */
            }
        }
    }

    // MARK: - 环境信息

    static func versionLabel() -> String {
        let name = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        return name.isEmpty ? "v-unknown" : "v\(name)"
    }

    static func deviceLabel() -> String {
        if let cached = cachedDevice, !cached.isEmpty { return cached }
        var info = utsname()
        _ = uname(&info)
        let machine = withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        let system = UIDevice.current.systemVersion
        let label = machine.isEmpty ? "iOS \(system)" : "\(machine) (iOS \(system))"
        cachedDevice = label
        return label
    }

    private static func formattedNow() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
}

// MARK: - C 回调（必须是顶层无捕获函数，才能转成函数指针）

private func handleException(_ exception: NSException) {
    CrashReporter.recordException(exception)
}

private func handleSignal(_ sig: Int32) {
    CrashReporter.recordSignal(sig)
    /* 记录完恢复默认处理并重新抛出，让系统按原流程结束进程（不改变崩溃行为） */
    _ = signal(sig, SIG_DFL)
    _ = raise(sig)
}
