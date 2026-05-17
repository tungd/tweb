import XCTest
@testable import TwebCore

final class Issue12ErrorPathTests: XCTestCase {
    func testMalformedSlashCommandProducesRecoverableError() throws {
        let output = RecordingProtocolOutput()
        let coordinator = SessionCoordinator(browser: FakeBrowserSession(), output: output)
        try coordinator.start(launchURL: nil)

        let outcome = try coordinator.receiveLine("/eval")

        XCTAssertEqual(outcome, .continueSession)
        XCTAssertEqual(output.renderedBlocks.last, """
        <error>
        /eval requires an argument
        </error>

        """)
    }

    func testTaskRunnerModelFailureSurfacesAsRecoverableError() throws {
        let output = RecordingProtocolOutput()
        let coordinator = SessionCoordinator(
            browser: FakeBrowserSession(),
            output: output,
            taskRunner: FailingTaskRunner(error: ModelBridgeError.missingConfiguration)
        )
        try coordinator.start(launchURL: nil)

        let outcome = try coordinator.receiveLine("Use the model")

        XCTAssertEqual(outcome, .continueSession)
        XCTAssertEqual(coordinator.debugState.lifecycleState, .idle)
        XCTAssertEqual(output.renderedBlocks.last, """
        <error>
        task failed: missing model configuration
        </error>

        """)
    }

    func testSessionStartupFailureEmitsFatalAndThrows() {
        let browser = FakeBrowserSession()
        browser.startError = SessionRuntimeError.unusable("WebKit process crashed")
        let output = RecordingProtocolOutput()
        let coordinator = SessionCoordinator(browser: browser, output: output)

        XCTAssertThrowsError(try coordinator.start(launchURL: nil))
        XCTAssertEqual(output.renderedBlocks.last, """
        <fatal>
        session startup failed: unusable session: WebKit process crashed
        </fatal>

        """)
    }

    func testInterruptedTurnProducesClearNonFatalOutcome() throws {
        let runner = ManualTaskRunner()
        let output = RecordingProtocolOutput()
        let coordinator = SessionCoordinator(
            browser: FakeBrowserSession(),
            output: output,
            taskRunner: runner
        )
        try coordinator.start(launchURL: nil)
        _ = try coordinator.receiveLine("Keep working")

        _ = try coordinator.receiveLine("/interrupt")

        XCTAssertEqual(coordinator.debugState.lifecycleState, .idle)
        XCTAssertTrue(output.renderedBlocks.last?.contains("<error>") ?? false)
        XCTAssertTrue(output.renderedBlocks.last?.contains("interrupted current Task Turn") ?? false)
    }
}
