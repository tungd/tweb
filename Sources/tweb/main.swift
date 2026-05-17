import Foundation
import TwebCore

struct CLIArguments {
    let raw: [String]

    var isSetup: Bool {
        raw.contains("--setup")
    }

    var isManual: Bool {
        raw.contains("--manual")
    }

    var skipsModelRequirement: Bool {
        raw.contains("--no-model-required") || isManual
    }

    var profileName: String? {
        value(after: "--profile")
    }

    var launchURL: String? {
        var skipNext = false
        for argument in raw {
            if skipNext {
                skipNext = false
                continue
            }
            if ["--base-url", "--model", "--api-token", "--profile"].contains(argument) {
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

extension ControlledBrowserSession: ScriptInjectingPage {
    func inject(script: String, into frame: FrameTarget) throws {
        onEvent?(.status("installed in-page engine in main frame"))
    }

    func evaluateReadinessProbe(_ source: String) throws -> Bool {
        source == "window.__twebPageAgentReady === true"
    }
}

final class ControlledEchoTaskRunner: BrowserSubagentTaskRunner {
    private let browser: BrowserSession

    init(browser: BrowserSession) {
        self.browser = browser
    }

    func startTask(_ request: TaskTurnRequest, events: TaskTurnEventSink) throws -> RunningTask {
        if let destination = firstHTTPURL(in: request.text) {
            try browser.load(destination)
        }
        let source = browser.currentURL
        events.handleTaskEvent(.result(TaskTurnResult(
            text: "completed: \(request.text)",
            compactEvidence: [
                CompactEvidence(source: source, quote: "controlled task runner")
            ]
        )))
        return CompletedRunningTask()
    }

    private func firstHTTPURL(in text: String) -> String? {
        text
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .first { $0.hasPrefix("http://") || $0.hasPrefix("https://") }?
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,)"))
    }
}

final class ControlledInPageTaskEngine: InPageTaskEngine {
    func runTask(_ request: InPageTaskRequest) throws -> TaskTurnResult {
        let body = Data("""
        {"model":"configured","messages":[{"role":"user","content":\(JSONValue.string(request.text).rendered)}]}
        """.utf8)
        _ = try request.modelBridge.handle(ModelSchemeRequest(
            method: "POST",
            path: SessionModelBridge.chatCompletionsPath,
            body: body
        ))
        return TaskTurnResult(
            text: "completed: \(request.text)",
            compactEvidence: [
                CompactEvidence(source: request.currentURL, quote: "model-backed PageAgent task completed")
            ]
        )
    }
}

final class ControlledManualProfileSession: ManualProfileSession {
    private let output: ProtocolOutput

    init(output: ProtocolOutput) {
        self.output = output
    }

    func open(profile: PersistentProfile, visibility: SessionVisibility) throws {
        output.write(.ready(url: "profile:\(profile.name)"))
        output.write(.result("manual profile session visible: \(profile.name) \(profile.storeUUID.uuidString)"))
    }
}

final class ControlledHandoffController: HandoffController {
    func reveal(session: BrowserSession) throws -> HandoffWindowState {
        HandoffWindowState(
            url: session.currentURL,
            containsLiveWebView: true,
            returnControlPlacement: .nativeWindowChrome
        )
    }

    func returnControl() throws {}
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

let profileRegistry = ProfileRegistry()

if arguments.isManual {
    do {
        try ManualMode(
            registry: profileRegistry,
            session: ControlledManualProfileSession(output: output)
        ).run(profileName: arguments.profileName)
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

do {
    let storage = try ProfileSelector(registry: profileRegistry)
        .storage(forProfileName: arguments.profileName)
    switch storage {
    case .ephemeral:
        output.write(.update("session-state: ephemeral"))
    case .persistent(let profile):
        output.write(.update("profile: \(profile.name) \(profile.storeUUID.uuidString)"))
    }
} catch {
    output.write(.fatal(String(describing: error)))
    exit(1)
}

let browser = ControlledBrowserSession()
let trace = TraceStore()
let commandHandler = SlashCommandHandler(
    page: browser,
    trace: trace,
    artifactWriter: LocalArtifactWriter(),
    output: output
)
let engineReinstaller = try? MainFrameEngineReinstaller(
    page: browser,
    bundle: PageAgentBundle.vendored()
)
let taskRunner: BrowserSubagentTaskRunner
if arguments.skipsModelRequirement {
    taskRunner = ControlledEchoTaskRunner(browser: browser)
} else {
    let configurationStore = FileModelConfigurationStore()
    taskRunner = PageAgentTaskRunner(
        engine: ControlledInPageTaskEngine(),
        modelBridge: SessionModelBridge(
            configurationStore: configurationStore,
            httpClient: URLSessionHTTPClient()
        )
    )
}
let coordinator = SessionCoordinator(
    browser: browser,
    output: output,
    slashCommandHandler: commandHandler,
    trace: trace,
    taskRunner: taskRunner,
    engineReinstaller: engineReinstaller,
    handoffController: ControlledHandoffController()
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
