import Foundation

struct PrettyCategory: Decodable, Identifiable, Equatable {
    let id: Int64
    let name: String
    let count: Int

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        name = (try? c.decode(String.self, forKey: .name)) ?? "全部"
        count = (try? c.decode(Int.self, forKey: .count)) ?? 0
    }

    enum CodingKeys: String, CodingKey { case id, name, count }
}

struct PrettyCategoriesData: Decodable {
    let list: [PrettyCategory]

    enum CodingKeys: String, CodingKey { case list }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decode([PrettyCategory].self, forKey: .list)) ?? []
    }
}

struct PrettyNumberItem: Decodable, Identifiable, Equatable {
    let id: Int64
    let number: String
    let price: Int
    let categoryId: Int64

    enum CodingKeys: String, CodingKey {
        case id, number, price
        case categoryId = "category_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        number = (try? c.decode(String.self, forKey: .number)) ?? ""
        price = (try? c.decode(Int.self, forKey: .price)) ?? 0
        categoryId = (try? c.decode(Int64.self, forKey: .categoryId)) ?? 0
    }
}

struct PrettyListData: Decodable {
    let list: [PrettyNumberItem]

    enum CodingKeys: String, CodingKey { case list }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = (try? c.decode([PrettyNumberItem].self, forKey: .list)) ?? []
    }
}

extension APIClient {
    func prettyCategories() async throws -> [PrettyCategory] {
        let data: PrettyCategoriesData = try await get("api/v1/pretty/categories")
        return data.list
    }

    func prettyList(categoryId: Int64, kind: String) async throws -> [PrettyNumberItem] {
        let data: PrettyListData = try await get("api/v1/pretty/list", query: [
            "category_id": "\(categoryId)",
            "kind": kind,
        ])
        return data.list
    }

    func buyPretty(id: Int64, payPassword: String) async throws {
        _ = try await postRaw("api/v1/pretty/buy", body: ["id": id, "pay_password": payPassword])
    }
}
