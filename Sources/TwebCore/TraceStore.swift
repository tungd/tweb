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
    private let lock = NSLock()
    private var events: [TraceEvent] = []

    public init() {}

    public func record(type: String, message: String) {
        lock.lock()
        defer { lock.unlock() }
        events.append(TraceEvent(type: type, message: message))
    }

    public func snapshot() -> [TraceEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }

    public func renderJSON() -> String {
        lock.lock()
        defer { lock.unlock() }
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
