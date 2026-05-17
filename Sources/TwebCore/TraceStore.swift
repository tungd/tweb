import Foundation

public struct TraceEvent: Equatable {
    public let type: String
    public let message: String

    public init(type: String, message: String) {
        self.type = type
        self.message = message
    }
}

public final class TraceStore {
    private var events: [TraceEvent] = []

    public init() {}

    public func record(type: String, message: String) {
        events.append(TraceEvent(type: type, message: message))
    }

    public func snapshot() -> [TraceEvent] {
        events
    }

    public func renderJSON() -> String {
        let renderedEvents = events.map { event in
            "{\(quote("message")):\(quote(event.message)),\(quote("type")):\(quote(event.type))}"
        }
        return "{\(quote("events")):[\(renderedEvents.joined(separator: ","))]}"
    }

    private func quote(_ value: String) -> String {
        let data = try? JSONEncoder().encode(value)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\(value)\""
    }
}
