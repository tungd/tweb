import Foundation
import XCTest
@testable import TwebCore

final class Issue11EndToEndSmokeWorkflowTests: XCTestCase {
    func testSmokeWorkflowCoversStartupTaskNavigationTraceAndArtifactCommand() throws {
        let browser = FakeBrowserSession()
        let output = RecordingProtocolOutput()
        let trace = TraceStore()
        let tempRoot = temporaryDirectory()
        let commandHandler = SlashCommandHandler(
            page: FakeInspectablePage(html: "<html><body>next</body></html>"),
            trace: trace,
            artifactWriter: LocalArtifactWriter(
                resolver: ArtifactPathResolver(tempDirectory: tempRoot)
            ),
            output: output
        )
        let coordinator = SessionCoordinator(
            browser: browser,
            output: output,
            slashCommandHandler: commandHandler,
            trace: trace,
            taskRunner: NavigatingTaskRunner(browser: browser, destination: "https://example.test/next"),
            engineReinstaller: FakeEngineReinstaller()
        )

        try coordinator.start(launchURL: "https://example.test/start")
        _ = try coordinator.receiveLine("Navigate to the next page and summarize it")
        _ = try coordinator.receiveLine("/trace")
        _ = try coordinator.receiveLine("/html page.html")

        XCTAssertTrue(output.renderedBlocks.contains { $0.contains("<ready>") })
        XCTAssertTrue(output.renderedBlocks.contains { $0.contains("<result>") && $0.contains("navigated summary") })
        XCTAssertTrue(output.renderedBlocks.contains { $0.contains("url: https://example.test/next") })
        XCTAssertTrue(output.renderedBlocks.contains { $0.contains("<trace>") })
        let artifactPath = tempRoot.appendingPathComponent("page.html")
        XCTAssertEqual(try String(contentsOf: artifactPath, encoding: .utf8), "<html><body>next</body></html>")
    }

    private func temporaryDirectory() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
