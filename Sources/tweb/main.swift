import Foundation
import TwebCore

struct CLIArguments {
    let raw: [String]

    var isSetup: Bool {
        raw.contains("--setup")
    }

    var skipsModelRequirement: Bool {
        raw.contains("--no-model-required")
    }

    var launchURL: String? {
        var skipNext = false
        for argument in raw {
            if skipNext {
                skipNext = false
                continue
            }
            if ["--base-url", "--model", "--api-token"].contains(argument) {
                skipNext = true
                continue
            }
            if !argument.hasPrefix("--") {
                return argument
            }
        }
        return nil
    }

    func value(after option: String) -> String? {
        guard let index = raw.firstIndex(of: option) else { return nil }
        let valueIndex = raw.index(after: index)
        guard valueIndex < raw.endIndex else { return nil }
        return raw[valueIndex]
    }
}

func prompt(_ label: String) -> String {
    print("\(label): ", terminator: "")
    return readLine() ?? ""
}

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

let arguments = CLIArguments(raw: Array(CommandLine.arguments.dropFirst()))
let output = StandardProtocolOutput()

if arguments.isSetup {
    do {
        let baseURLString = arguments.value(after: "--base-url") ?? prompt("Base URL")
        let modelName = arguments.value(after: "--model") ?? prompt("Model")
        let apiToken = arguments.value(after: "--api-token") ?? prompt("API token")
        guard let baseURL = URL(string: baseURLString) else {
            output.write(.fatal("invalid model base URL"))
            exit(1)
        }
        try SetupMode(configurationStore: FileModelConfigurationStore()).save(
            baseURL: baseURL,
            modelName: modelName,
            apiToken: apiToken
        )
        output.write(.result("model configuration saved"))
        exit(0)
    } catch {
        output.write(.fatal(String(describing: error)))
        exit(1)
    }
}

if !arguments.skipsModelRequirement {
    do {
        let ready = try ModelConfigurationGate(
            configurationStore: FileModelConfigurationStore(),
            output: output
        ).ensureReadyForModelBackedSession()
        if !ready {
            exit(1)
        }
    } catch {
        output.write(.fatal(String(describing: error)))
        exit(1)
    }
}

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
    try coordinator.start(launchURL: arguments.launchURL)
    while let line = readLine() {
        if try coordinator.receiveLine(line) == .exit {
            break
        }
    }
} catch {
    output.write(.fatal(String(describing: error)))
    exit(1)
}
