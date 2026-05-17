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
        let runner = PageAgentTaskRunner(engine: engine, modelBridge: modelBridge)
        let output = RecordingProtocolOutput()
        let coordinator = SessionCoordinator(
            browser: FakeBrowserSession(),
            output: output,
            taskRunner: runner
        )
        try coordinator.start(launchURL: "https://example.test")

        _ = try coordinator.receiveLine("Answer with the page title")

        XCTAssertEqual(engine.tasks, ["Answer with the page title"])
        XCTAssertEqual(http.requests.count, 1)
        XCTAssertEqual(http.requests.first?.url.absoluteString, "https://llm.example.test/v1/chat/completions")
        XCTAssertTrue(output.renderedBlocks.last?.contains("<result>") ?? false)
        XCTAssertTrue(output.renderedBlocks.last?.contains("compact-evidence:") ?? false)
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
