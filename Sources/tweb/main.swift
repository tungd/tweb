import Foundation
import TwebCore

final class ControlledBrowserSession: BrowserSession {
    var onEvent: ((BrowserEvent) -> Void)?
    private(set) var currentURL: String = "about:blank"

    func startHidden() throws {
        onEvent?(.status("hidden session started"))
    }

    func load(_ url: String) throws {
        currentURL = url
        onEvent?(.urlChanged(url))
    }

    func close() {}
}

let launchURL = CommandLine.arguments.dropFirst().first { !$0.hasPrefix("--") }
let output = StandardProtocolOutput()
let coordinator = SessionCoordinator(
    browser: ControlledBrowserSession(),
    output: output
)

do {
    try coordinator.start(launchURL: launchURL)
    while let line = readLine() {
        if try coordinator.receiveLine(line) == .exit {
            break
        }
    }
} catch {
    output.write(.fatal(String(describing: error)))
    exit(1)
}
