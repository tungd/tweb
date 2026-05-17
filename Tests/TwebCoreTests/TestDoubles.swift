import Foundation
@testable import TwebCore

final class RecordingProtocolOutput: ProtocolOutput {
    private(set) var renderedBlocks: [String] = []

    func write(_ block: ProtocolBlock) {
        renderedBlocks.append(TextProtocolRenderer.render(block))
    }
}

final class FakeBrowserSession: BrowserSession {
    var onEvent: ((BrowserEvent) -> Void)?
    private(set) var loadedURLs: [String] = []
    private(set) var closed = false

    var currentURL: String {
        loadedURLs.last ?? "about:blank"
    }

    func startHidden() throws {
        emitStatus("hidden session started")
    }

    func load(_ url: String) throws {
        loadedURLs.append(url)
        onEvent?(.urlChanged(url))
    }

    func close() {
        closed = true
    }

    func emitStatus(_ status: String) {
        onEvent?(.status(status))
    }
}

final class FakeInspectablePage: InspectablePage {
    var evaluationResults: [String: JSONValue] = [:]
    var evaluatedScripts: [String] = []
    var screenshotData = Data()
    var screenshotRequests: [ScreenshotCaptureMode] = []
    var html = ""

    func evaluateJavaScript(_ source: String) throws -> JSONValue {
        evaluatedScripts.append(source)
        return evaluationResults[source] ?? .null
    }

    func captureScreenshot(mode: ScreenshotCaptureMode) throws -> Data {
        screenshotRequests.append(mode)
        return screenshotData
    }

    func currentHTML() throws -> String {
        html
    }
}

final class FakeSecretStore: SecretStore {
    var tokens: [String: String] = [:]

    func saveSecret(_ value: String, forKey key: String) throws {
        tokens[key] = value
    }

    func readSecret(forKey key: String) throws -> String? {
        tokens[key]
    }
}

final class FakeHTTPClient: HTTPClient {
    var response: HTTPResponse
    private(set) var requests: [HTTPRequest] = []

    init(response: HTTPResponse = HTTPResponse(statusCode: 200, body: Data(#"{"ok":true}"#.utf8))) {
        self.response = response
    }

    func send(_ request: HTTPRequest) throws -> HTTPResponse {
        requests.append(request)
        return response
    }
}

final class FakeScriptInjectingPage: ScriptInjectingPage {
    var injections: [ScriptInjection] = []
    var readinessProbes: [String] = []
    var readinessResult = true

    func inject(script: String, into frame: FrameTarget) throws {
        injections.append(ScriptInjection(script: script, frame: frame))
    }

    func evaluateReadinessProbe(_ source: String) throws -> Bool {
        readinessProbes.append(source)
        return readinessResult
    }
}

final class ImmediateTaskRunner: BrowserSubagentTaskRunner {
    var result: TaskTurnResult
    private(set) var startedTasks: [TaskTurnRequest] = []

    init(result: TaskTurnResult) {
        self.result = result
    }

    func startTask(_ request: TaskTurnRequest, events: TaskTurnEventSink) throws -> RunningTask {
        startedTasks.append(request)
        events.handleTaskEvent(.result(result))
        return CompletedRunningTask()
    }
}

final class FakeInPageTaskEngine: InPageTaskEngine {
    private(set) var tasks: [String] = []

    func runTask(_ request: InPageTaskRequest) throws -> TaskTurnResult {
        tasks.append(request.text)
        _ = try request.modelBridge.handle(ModelSchemeRequest(
            method: "POST",
            path: "/v1/chat/completions",
            body: Data(#"{"model":"test-model","messages":[]}"#.utf8)
        ))
        return TaskTurnResult(
            text: "done",
            compactEvidence: [
                CompactEvidence(source: request.currentURL, quote: "model-backed page task completed")
            ]
        )
    }
}

final class ManualTaskRunner: BrowserSubagentTaskRunner {
    private(set) var startedTasks: [TaskTurnRequest] = []
    let handle = RecordingRunningTask()
    private weak var events: TaskTurnEventSink?

    func startTask(_ request: TaskTurnRequest, events: TaskTurnEventSink) throws -> RunningTask {
        startedTasks.append(request)
        self.events = events
        return handle
    }

    func emit(_ event: TaskTurnEvent) {
        events?.handleTaskEvent(event)
    }
}

final class RecordingRunningTask: RunningTask {
    private(set) var steering: [String] = []
    private(set) var interrupted = false

    func provideSteering(_ text: String) {
        steering.append(text)
    }

    func interrupt() {
        interrupted = true
    }
}

final class FakeEngineReinstaller: EngineReinstaller {
    var reinstalledURLs: [String] = []
    var error: Error?

    func reinstall(afterTopLevelNavigationTo url: String) throws {
        reinstalledURLs.append(url)
        if let error {
            throw error
        }
    }
}

final class FakeManualProfileSession: ManualProfileSession {
    var openedProfiles: [PersistentProfile] = []
    var visibility: [SessionVisibility] = []

    func open(profile: PersistentProfile, visibility: SessionVisibility) throws {
        openedProfiles.append(profile)
        self.visibility.append(visibility)
    }
}
