import Foundation

public enum ScreenshotCaptureMode: Equatable, Sendable {
    case fullPage
}

public protocol InspectablePage: AnyObject {
    func evaluateJavaScript(_ source: String) throws -> JSONValue
    func captureScreenshot(mode: ScreenshotCaptureMode) throws -> Data
    func currentHTML() throws -> String
}

public enum JSONValue: Equatable, Sendable, Codable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let values):
            try container.encode(values)
        case .object(let object):
            try container.encode(object)
        }
    }

    public var rendered: String {
        switch self {
        case .null:
            return "null"
        case .bool(let value):
            return value ? "true" : "false"
        case .number(let value):
            if value.rounded() == value {
                return String(Int(value))
            }
            return String(value)
        case .string(let value):
            return Self.quote(value)
        case .array(let values):
            return "[" + values.map(\.rendered).joined(separator: ",") + "]"
        case .object(let object):
            let fields = object.keys.sorted().map { key in
                "\(Self.quote(key)):\(object[key]?.rendered ?? "null")"
            }
            return "{" + fields.joined(separator: ",") + "}"
        }
    }

    private static func quote(_ value: String) -> String {
        let data = try? JSONEncoder().encode(value)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\(value)\""
    }
}
