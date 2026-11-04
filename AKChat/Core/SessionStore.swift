import Foundation

/// 登录态持久化。首个版本先用 UserDefaults，接入钥匙串在安全加固阶段再做。
final class SessionStore {
    static let shared = SessionStore()

    private let tokenKey = "ak.token"
    private let refreshKey = "ak.refresh"
    private let userKey = "ak.user"
    private let deviceKey = "ak.device_id"

    private let defaults = UserDefaults.standard

    var token: String? {
        get { defaults.string(forKey: tokenKey) }
        set { defaults.set(newValue, forKey: tokenKey) }
    }

    var refreshToken: String? {
        get { defaults.string(forKey: refreshKey) }
        set { defaults.set(newValue, forKey: refreshKey) }
    }

    var deviceId: String {
        if let id = defaults.string(forKey: deviceKey), !id.isEmpty { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: deviceKey)
        return id
    }

    var user: User? {
        get {
            guard let data = defaults.data(forKey: userKey) else { return nil }
            return try? JSONDecoder().decode(User.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: userKey)
            } else {
                defaults.removeObject(forKey: userKey)
            }
        }
    }

    var isLoggedIn: Bool { (token?.isEmpty == false) }

    func clear() {
        defaults.removeObject(forKey: tokenKey)
        defaults.removeObject(forKey: refreshKey)
        defaults.removeObject(forKey: userKey)
    }
}
