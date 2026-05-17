import XCTest
@testable import TwebCore

final class Issue08NavigationContinuationTests: XCTestCase {
    func testTopLevelNavigationEmitsURLUpdateAndTriggersEngineReinstall() throws {
        let browser = FakeBrowserSession()
        let output = RecordingProtocolOutput()
        let reinstaller = FakeEngineReinstaller()
        let coordinator = SessionCoordinator(
            browser: browser,
            output: output,
            engineReinstaller: reinstaller
        )
        try coordinator.start(launchURL: "https://example.test/start")
        reinstaller.reinstalledURLs.removeAll()

        try browser.load("https://example.test/next")

        XCTAssertTrue(output.renderedBlocks.contains("""
        <update>
        url: https://example.test/next
        </update>

        """))
        XCTAssertEqual(reinstaller.reinstalledURLs, ["https://example.test/next"])
    }

    func testRunningTaskCanContinueAfterNavigationReinstall() throws {
        let browser = FakeBrowserSession()
        let runner = ManualTaskRunner()
        let output = RecordingProtocolOutput()
        let coordinator = SessionCoordinator(
            browser: browser,
            output: output,
            taskRunner: runner,
            engineReinstaller: FakeEngineReinstaller()
        )
        try coordinator.start(launchURL: "https://example.test/start")
        _ = try coordinator.receiveLine("Follow the link and summarize")

        try browser.load("https://example.test/next")
        runner.emit(.result(TaskTurnResult(
            text: "continued after navigation",
            compactEvidence: [CompactEvidence(source: browser.currentURL, quote: "next page")]
        )))

        XCTAssertEqual(coordinator.debugState.lifecycleState, .idle)
        XCTAssertTrue(output.renderedBlocks.last?.contains("continued after navigation") ?? false)
        XCTAssertTrue(output.renderedBlocks.last?.contains("https://example.test/next") ?? false)
    }

    func testCoordinatorDoesNotUseNetworkIdleHeuristicsForPageReadiness() throws {
        let coordinator = SessionCoordinator(
            browser: FakeBrowserSession(),
            output: RecordingProtocolOutput(),
            engineReinstaller: FakeEngineReinstaller()
        )

        XCTAssertFalse(coordinator.usesNetworkIdleHeuristics)
    }

    func testEngineReinstallFailureIsRecoverableError() throws {
        let browser = FakeBrowserSession()
        let output = RecordingProtocolOutput()
        let reinstaller = FakeEngineReinstaller()
        reinstaller.error = EngineInstallationError.readinessProbeFailed
        let coordinator = SessionCoordinator(
            browser: browser,
            output: output,
            engineReinstaller: reinstaller
        )
        try coordinator.start(launchURL: nil)

        try browser.load("https://example.test/broken")

        XCTAssertEqual(output.renderedBlocks.last, """
        <error>
        engine reinstall failed: in-page engine readiness probe failed
        </error>

        """)
        XCTAssertEqual(coordinator.debugState.lifecycleState, .idle)
    }
}
