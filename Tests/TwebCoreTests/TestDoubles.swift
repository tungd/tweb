import Foundation
@testable import TwebCore

final class RecordingProtocolOutput: ProtocolOutput {
    private let lock = NSLock()
    private var blocks: [String] = []

    var renderedBlocks: [String] {
        lock.lock()
        defer { lock.unlock() }
        return blocks
    }

    func write(_ block: ProtocolBlock) {
        lock.lock()
        blocks.append(TextProtocolRenderer.render(block))
        lock.unlock()
    }
}

final class FakeBrowserSession: BrowserSession {
    var onEvent: ((BrowserEvent) -> Void)?
    private(set) var loadedURLs: [String] = []
    private(set) var closed = false
    var startError: Error?
    var loadError: Error?

    var currentURL: String {
        loadedURLs.last ?? "about:blank"
    }

    func startHidden() throws {
        if let startError {
            throw startError
        }
        emitStatus("hidden session started")
    }

    func load(_ url: String) throws {
        if let loadError {
            throw loadError
        }
        loadedURLs.append(url)
        onEvent?(.urlChanged(url))
    }

    func close() {
        closed = true
    }

    func emitStatus(_ status: String) {
        onEvent?(.status(status))
    }

    static func loaded(_ url: String) -> FakeBrowserSession {
        let session = FakeBrowserSession()
        try? session.load(url)
        return session
    }
}

final class FakeInspectablePage: InspectablePage {
    var evaluationResults: [String: JSONValue] = [:]
    var evaluatedScripts: [String] = []
    var screenshotData = Data()
    var screenshotRequests: [ScreenshotCaptureMode] = []
    var html = ""

    convenience init(html: String) {
        self.init()
        self.html = html
    }

    init() {}

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

final class FakePageAgentScriptPage: PageAgentScriptPage {
    struct Call: Equatable {
        let source: String
        let arguments: [String: String]
    }

    private let lock = NSLock()
    var result: JSONValue = .null
    private var recordedCalls: [Call] = []

    var calls: [Call] {
        lock.lock()
        defer { lock.unlock() }
        return recordedCalls
    }

    func callAsyncJavaScript(_ source: String, arguments: [String: String]) throws -> JSONValue {
        lock.lock()
        recordedCalls.append(Call(source: source, arguments: arguments))
        lock.unlock()
        return result
    }
}

final class FakeHTTPClient: HTTPClient {
    private let lock = NSLock()
    var response: HTTPResponse
    private var recordedRequests: [HTTPRequest] = []

    var requests: [HTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests
    }

    init(response: HTTPResponse = HTTPResponse(statusCode: 200, body: Data(#"{"ok":true}"#.utf8))) {
        self.response = response
    }

    func send(_ request: HTTPRequest) throws -> HTTPResponse {
        lock.lock()
        recordedRequests.append(request)
        lock.unlock()
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
    private let lock = NSLock()
    private var recordedTasks: [String] = []

    var tasks: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recordedTasks
    }

    func runTask(_ request: InPageTaskRequest) throws -> TaskTurnResult {
        lock.lock()
        recordedTasks.append(request.text)
        lock.unlock()
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

final class BlockingInPageTaskEngine: InterruptibleInPageTaskEngine {
    private let startedSemaphore = DispatchSemaphore(value: 0)
    private let finishSemaphore = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var interruptedFlag = false
    var modelRequestsBeforeBlocking = 1

    var interrupted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return interruptedFlag
    }

    func runTask(_ request: InPageTaskRequest) throws -> TaskTurnResult {
        startedSemaphore.signal()
        for _ in 0..<modelRequestsBeforeBlocking {
            _ = try request.modelBridge.handle(ModelSchemeRequest(
                method: "POST",
                path: "/v1/chat/completions",
                body: Data(#"{"model":"test-model","messages":[]}"#.utf8)
            ))
        }
        _ = finishSemaphore.wait(timeout: .now() + 2)
        return TaskTurnResult(text: "unblocked", compactEvidence: [])
    }

    func interruptTask() {
        lock.lock()
        interruptedFlag = true
        lock.unlock()
        finishSemaphore.signal()
    }

    func waitUntilStarted(timeout: TimeInterval = 1) -> Bool {
        startedSemaphore.wait(timeout: .now() + timeout) == .success
    }

    func finish() {
        finishSemaphore.signal()
    }
}

@discardableResult
func waitUntil(timeout: TimeInterval = 1, _ condition: () -> Bool) -> Bool {
    let deadline = Date(timeIntervalSinceNow: timeout)
    while Date() < deadline {
        if condition() {
            return true
        }
        RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
    }
    return condition()
}

final class FakeManualProfileSession: ManualProfileSession {
    var openedProfiles: [PersistentProfile] = []
    var visibility: [SessionVisibility] = []

    func open(profile: PersistentProfile, visibility: SessionVisibility) throws {
        openedProfiles.append(profile)
        self.visibility.append(visibility)
    }
}

final class FakeHandoffController: HandoffController {
    var revealedURLs: [String] = []
    var visible = false
    var returnedControl = false

    func reveal(session: BrowserSession) throws -> HandoffWindowState {
        visible = true
        revealedURLs.append(session.currentURL)
        return HandoffWindowState(
            url: session.currentURL,
            containsLiveWebView: true,
            returnControlPlacement: .nativeWindowChrome
        )
    }

    func returnControl() throws {
        visible = false
        returnedControl = true
    }
}

final class NavigatingTaskRunner: BrowserSubagentTaskRunner {
    private let browser: BrowserSession
    private let destination: String

    init(browser: BrowserSession, destination: String) {
        self.browser = browser
        self.destination = destination
    }

    func startTask(_ request: TaskTurnRequest, events: TaskTurnEventSink) throws -> RunningTask {
        try browser.load(destination)
        events.handleTaskEvent(.result(TaskTurnResult(
            text: "navigated summary",
            compactEvidence: [
                CompactEvidence(source: destination, quote: "next")
            ]
        )))
        return CompletedRunningTask()
    }
}

final class FailingTaskRunner: BrowserSubagentTaskRunner {
    let error: Error

    init(error: Error) {
        self.error = error
    }

    func startTask(_ request: TaskTurnRequest, events: TaskTurnEventSink) throws -> RunningTask {
        throw error
    }
}
