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

extension ControlledBrowserSession: InspectablePage {
    func evaluateJavaScript(_ source: String) throws -> JSONValue {
        switch source.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "location.href":
            return .string(currentURL)
        case "document.title":
            return .string("tweb controlled page")
        default:
            return .string("evaluated: \(source)")
        }
    }

    func captureScreenshot(mode: ScreenshotCaptureMode) throws -> Data {
        Data("controlled full-page screenshot for \(currentURL)\n".utf8)
    }

    func currentHTML() throws -> String {
        """
        <!doctype html>
        <html>
        <head><title>tweb controlled page</title></head>
        <body data-url="\(currentURL)">controlled page</body>
        </html>
        """
    }
}

let launchURL = CommandLine.arguments.dropFirst().first { !$0.hasPrefix("--") }
let output = StandardProtocolOutput()
let browser = ControlledBrowserSession()
let trace = TraceStore()
let commandHandler = SlashCommandHandler(
    page: browser,
    trace: trace,
    artifactWriter: LocalArtifactWriter(),
    output: output
)
let coordinator = SessionCoordinator(
    browser: browser,
    output: output,
    slashCommandHandler: commandHandler,
    trace: trace
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
