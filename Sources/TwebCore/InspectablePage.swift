import Foundation

public enum ScreenshotCaptureMode: Equatable {
    case fullPage
}

public protocol InspectablePage: AnyObject {
    func evaluateJavaScript(_ source: String) throws -> JSONValue
    func captureScreenshot(mode: ScreenshotCaptureMode) throws -> Data
    func currentHTML() throws -> String
}

public enum JSONValue: Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

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
