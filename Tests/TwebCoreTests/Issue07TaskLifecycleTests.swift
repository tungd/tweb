import XCTest
@testable import TwebCore

final class Issue07TaskLifecycleTests: XCTestCase {
    func testSecondPlainTextDuringRunningTaskBecomesQueuedSteering() throws {
        let runner = ManualTaskRunner()
        let coordinator = makeCoordinator(runner: runner)
        try coordinator.start(launchURL: "https://example.test")

        _ = try coordinator.receiveLine("Find the account page")
        _ = try coordinator.receiveLine("Prefer the personal account")

        XCTAssertEqual(runner.startedTasks.map(\.text), ["Find the account page"])
        XCTAssertEqual(runner.handle.steering, ["Prefer the personal account"])
        XCTAssertEqual(coordinator.debugState.lifecycleState, .running)
        XCTAssertEqual(coordinator.debugState.queuedSteering, ["Prefer the personal account"])
    }

    func testInterruptStopsCurrentTaskWithoutEndingSession() throws {
        let runner = ManualTaskRunner()
        let browser = FakeBrowserSession()
        let output = RecordingProtocolOutput()
        let coordinator = SessionCoordinator(browser: browser, output: output, taskRunner: runner)
        try coordinator.start(launchURL: nil)
        _ = try coordinator.receiveLine("Keep working")

        let outcome = try coordinator.receiveLine("/interrupt")

        XCTAssertEqual(outcome, .continueSession)
        XCTAssertTrue(runner.handle.interrupted)
        XCTAssertFalse(browser.closed)
        XCTAssertEqual(coordinator.debugState.lifecycleState, .idle)
        XCTAssertEqual(output.renderedBlocks.last, """
        <error>
        interrupted current Task Turn
        </error>

        """)
    }

    func testQuitInterruptsCurrentTaskAndEndsSession() throws {
        let runner = ManualTaskRunner()
        let browser = FakeBrowserSession()
        let output = RecordingProtocolOutput()
        let coordinator = SessionCoordinator(browser: browser, output: output, taskRunner: runner)
        try coordinator.start(launchURL: nil)
        _ = try coordinator.receiveLine("Keep working")

        let outcome = try coordinator.receiveLine("/quit")

        XCTAssertEqual(outcome, .exit)
        XCTAssertTrue(runner.handle.interrupted)
        XCTAssertTrue(browser.closed)
        XCTAssertEqual(coordinator.debugState.lifecycleState, .idle)
        XCTAssertEqual(coordinator.debugState.queuedSteering, [])
        XCTAssertEqual(coordinator.debugState.turnMemoryCount, 0)
    }

    func testNeedsInputPausesUntilParentProvidesSteering() throws {
        let runner = ManualTaskRunner()
        let output = RecordingProtocolOutput()
        let coordinator = makeCoordinator(runner: runner, output: output)
        try coordinator.start(launchURL: nil)
        _ = try coordinator.receiveLine("Log in")

        runner.emit(.needsInput("Which account should I use?"))

        XCTAssertEqual(coordinator.debugState.lifecycleState, .needsInput)
        XCTAssertEqual(output.renderedBlocks.last, """
        <needs-input>
        Which account should I use?
        </needs-input>

        """)

        _ = try coordinator.receiveLine("Use the personal account")

        XCTAssertEqual(runner.handle.steering, ["Use the personal account"])
        XCTAssertEqual(coordinator.debugState.lifecycleState, .running)
    }

    func testCompletedTurnResetsTurnMemoryAndAllowsFollowUpWithoutSemanticMemory() throws {
        let runner = ManualTaskRunner()
        let browser = FakeBrowserSession()
        let coordinator = SessionCoordinator(browser: browser, output: RecordingProtocolOutput(), taskRunner: runner)
        try coordinator.start(launchURL: "https://example.test/start")

        _ = try coordinator.receiveLine("First task")
        XCTAssertEqual(coordinator.debugState.turnMemoryCount, 1)

        runner.emit(.result(TaskTurnResult(text: "done", compactEvidence: [])))

        XCTAssertEqual(coordinator.debugState.lifecycleState, .idle)
        XCTAssertEqual(coordinator.debugState.turnMemoryCount, 0)
        XCTAssertTrue(coordinator.semanticSessionMemorySnapshot().isEmpty)
        XCTAssertEqual(browser.currentURL, "https://example.test/start")

        _ = try coordinator.receiveLine("Follow up")

        XCTAssertEqual(runner.startedTasks.map(\.text), ["First task", "Follow up"])
    }

    private func makeCoordinator(
        runner: ManualTaskRunner,
        output: RecordingProtocolOutput = RecordingProtocolOutput()
    ) -> SessionCoordinator {
        SessionCoordinator(
            browser: FakeBrowserSession(),
            output: output,
            taskRunner: runner
        )
    }
}
