import Foundation

public struct TaskTurnRequest: Equatable, Sendable {
    public let text: String
    public let currentURL: String

    public init(text: String, currentURL: String) {
        self.text = text
        self.currentURL = currentURL
    }
}

public struct CompactEvidence: Equatable, Sendable {
    public let source: String
    public let quote: String

    public init(source: String, quote: String) {
        self.source = source
        self.quote = quote
    }
}

public struct TaskTurnResult: Equatable, Sendable {
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

public enum TaskTurnEvent: Equatable, Sendable {
    case update(String)
    case needsInput(String)
    case requestedHumanHandoff(String)
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

public protocol InterruptibleInPageTaskEngine: InPageTaskEngine {
    func interruptTask()
}

public final class PageAgentTaskRunner: BrowserSubagentTaskRunner {
    private let engine: InPageTaskEngine
    private let modelBridge: SessionModelBridge
    private let progressInterval: TimeInterval
    private let executionQueue: DispatchQueue
    private let interruptQueue: DispatchQueue
    private let progressQueue: DispatchQueue
    private let eventQueue: DispatchQueue

    public init(
        engine: InPageTaskEngine,
        modelBridge: SessionModelBridge,
        progressInterval: TimeInterval = 5,
        executionQueue: DispatchQueue = DispatchQueue(label: "tweb.page-agent.task", qos: .userInitiated),
        interruptQueue: DispatchQueue = DispatchQueue(label: "tweb.page-agent.interrupt", qos: .userInitiated),
        progressQueue: DispatchQueue = DispatchQueue(label: "tweb.page-agent.progress", qos: .utility),
        eventQueue: DispatchQueue = .main
    ) {
        self.engine = engine
        self.modelBridge = modelBridge
        self.progressInterval = progressInterval
        self.executionQueue = executionQueue
        self.interruptQueue = interruptQueue
        self.progressQueue = progressQueue
        self.eventQueue = eventQueue
    }

    public func startTask(_ request: TaskTurnRequest, events: TaskTurnEventSink) throws -> RunningTask {
        let task = PageAgentRunningTask(
            request: request,
            engine: engine,
            modelBridge: modelBridge,
            events: events,
            progressInterval: progressInterval,
            executionQueue: executionQueue,
            interruptQueue: interruptQueue,
            progressQueue: progressQueue,
            eventQueue: eventQueue
        )
        task.start()
        return task
    }
}

private final class PageAgentRunningTask: RunningTask, @unchecked Sendable {
    private let request: TaskTurnRequest
    private let engine: InPageTaskEngine
    private let modelBridge: SessionModelBridge
    private weak var events: TaskTurnEventSink?
    private let progressInterval: TimeInterval
    private let executionQueue: DispatchQueue
    private let interruptQueue: DispatchQueue
    private let progressQueue: DispatchQueue
    private let eventQueue: DispatchQueue
    private let baselineModelRequestCount: Int
    private let lock = NSLock()
    private var finished = false
    private var interrupted = false
    private var progressTimer: DispatchSourceTimer?

    init(
        request: TaskTurnRequest,
        engine: InPageTaskEngine,
        modelBridge: SessionModelBridge,
        events: TaskTurnEventSink,
        progressInterval: TimeInterval,
        executionQueue: DispatchQueue,
        interruptQueue: DispatchQueue,
        progressQueue: DispatchQueue,
        eventQueue: DispatchQueue
    ) {
        self.request = request
        self.engine = engine
        self.modelBridge = modelBridge
        self.events = events
        self.progressInterval = progressInterval
        self.executionQueue = executionQueue
        self.interruptQueue = interruptQueue
        self.progressQueue = progressQueue
        self.eventQueue = eventQueue
        self.baselineModelRequestCount = modelBridge.modelRequestCount
    }

    func start() {
        startProgressTimer()
        executionQueue.async { [weak self] in
            guard let self else { return }
            do {
                let result = try self.engine.runTask(InPageTaskRequest(
                    text: self.request.text,
                    currentURL: self.request.currentURL,
                    modelBridge: self.modelBridge
                ))
                self.finish(.result(result))
            } catch {
                self.finish(.failed("task failed: \(error)"))
            }
        }
    }

    func provideSteering(_ text: String) {}

    func interrupt() {
        let shouldInterrupt: Bool
        lock.lock()
        shouldInterrupt = !finished && !interrupted
        interrupted = true
        progressTimer?.cancel()
        progressTimer = nil
        lock.unlock()

        guard shouldInterrupt else { return }
        interruptQueue.async { [weak self] in
            guard let self else { return }
            (self.engine as? InterruptibleInPageTaskEngine)?.interruptTask()
        }
    }

    private func startProgressTimer() {
        guard progressInterval > 0 else { return }

        let timer = DispatchSource.makeTimerSource(queue: progressQueue)
        timer.schedule(
            deadline: .now() + progressInterval,
            repeating: progressInterval
        )
        timer.setEventHandler { [weak self] in
            self?.emitProgressUpdate()
        }

        lock.lock()
        progressTimer = timer
        lock.unlock()
        timer.resume()
    }

    private func emitProgressUpdate() {
        lock.lock()
        let shouldEmit = !finished && !interrupted
        lock.unlock()
        guard shouldEmit else { return }

        let count = modelBridge.modelRequestCount - baselineModelRequestCount
        events?.handleTaskEvent(.update("PageAgent task running: \(count) model turns"))
    }

    private func finish(_ event: TaskTurnEvent) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        let shouldEmit = !interrupted
        progressTimer?.cancel()
        progressTimer = nil
        lock.unlock()

        guard shouldEmit else { return }
        emit(event)
    }

    private func emit(_ event: TaskTurnEvent) {
        eventQueue.async { [weak self] in
            guard let self, self.shouldDeliverQueuedEvent(event) else { return }
            self.events?.handleTaskEvent(event)
        }
    }

    private func shouldDeliverQueuedEvent(_ event: TaskTurnEvent) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        switch event {
        case .update:
            return !finished && !interrupted
        case .needsInput, .requestedHumanHandoff, .result, .failed:
            return !interrupted
        }
    }
}
