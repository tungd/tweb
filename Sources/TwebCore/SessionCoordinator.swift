import Foundation

public enum SessionReceiveOutcome: Equatable {
    case continueSession
    case exit
}

public final class SessionCoordinator {
    private let browser: BrowserSession
    private let output: ProtocolOutput
    private let slashCommandHandler: SlashCommandHandler?
    private let trace: TraceStore?
    private let taskRunner: BrowserSubagentTaskRunner?
    private var started = false
    private var activeTask: RunningTask?

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

            guard let slashCommandHandler else {
                output.write(.error("unsupported command in this session"))
                return .continueSession
            }

            return try slashCommandHandler.handle(command)
        }

        if line.trimmingCharacters(in: .whitespacesAndNewlines) == "/quit" {
            browser.close()
            return .exit
        }

        let taskText = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !taskText.isEmpty else {
            return .continueSession
        }

        guard let taskRunner else {
            output.write(.error("unsupported input: \(line)"))
            return .continueSession
        }

        trace?.record(type: "task", message: taskText)
        let handle = try taskRunner.startTask(
            TaskTurnRequest(text: taskText, currentURL: browser.currentURL),
            events: self
        )
        if activeTask !== nil {
            activeTask = handle
        }
        return .continueSession
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
}

extension SessionCoordinator: TaskTurnEventSink {
    public func handleTaskEvent(_ event: TaskTurnEvent) {
        switch event {
        case .update(let message):
            trace?.record(type: "task-update", message: message)
            output.write(.update(message))
        case .needsInput(let message):
            trace?.record(type: "needs-input", message: message)
            output.write(.needsInput(message))
        case .result(let result):
            trace?.record(type: "result", message: result.text)
            activeTask = nil
            output.write(.result(result.protocolBody))
        case .failed(let message):
            trace?.record(type: "error", message: message)
            activeTask = nil
            output.write(.error(message))
        }
    }
}
