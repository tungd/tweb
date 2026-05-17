import Foundation

public struct TaskTurnRequest: Equatable {
    public let text: String
    public let currentURL: String

    public init(text: String, currentURL: String) {
        self.text = text
        self.currentURL = currentURL
    }
}

public struct CompactEvidence: Equatable {
    public let source: String
    public let quote: String

    public init(source: String, quote: String) {
        self.source = source
        self.quote = quote
    }
}

public struct TaskTurnResult: Equatable {
    public let text: String
    public let compactEvidence: [CompactEvidence]

    public init(text: String, compactEvidence: [CompactEvidence]) {
        self.text = text
        self.compactEvidence = compactEvidence
    }

    public var protocolBody: String {
        guard !compactEvidence.isEmpty else {
            return text
        }

        let evidence = compactEvidence.map { item in
            """
            - source: \(item.source)
              quote: \(item.quote)
            """
        }
        .joined(separator: "\n")

        return """
        \(text)
        compact-evidence:
        \(evidence)
        """
    }
}

public enum TaskTurnEvent: Equatable {
    case update(String)
    case needsInput(String)
    case result(TaskTurnResult)
    case failed(String)
}

public protocol TaskTurnEventSink: AnyObject {
    func handleTaskEvent(_ event: TaskTurnEvent)
}

public protocol RunningTask: AnyObject {
    func provideSteering(_ text: String)
    func interrupt()
}

public final class CompletedRunningTask: RunningTask {
    public init() {}
    public func provideSteering(_ text: String) {}
    public func interrupt() {}
}

public protocol BrowserSubagentTaskRunner {
    func startTask(_ request: TaskTurnRequest, events: TaskTurnEventSink) throws -> RunningTask
}

public struct InPageTaskRequest {
    public let text: String
    public let currentURL: String
    public let modelBridge: SessionModelBridge

    public init(text: String, currentURL: String, modelBridge: SessionModelBridge) {
        self.text = text
        self.currentURL = currentURL
        self.modelBridge = modelBridge
    }
}

public protocol InPageTaskEngine {
    func runTask(_ request: InPageTaskRequest) throws -> TaskTurnResult
}

public final class PageAgentTaskRunner: BrowserSubagentTaskRunner {
    private let engine: InPageTaskEngine
    private let modelBridge: SessionModelBridge

    public init(engine: InPageTaskEngine, modelBridge: SessionModelBridge) {
        self.engine = engine
        self.modelBridge = modelBridge
    }

    public func startTask(_ request: TaskTurnRequest, events: TaskTurnEventSink) throws -> RunningTask {
        let result = try engine.runTask(InPageTaskRequest(
            text: request.text,
            currentURL: request.currentURL,
            modelBridge: modelBridge
        ))
        events.handleTaskEvent(.result(result))
        return CompletedRunningTask()
    }
}
