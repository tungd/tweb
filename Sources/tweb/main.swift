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

    var isControlled: Bool {
        raw.contains("--controlled")
    }

    var requiresModelConfiguration: Bool {
        !isControlled && !isManual
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

extension ControlledBrowserSession: PageAgentScriptPage {
    func callAsyncJavaScript(_ source: String, arguments: [String: String]) throws -> JSONValue {
        .object([
            "text": .string("controlled PageAgent executed: \(arguments["task"] ?? "")"),
            "compactEvidence": .array([
                .object([
                    "source": .string(currentURL),
                    "quote": .string("controlled PageAgent task runner")
                ])
            ])
        ])
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

final class StandardInputSessionDriver: @unchecked Sendable {
    private let coordinator: SessionCoordinator
    private let output: ProtocolOutput
    private let pollInterval: TimeInterval
    private let lock = NSLock()
    private var inputClosed = false
    private var exitRequested = false
    private var exitCode = 0

    init(
        coordinator: SessionCoordinator,
        output: ProtocolOutput,
        pollInterval: TimeInterval = 0.02
    ) {
        self.coordinator = coordinator
        self.output = output
        self.pollInterval = pollInterval
    }

    func run() -> Int {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            while let line = readLine() {
                guard let self, !self.isExitRequested else { break }
                DispatchQueue.main.async { [weak self] in
                    self?.receive(line)
                }
            }
            DispatchQueue.main.async { [weak self] in
                self?.inputDidClose()
            }
        }

        while !isExitRequested {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: pollInterval))
            if shouldExitAfterInputClosed {
                requestExit(code: 0)
            }
        }
        return currentExitCode
    }

    private func receive(_ line: String) {
        guard !isExitRequested else { return }

        do {
            if try coordinator.receiveLine(line) == .exit {
                requestExit(code: 0)
            }
        } catch {
            output.write(.fatal(String(describing: error)))
            requestExit(code: 1)
        }
    }

    private func inputDidClose() {
        lock.lock()
        inputClosed = true
        lock.unlock()
    }

    private var shouldExitAfterInputClosed: Bool {
        lock.lock()
        let closed = inputClosed
        lock.unlock()
        guard closed else { return false }
        return coordinator.debugState.lifecycleState != .running
    }

    private var isExitRequested: Bool {
        lock.lock()
        defer { lock.unlock() }
        return exitRequested
    }

    private var currentExitCode: Int {
        lock.lock()
        defer { lock.unlock() }
        return exitCode
    }

    private func requestExit(code: Int) {
        lock.lock()
        if !exitRequested {
            exitCode = code
            exitRequested = true
        }
        lock.unlock()
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

let configuredModel: ModelConfiguration?
let fileModelConfigurationStore = FileModelConfigurationStore()
if arguments.requiresModelConfiguration {
    do {
        guard let configuration = try fileModelConfigurationStore.load() else {
            let missing = try fileModelConfigurationStore.missingRequirements().joined(separator: ", ")
            output.write(.fatal("missing model configuration: \(missing)"))
            exit(1)
        }
        configuredModel = configuration
    } catch {
        output.write(.fatal(String(describing: error)))
        exit(1)
    }
} else {
    configuredModel = nil
}

let trace = TraceStore()
let selectedStorage: SessionStorage
do {
    selectedStorage = try ProfileSelector(registry: profileRegistry)
        .storage(forProfileName: arguments.profileName)
    switch selectedStorage {
    case .ephemeral:
        output.write(.update("session-state: ephemeral"))
    case .persistent(let profile):
        output.write(.update("profile: \(profile.name) \(profile.storeUUID.uuidString)"))
    }
} catch {
    output.write(.fatal(String(describing: error)))
    exit(1)
}

let browser: BrowserSession & InspectablePage & ScriptInjectingPage & PageAgentScriptPage
let webKitModelBridge: SessionModelBridge?
if arguments.isControlled {
    browser = ControlledBrowserSession()
    webKitModelBridge = nil
} else {
    webKitModelBridge = configuredModel.map {
        SessionModelBridge(
            configurationStore: InMemoryModelConfigurationStore(configuration: $0),
            httpClient: URLSessionHTTPClient()
        )
    }
    browser = WebKitBrowserSession(storage: selectedStorage, modelBridge: webKitModelBridge)
}
let commandHandler = SlashCommandHandler(
    page: browser,
    trace: trace,
    artifactWriter: LocalArtifactWriter(),
    output: output
)
let engineReinstaller: EngineReinstaller?
if arguments.isControlled {
    engineReinstaller = nil
} else {
    engineReinstaller = try? MainFrameEngineReinstaller(
        page: browser,
        bundle: PageAgentBundle.pinnedCDNLoader()
    )
}
let taskRunner: BrowserSubagentTaskRunner
if arguments.isControlled {
    taskRunner = ControlledEchoTaskRunner(browser: browser)
} else {
    guard let webKitModelBridge else {
        output.write(.fatal("missing model configuration"))
        exit(1)
    }
    taskRunner = PageAgentTaskRunner(
        engine: PageAgentJavaScriptTaskEngine(page: browser),
        modelBridge: webKitModelBridge
    )
}
let coordinator = SessionCoordinator(
    browser: browser,
    output: output,
    slashCommandHandler: commandHandler,
    trace: trace,
    taskRunner: taskRunner,
    engineReinstaller: engineReinstaller,
    handoffController: arguments.isControlled ? ControlledHandoffController() : WebKitHandoffController()
)

do {
    try coordinator.start(launchURL: arguments.launchURL)
    let driver = StandardInputSessionDriver(
        coordinator: coordinator,
        output: output
    )
    let exitCode = driver.run()
    if exitCode != 0 {
        exit(Int32(exitCode))
    }
} catch {
    output.write(.fatal(String(describing: error)))
    exit(1)
}
