import Foundation

/// A small JSON type for building API request bodies and schemas in a Sendable way.
enum JSONValue: Codable, Hashable, Sendable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral,
    ExpressibleByBooleanLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(stringLiteral value: String) { self = .string(value) }
    init(integerLiteral value: Int) { self = .number(Double(value)) }
    init(booleanLiteral value: Bool) { self = .bool(value) }
    init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
    init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { self = .object(try container.decode([String: JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    subscript(key: String) -> JSONValue? {
        if case .object(let object) = self { return object[key] }
        return nil
    }
}

/// Helpers for writing JSON Schemas for structured outputs.
/// Every object gets `additionalProperties: false` and lists all its properties as required,
/// which the API needs to guarantee the shape.
enum Schema {
    static let string: JSONValue = ["type": "string"]
    static let integer: JSONValue = ["type": "integer"]
    static let number: JSONValue = ["type": "number"]
    static let boolean: JSONValue = ["type": "boolean"]

    static func object(_ properties: [String: JSONValue]) -> JSONValue {
        .object([
            "type": "object",
            "properties": .object(properties),
            "required": .array(properties.keys.sorted().map(JSONValue.string)),
            "additionalProperties": false,
        ])
    }

    static func array(of items: JSONValue) -> JSONValue {
        ["type": "array", "items": items]
    }

    static func oneOf(_ values: [String]) -> JSONValue {
        ["type": "string", "enum": .array(values.map(JSONValue.string))]
    }

    static func nullable(_ schema: JSONValue) -> JSONValue {
        ["anyOf": [schema, ["type": "null"]]]
    }
}
