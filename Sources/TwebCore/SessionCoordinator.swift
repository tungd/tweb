import Foundation

public enum SessionReceiveOutcome: Equatable {
    case continueSession
    case exit
}

public final class SessionCoordinator {
    private let browser: BrowserSession
    private let output: ProtocolOutput
    private var started = false

    public init(browser: BrowserSession, output: ProtocolOutput) {
        self.browser = browser
        self.output = output
        self.browser.onEvent = { [weak self] event in
            self?.handleBrowserEvent(event)
        }
    }

    public func start(launchURL: String?) throws {
        guard !started else { return }
        started = true
        try browser.startHidden()
        try browser.load(launchURL ?? "about:blank")
        output.write(.ready(url: browser.currentURL))
    }

    public func receiveLine(_ line: String) throws -> SessionReceiveOutcome {
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
            output.write(.update("status: \(status)"))
        case .urlChanged(let url):
            output.write(.update("url: \(url)"))
        }
    }
}
