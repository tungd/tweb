import Foundation

public enum SessionReceiveOutcome: Equatable {
    case continueSession
    case exit
}

public enum SessionRuntimeError: Error, Equatable, CustomStringConvertible {
    case unusable(String)

    public var description: String {
        switch self {
        case .unusable(let message):
            return "unusable session: \(message)"
        }
    }
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
    private let engineReinstaller: EngineReinstaller?
    private let handoffController: HandoffController?
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

    public var usesNetworkIdleHeuristics: Bool {
        false
    }

    public init(
        browser: BrowserSession,
        output: ProtocolOutput,
        slashCommandHandler: SlashCommandHandler? = nil,
        trace: TraceStore? = nil,
        taskRunner: BrowserSubagentTaskRunner? = nil,
        engineReinstaller: EngineReinstaller? = nil,
        handoffController: HandoffController? = nil
    ) {
        self.browser = browser
        self.output = output
        self.slashCommandHandler = slashCommandHandler
        self.trace = trace
        self.taskRunner = taskRunner
        self.engineReinstaller = engineReinstaller
        self.handoffController = handoffController
        self.browser.onEvent = { [weak self] event in
            self?.handleBrowserEvent(event)
        }
    }

    public func start(launchURL: String?) throws {
        guard !started else { return }
        started = true
        trace?.record(type: "session", message: "starting hidden session")
        do {
            try browser.startHidden()
            try browser.load(launchURL ?? "about:blank")
            trace?.record(type: "ready", message: browser.currentURL)
            output.write(.ready(url: browser.currentURL))
        } catch {
            trace?.record(type: "fatal", message: "session startup failed: \(error)")
            output.write(.fatal("session startup failed: \(error)"))
            throw error
        }
    }

    public func receiveLine(_ line: String) throws -> SessionReceiveOutcome {
        if line.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/") {
            let command: SlashCommand
            do {
                command = try SlashCommand.parse(line)
            } catch {
                output.write(.error(String(describing: error)))
                return .continueSession
            }
            if command == .quit {
                browser.close()
                return .exit
            }
            if command == .interrupt {
                return interruptCurrentTask()
            }
            if command == .human {
                return revealHumanHandoff()
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
        let handle: RunningTask
        do {
            handle = try taskRunner.startTask(
                TaskTurnRequest(text: taskText, currentURL: browser.currentURL),
                events: self
            )
        } catch {
            lifecycleState = .idle
            queuedSteering = []
            turnMemory = []
            trace?.record(type: "error", message: "task failed: \(error)")
            output.write(.error("task failed: \(error)"))
            return .continueSession
        }
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
            do {
                try engineReinstaller?.reinstall(afterTopLevelNavigationTo: url)
            } catch {
                trace?.record(type: "error", message: "engine reinstall failed: \(error)")
                output.write(.error("engine reinstall failed: \(error)"))
            }
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

    private func revealHumanHandoff() -> SessionReceiveOutcome {
        guard let handoffController else {
            output.write(.error("Human Handoff is not available in this session"))
            return .continueSession
        }

        do {
            let window = try handoffController.reveal(session: browser)
            trace?.record(type: "human-handoff", message: window.url)
            output.write(.update("human handoff visible: \(window.url)"))
        } catch {
            output.write(.error("human handoff failed: \(error)"))
        }
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
        case .requestedHumanHandoff(let message):
            trace?.record(type: "needs-input", message: "human handoff requested: \(message)")
            lifecycleState = .needsInput
            output.write(.needsInput(
                "Browser Subagent requested Human Handoff: \(message). Parent Agent must invoke /human."
            ))
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
