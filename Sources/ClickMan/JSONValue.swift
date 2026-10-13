import Foundation

/// A JSON value: what the properties, traits and context of an event are made of.
enum JSONValue: Sendable, Equatable, Encodable {
    case null
    case bool(Bool)
    case integer(Int64)
    case unsigned(UInt64)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    /// A value with no JSON form, named by what it is.
    struct NotJSON: Error, CustomStringConvertible {
        let description: String
    }

    /// A host value as JSON: Foundation's JSON types, with `Date`, `URL` and
    /// `UUID` as strings.
    init(_ value: Any) throws {
        var conversion = JSONConversion()
        self = try conversion.value(value)
    }

    /// Host properties or traits as a JSON object.
    static func object(from host: [String: Any]) throws -> [String: JSONValue] {
        var conversion = JSONConversion()
        return try host.mapValues { try conversion.value($0, depth: 1) }
    }

    /// The JSON object `text` holds, e.g. the stored traits.
    static func object(parsing text: String) throws -> [String: JSONValue] {
        guard case .object(let members) = try JSONValue(JSONSerialization.jsonObject(with: Data(text.utf8))) else {
            throw NotJSON(description: "\(text) is not a JSON object")
        }
        return members
    }

    /// The value as JSON text, its keys sorted.
    func json() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .unsigned(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let values): try container.encode(values)
        case .object(let members): try container.encode(members)
        }
    }

}
