import Foundation

extension APIClient {
    /// 只拉 afterId 之后的消息（服务端按 id 升序返回）。
    /// 用于 WS 漏帧 / 断线重连后的前台兜底轮询。
    func historyAfter(convType: String, convId: Int64, afterId: Int64, limit: Int = 50) async throws -> HistoryData {
        try await get("api/v1/messages", query: [
            "conv_type": convType,
            "conv_id": String(convId),
            "after_id": String(afterId),
            "limit": String(limit),
        ])
    }
}
