import Foundation

extension APIClient {
    /// 发送邮箱验证码：purpose = register / reset
    func sendEmailCode(email: String, purpose: String) async throws -> String {
        try await postRaw("api/v1/auth/email_code", body: ["email": email, "purpose": purpose])
    }

    /// 注册成功后直接返回登录态（与网页端同一接口）
    func register(nickname: String, password: String, email: String,
                  code: String, invite: String) async throws -> LoginData {
        var body: [String: Any] = [
            "nickname": nickname,
            "password": password,
            "email": email,
            "email_code": code,
            "device_id": SessionStore.shared.deviceId,
            "device_name": "iPhone",
            "platform": "ios",
        ]
        if !invite.isEmpty { body["invite_code"] = invite }
        return try await post("api/v1/auth/register", body: body)
    }

    /// 找回密码：重置后所有设备下线，需要重新登录
    func resetPassword(email: String, code: String, password: String) async throws {
        _ = try await postRaw("api/v1/auth/reset_password", body: [
            "email": email,
            "code": code,
            "password": password,
        ])
    }
}
