import Foundation

/// 服务端地址集中定义：域名只在这一处维护，改域名不必再翻各个页面。
/// 注意区分三个不同语义：官网首页、App 下载页（企业签名分发）、个人主页链接。
enum Endpoints {
    /// 主域名（带 www）：接口与 WebSocket 都走它
    static let host = "www.aksliao.cn"

    /// 接口根地址，末尾带 /，与 appendingPathComponent 搭配
    static let base = URL(string: "https://\(host)/")!

    /// 实时通道
    static let wsURL = URL(string: "wss://\(host)/ws")!

    /// 关于页展示的官网地址（后台未配置时用）
    static let officialSite = "https://\(host)"

    /// App 下载页：企业签名分发只走这里，不跟随后台「官方网站」配置
    static let downloadPage = URL(string: "https://aksliao.cn/")!

    /// 邀请注册链接：邀请码为空时用 AK号兜底
    static func inviteLink(code: String) -> String {
        "https://\(host)/register.php?invite=\(code)"
    }

    /// 个人主页链接：与邀请链接不是同一路径，个人二维码扫码后直接打开资料页
    static func userLink(uid: Int64) -> String {
        "https://\(host)/user.php?id=\(uid)"
    }
}
