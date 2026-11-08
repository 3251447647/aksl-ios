import Foundation

extension APIClient {
    /// 聊天记录搜索：convType / convId 传空表示全局搜索
    func searchMessages(
        keyword: String,
        convType: String = "",
        convId: Int64 = 0,
        kind: String = "all",
        page: Int = 1,
        limit: Int = 30,
        beforeId: Int64 = 0,
        beforeTs: Int64 = 0
    ) async throws -> MessageSearchData {
        var q: [String: String] = [
            "keyword": keyword,
            "kind": kind,
            "page": String(page),
            "limit": String(limit)
        ]
        if !convType.isEmpty { q["conv_type"] = convType }
        if convId > 0 { q["conv_id"] = String(convId) }
        if beforeId > 0 { q["before_id"] = String(beforeId) }
        if beforeTs > 0 { q["before_ts"] = String(beforeTs) }
        return try await get("api/v1/search/messages", query: q)
    }

    /// 最新版本信息（免登录）
    func appVersion() async throws -> AppVersionInfo {
        try await get("api/v1/app/version")
    }
}
