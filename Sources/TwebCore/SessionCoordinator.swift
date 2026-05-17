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
    private var started = false

    public init(
        browser: BrowserSession,
        output: ProtocolOutput,
        slashCommandHandler: SlashCommandHandler? = nil,
        trace: TraceStore? = nil
    ) {
        self.browser = browser
        self.output = output
        self.slashCommandHandler = slashCommandHandler
        self.trace = trace
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

        output.write(.error("unsupported input: \(line)"))
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
