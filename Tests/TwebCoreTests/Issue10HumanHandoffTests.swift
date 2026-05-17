import XCTest
@testable import TwebCore

final class Issue10HumanHandoffTests: XCTestCase {
    func testHumanCommandRevealsSameLiveBrowserState() throws {
        let browser = FakeBrowserSession()
        let handoff = FakeHandoffController()
        let output = RecordingProtocolOutput()
        let coordinator = SessionCoordinator(
            browser: browser,
            output: output,
            handoffController: handoff
        )
        try coordinator.start(launchURL: "https://example.test/login")

        _ = try coordinator.receiveLine("/human")

        XCTAssertEqual(handoff.revealedURLs, ["https://example.test/login"])
        XCTAssertEqual(output.renderedBlocks.last, """
        <update>
        human handoff visible: https://example.test/login
        </update>

        """)
    }

    func testHandoffWindowUsesLiveWebViewAndNativeReturnControl() throws {
        let handoff = FakeHandoffController()

        let window = try handoff.reveal(session: FakeBrowserSession.loaded("https://example.test"))

        XCTAssertTrue(window.containsLiveWebView)
        XCTAssertEqual(window.returnControlPlacement, .nativeWindowChrome)
    }

    func testReturnControlHidesWindowAndReturnsToAgentControl() throws {
        let handoff = FakeHandoffController()
        _ = try handoff.reveal(session: FakeBrowserSession.loaded("https://example.test"))

        try handoff.returnControl()

        XCTAssertFalse(handoff.visible)
        XCTAssertTrue(handoff.returnedControl)
    }

    func testBrowserSubagentCannotOpenHumanHandoffByItself() throws {
        let runner = ManualTaskRunner()
        let handoff = FakeHandoffController()
        let output = RecordingProtocolOutput()
        let coordinator = SessionCoordinator(
            browser: FakeBrowserSession(),
            output: output,
            taskRunner: runner,
            handoffController: handoff
        )
        try coordinator.start(launchURL: nil)
        _ = try coordinator.receiveLine("Handle the CAPTCHA")

        runner.emit(.requestedHumanHandoff("CAPTCHA is blocking progress"))

        XCTAssertTrue(handoff.revealedURLs.isEmpty)
        XCTAssertEqual(output.renderedBlocks.last, """
        <needs-input>
        Browser Subagent requested Human Handoff: CAPTCHA is blocking progress. Parent Agent must invoke /human.
        </needs-input>

        """)
    }
}
