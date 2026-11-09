import Foundation

/// 群设置 / 群等级（GET /api/v1/group/settings）
struct GroupSettings: Decodable {
    let memberCount: Int
    let maxMember: Int
    let groupMaxMember: Int
    let ownerVipLevel: Int
    let ownerVipLabel: String
    let ownerGroupCount: Int
    let ownerUpgradeLeft: Int
    let upgradeMaxMember: Int
    let canUpgrade: Int

    enum CodingKeys: String, CodingKey {
        case memberCount = "member_count"
        case maxMember = "max_member"
        case groupMaxMember = "group_max_member"
        case ownerVipLevel = "owner_vip_level"
        case ownerVipLabel = "owner_vip_label"
        case ownerGroupCount = "owner_group_count"
        case ownerUpgradeLeft = "owner_upgrade_left"
        case upgradeMaxMember = "upgrade_max_member"
        case canUpgrade = "can_upgrade"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        memberCount = (try? c.decode(Int.self, forKey: .memberCount)) ?? 0
        maxMember = (try? c.decode(Int.self, forKey: .maxMember)) ?? 0
        groupMaxMember = (try? c.decode(Int.self, forKey: .groupMaxMember)) ?? 0
        ownerVipLevel = (try? c.decode(Int.self, forKey: .ownerVipLevel)) ?? 0
        ownerVipLabel = (try? c.decode(String.self, forKey: .ownerVipLabel)) ?? ""
        ownerGroupCount = (try? c.decode(Int.self, forKey: .ownerGroupCount)) ?? 0
        ownerUpgradeLeft = (try? c.decode(Int.self, forKey: .ownerUpgradeLeft)) ?? 0
        upgradeMaxMember = (try? c.decode(Int.self, forKey: .upgradeMaxMember)) ?? 0
        canUpgrade = (try? c.decode(Int.self, forKey: .canUpgrade)) ?? 0
    }
}

extension APIClient {
    func groupSettings(gid: Int64) async throws -> GroupSettings {
        try await get("api/v1/group/settings", query: ["id": "\(gid)"])
    }

    /// 升级群人数上限
    func upgradeGroup(gid: Int64) async throws {
        _ = try await postRaw("api/v1/group/upgrade", body: ["id": gid])
    }
}
