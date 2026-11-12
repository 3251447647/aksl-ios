import Foundation

/// 设备时钟可能与服务器有偏差。撤回时限等规则按服务端时间计算，
/// 接口带回 server_time 时校准一次；偏差不超过 60 秒不校正，避免网络往返抖动。
enum ServerClock {
    private static let lock = NSLock()
    private static var offset: Int64 = 0

    static func sync(_ serverSec: Int64) {
        guard serverSec > 0 else { return }
        let diff = serverSec - Int64(Date().timeIntervalSince1970)
        lock.lock()
        offset = abs(diff) > 60 ? diff : 0
        lock.unlock()
    }

    static var nowSec: Int64 {
        lock.lock()
        let off = offset
        lock.unlock()
        return Int64(Date().timeIntervalSince1970) + off
    }
}
