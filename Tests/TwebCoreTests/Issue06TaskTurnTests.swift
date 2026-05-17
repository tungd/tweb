import Foundation
import XCTest
@testable import TwebCore

final class Issue06TaskTurnTests: XCTestCase {
    func testPlainTextInputStartsTaskTurnAndReturnsResultBlock() throws {
        let browser = FakeBrowserSession()
        let output = RecordingProtocolOutput()
        let runner = ImmediateTaskRunner(result: TaskTurnResult(
            text: "The page says hello.",
            compactEvidence: [
                CompactEvidence(source: "https://example.test", quote: "Hello")
            ]
        ))
        let coordinator = SessionCoordinator(
            browser: browser,
            output: output,
            taskRunner: runner
        )
        try coordinator.start(launchURL: "https://example.test")

        _ = try coordinator.receiveLine("Summarize the page")

        XCTAssertEqual(runner.startedTasks.map(\.text), ["Summarize the page"])
        XCTAssertEqual(output.renderedBlocks.last, """
        <result>
        The page says hello.
        compact-evidence:
        - source: https://example.test
          quote: Hello
        </result>

        """)
    }

    func testPageAgentTaskRunnerRoutesModelCallsThroughSessionModelBridge() throws {
        let responseBody = Data(#"{"choices":[{"message":{"content":"done"}}]}"#.utf8)
        let http = FakeHTTPClient(response: HTTPResponse(statusCode: 200, body: responseBody))
        let modelBridge = SessionModelBridge(
            configurationStore: InMemoryModelConfigurationStore(configuration: ModelConfiguration(
                baseURL: URL(string: "https://llm.example.test")!,
                modelName: "test-model",
                apiToken: "sk-test"
            )),
            httpClient: http
        )
        let engine = FakeInPageTaskEngine()
        let runner = PageAgentTaskRunner(
            engine: engine,
            modelBridge: modelBridge,
            progressInterval: 0
        )
        let output = RecordingProtocolOutput()
        let coordinator = SessionCoordinator(
            browser: FakeBrowserSession(),
            output: output,
            taskRunner: runner
        )
        try coordinator.start(launchURL: "https://example.test")

        _ = try coordinator.receiveLine("Answer with the page title")

        XCTAssertTrue(waitUntil { output.renderedBlocks.last?.contains("<result>") ?? false })
        XCTAssertEqual(engine.tasks, ["Answer with the page title"])
        XCTAssertEqual(http.requests.count, 1)
        XCTAssertEqual(http.requests.first?.url.absoluteString, "https://llm.example.test/v1/chat/completions")
        XCTAssertTrue(output.renderedBlocks.last?.contains("<result>") ?? false)
        XCTAssertTrue(output.renderedBlocks.last?.contains("compact-evidence:") ?? false)
    }

    func testPageAgentJavaScriptTaskEngineReturnsInPageEngineResult() throws {
        let page = FakePageAgentScriptPage()
        page.result = .object([
            "text": .string("real page-agent answer"),
            "compactEvidence": .array([
                .object([
                    "source": .string("https://example.test/result"),
                    "quote": .string("evidence from the active page")
                ])
            ])
        ])
        let bridge = SessionModelBridge(
            configurationStore: InMemoryModelConfigurationStore(configuration: ModelConfiguration(
                baseURL: URL(string: "https://llm.example.test")!,
                modelName: "test-model",
                apiToken: "sk-test"
            )),
            httpClient: FakeHTTPClient()
        )
        let engine = PageAgentJavaScriptTaskEngine(page: page)

        let result = try engine.runTask(InPageTaskRequest(
            text: "Find free models",
            currentURL: "https://example.test/start",
            modelBridge: bridge
        ))

        XCTAssertEqual(result, TaskTurnResult(
            text: "real page-agent answer",
            compactEvidence: [
                CompactEvidence(
                    source: "https://example.test/result",
                    quote: "evidence from the active page"
                )
            ]
        ))
        XCTAssertEqual(page.calls.map(\.arguments["task"]), ["Find free models"])
        XCTAssertEqual(page.calls.map(\.arguments["currentURL"]), ["https://example.test/start"])
        XCTAssertTrue(page.calls.first?.source.contains("__twebPageAgent.runTwebTask") ?? false)
    }

    func testPageAgentTaskRunnerEmitsPeriodicModelTurnUpdates() throws {
        let http = FakeHTTPClient()
        let modelBridge = SessionModelBridge(
            configurationStore: InMemoryModelConfigurationStore(configuration: ModelConfiguration(
                baseURL: URL(string: "https://llm.example.test")!,
                modelName: "test-model",
                apiToken: "sk-test"
            )),
            httpClient: http
        )
        let engine = BlockingInPageTaskEngine()
        let runner = PageAgentTaskRunner(
            engine: engine,
            modelBridge: modelBridge,
            progressInterval: 0.01
        )
        let output = RecordingProtocolOutput()
        let coordinator = SessionCoordinator(
            browser: FakeBrowserSession(),
            output: output,
            taskRunner: runner
        )
        try coordinator.start(launchURL: "https://example.test")

        _ = try coordinator.receiveLine("Long PageAgent task")

        XCTAssertTrue(engine.waitUntilStarted())
        XCTAssertTrue(waitUntil {
            output.renderedBlocks.contains {
                $0.contains("PageAgent task running: 1 model turns")
            }
        })

        engine.finish()
        XCTAssertTrue(waitUntil {
            output.renderedBlocks.last?.contains("<result>") ?? false
        })
    }

    func testPageAgentJavaScriptTaskEngineCanInterruptInPageTask() {
        let page = FakePageAgentScriptPage()
        let engine = PageAgentJavaScriptTaskEngine(page: page)

        engine.interruptTask()

        XCTAssertTrue(page.calls.last?.source.contains("stopTwebTask") ?? false)
    }

    func testBrowserStateRemainsIntactAfterCompletedTaskTurn() throws {
        let browser = FakeBrowserSession()
        let output = RecordingProtocolOutput()
        let coordinator = SessionCoordinator(
            browser: browser,
            output: output,
            taskRunner: ImmediateTaskRunner(result: TaskTurnResult(
                text: "done",
                compactEvidence: []
            ))
        )
        try coordinator.start(launchURL: "https://example.test/start")

        _ = try coordinator.receiveLine("Do a page-local task")

        XCTAssertEqual(browser.currentURL, "https://example.test/start")
    }
}
