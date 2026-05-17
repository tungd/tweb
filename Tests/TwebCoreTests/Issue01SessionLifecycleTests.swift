import XCTest
@testable import TwebCore

final class Issue01SessionLifecycleTests: XCTestCase {
    func testStartupWithoutLaunchURLStartsAboutBlankAndEmitsReady() throws {
        let browser = FakeBrowserSession()
        let output = RecordingProtocolOutput()
        let coordinator = SessionCoordinator(browser: browser, output: output)

        try coordinator.start(launchURL: nil)

        XCTAssertEqual(browser.loadedURLs, ["about:blank"])
        XCTAssertEqual(output.renderedBlocks.last, """
        <ready>
        url: about:blank
        </ready>

        """)
    }

    func testStartupWithLaunchURLNavigatesActivePageThere() throws {
        let browser = FakeBrowserSession()
        let output = RecordingProtocolOutput()
        let coordinator = SessionCoordinator(browser: browser, output: output)

        try coordinator.start(launchURL: "https://example.com/start")

        XCTAssertEqual(browser.loadedURLs, ["https://example.com/start"])
        XCTAssertTrue(output.renderedBlocks.contains("""
        <update>
        url: https://example.com/start
        </update>

        """))
    }

    func testStatusUpdatesRenderAsUpdateBlocks() throws {
        let browser = FakeBrowserSession()
        let output = RecordingProtocolOutput()
        let coordinator = SessionCoordinator(browser: browser, output: output)

        try coordinator.start(launchURL: nil)
        browser.emitStatus("loaded")

        XCTAssertTrue(output.renderedBlocks.contains("""
        <update>
        status: loaded
        </update>

        """))
    }

    func testQuitClosesTheBrowserSessionAndRequestsProcessExit() throws {
        let browser = FakeBrowserSession()
        let output = RecordingProtocolOutput()
        let coordinator = SessionCoordinator(browser: browser, output: output)

        try coordinator.start(launchURL: nil)
        let outcome = try coordinator.receiveLine("/quit")

        XCTAssertEqual(outcome, .exit)
        XCTAssertTrue(browser.closed)
    }
}
