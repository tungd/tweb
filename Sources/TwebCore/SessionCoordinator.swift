import Foundation

public enum SessionReceiveOutcome: Equatable {
    case continueSession
    case exit
}

public enum TaskLifecycleState: Equatable {
    case idle
    case running
    case needsInput
}

public struct SessionDebugState: Equatable {
    public let lifecycleState: TaskLifecycleState
    public let queuedSteering: [String]
    public let turnMemoryCount: Int
}

public final class SessionCoordinator {
    private let browser: BrowserSession
    private let output: ProtocolOutput
    private let slashCommandHandler: SlashCommandHandler?
    private let trace: TraceStore?
    private let taskRunner: BrowserSubagentTaskRunner?
    private var started = false
    private var activeTask: RunningTask?
    private var lifecycleState: TaskLifecycleState = .idle
    private var queuedSteering: [String] = []
    private var turnMemory: [String] = []

    public var debugState: SessionDebugState {
        SessionDebugState(
            lifecycleState: lifecycleState,
            queuedSteering: queuedSteering,
            turnMemoryCount: turnMemory.count
        )
    }

    public init(
        browser: BrowserSession,
        output: ProtocolOutput,
        slashCommandHandler: SlashCommandHandler? = nil,
        trace: TraceStore? = nil,
        taskRunner: BrowserSubagentTaskRunner? = nil
    ) {
        self.browser = browser
        self.output = output
        self.slashCommandHandler = slashCommandHandler
        self.trace = trace
        self.taskRunner = taskRunner
        self.browser.onEvent = { [weak self] event in
            self?.handleBrowserEvent(event)
        }
    }

    public func start(launchURL: String?) throws {
        guard !started else { return }
        started = true
        trace?.record(type: "session", message: "starting hidden session")
        try browser.startHidden()
        try browser.load(launchURL ?? "about:blank")
        trace?.record(type: "ready", message: browser.currentURL)
        output.write(.ready(url: browser.currentURL))
    }

    public func receiveLine(_ line: String) throws -> SessionReceiveOutcome {
        if line.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/") {
            let command = try SlashCommand.parse(line)
            if command == .quit {
                browser.close()
                return .exit
            }
            if command == .interrupt {
                return interruptCurrentTask()
            }

            guard let slashCommandHandler else {
                output.write(.error("unsupported command in this session"))
                return .continueSession
            }

            return try slashCommandHandler.handle(command)
        }

        let taskText = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !taskText.isEmpty else {
            return .continueSession
        }

        if lifecycleState == .running {
            activeTask?.provideSteering(taskText)
            queuedSteering.append(taskText)
            turnMemory.append(taskText)
            trace?.record(type: "queued-steering", message: taskText)
            output.write(.update("queued steering: \(taskText)"))
            return .continueSession
        }

        if lifecycleState == .needsInput {
            activeTask?.provideSteering(taskText)
            turnMemory.append(taskText)
            lifecycleState = .running
            trace?.record(type: "steering", message: taskText)
            output.write(.update("steering received"))
            return .continueSession
        }

        guard let taskRunner else {
            output.write(.error("unsupported input: \(line)"))
            return .continueSession
        }

        trace?.record(type: "task", message: taskText)
        lifecycleState = .running
        queuedSteering = []
        turnMemory = [taskText]
        let handle = try taskRunner.startTask(
            TaskTurnRequest(text: taskText, currentURL: browser.currentURL),
            events: self
        )
        if lifecycleState != .idle {
            activeTask = handle
        }
        return .continueSession
    }

    public func semanticSessionMemorySnapshot() -> [String] {
        []
    }

    private func handleBrowserEvent(_ event: BrowserEvent) {
        switch event {
        case .status(let status):
            trace?.record(type: "status", message: status)
            output.write(.update("status: \(status)"))
        case .urlChanged(let url):
            trace?.record(type: "url", message: url)
            output.write(.update("url: \(url)"))
        }
    }

    private func interruptCurrentTask() -> SessionReceiveOutcome {
        guard let activeTask else {
            output.write(.error("no active Task Turn to interrupt"))
            return .continueSession
        }

        activeTask.interrupt()
        self.activeTask = nil
        lifecycleState = .idle
        queuedSteering = []
        turnMemory = []
        trace?.record(type: "interrupt", message: "current Task Turn interrupted")
        output.write(.error("interrupted current Task Turn"))
        return .continueSession
    }
}

extension SessionCoordinator: TaskTurnEventSink {
    public func handleTaskEvent(_ event: TaskTurnEvent) {
        switch event {
        case .update(let message):
            trace?.record(type: "task-update", message: message)
            output.write(.update(message))
        case .needsInput(let message):
            trace?.record(type: "needs-input", message: message)
            lifecycleState = .needsInput
            output.write(.needsInput(message))
        case .result(let result):
            trace?.record(type: "result", message: result.text)
            activeTask = nil
            lifecycleState = .idle
            queuedSteering = []
            turnMemory = []
            output.write(.result(result.protocolBody))
        case .failed(let message):
            trace?.record(type: "error", message: message)
            activeTask = nil
            lifecycleState = .idle
            queuedSteering = []
            turnMemory = []
            output.write(.error(message))
        }
    }
}
