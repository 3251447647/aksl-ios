import Foundation
import QuartzCore

/// 仅 DEBUG 生效的耗时日志：`[AKPerf] home.conversations 128.4ms · 12 个会话`
/// Release 下 start() 返回 0、log() 空实现，调用点不需要额外分支。
enum AKPerf {
    #if DEBUG
    static func start() -> CFTimeInterval {
        CACurrentMediaTime()
    }

    static func log(_ label: String, since start: CFTimeInterval, _ note: String = "") {
        let ms = (CACurrentMediaTime() - start) * 1000
        let suffix = note.isEmpty ? "" : " · \(note)"
        print(String(format: "[AKPerf] %@ %.1fms%@", label, ms, suffix))
    }
    #else
    @inline(__always)
    static func start() -> CFTimeInterval { 0 }

    @inline(__always)
    static func log(_ label: String, since start: CFTimeInterval, _ note: String = "") {}
    #endif
}
