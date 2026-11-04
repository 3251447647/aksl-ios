import Foundation

/// 消息 extra 字段随 type 变化（红包/转账/礼物/名片/通话…），
/// 用统一容器承接，避免为每种卡片再定义一套 Decodable。
enum JSONValue: Decodable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Double.self) { self = .number(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([String: JSONValue].self) { self = .object(v); return }
        if let v = try? c.decode([JSONValue].self) { self = .array(v); return }
        self = .null
    }

    var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .number(let d): return d == d.rounded() ? String(Int64(d)) : String(d)
        case .bool(let b): return b ? "1" : "0"
        default: return nil
        }
    }

    var intValue: Int? {
        switch self {
        case .number(let d): return Int(d)
        case .string(let s): return Int(s.trimmingCharacters(in: .whitespaces))
        case .bool(let b): return b ? 1 : 0
        default: return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .number(let d): return d
        case .string(let s): return Double(s.trimmingCharacters(in: .whitespaces))
        case .bool(let b): return b ? 1 : 0
        default: return nil
        }
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }
}

extension Dictionary where Key == String, Value == JSONValue {
    func str(_ key: String) -> String { self[key]?.stringValue ?? "" }
    func int(_ key: String) -> Int { self[key]?.intValue ?? 0 }
    func dbl(_ key: String) -> Double { self[key]?.doubleValue ?? 0 }
}
