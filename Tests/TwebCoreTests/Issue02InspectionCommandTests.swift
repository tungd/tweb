import Foundation
import XCTest
@testable import TwebCore

final class Issue02InspectionCommandTests: XCTestCase {
    func testSlashCommandParsingRecognizesInspectionCommands() throws {
        XCTAssertEqual(try SlashCommand.parse("/trace"), .trace)
        XCTAssertEqual(try SlashCommand.parse("/eval document.title"), .eval("document.title"))
        XCTAssertEqual(try SlashCommand.parse("/screenshot shot.png"), .screenshot("shot.png"))
        XCTAssertEqual(try SlashCommand.parse("/html /tmp/page.html"), .html("/tmp/page.html"))
        XCTAssertEqual(try SlashCommand.parse("/quit"), .quit)
    }

    func testRelativeArtifactPathsResolveUnderTemporaryDirectory() throws {
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let resolver = ArtifactPathResolver(tempDirectory: tempRoot)

        let resolved = try resolver.resolve("shot.png")

        XCTAssertEqual(resolved, tempRoot.appendingPathComponent("shot.png"))
        XCTAssertFalse(resolved.path.hasPrefix(FileManager.default.currentDirectoryPath))
    }

    func testAbsoluteArtifactPathsArePreserved() throws {
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let resolver = ArtifactPathResolver(tempDirectory: tempRoot)
        let absolute = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("explicit.html")

        XCTAssertEqual(try resolver.resolve(absolute.path), absolute)
    }

    func testTraceCommandRendersInlineTraceJSON() throws {
        let page = FakeInspectablePage()
        let trace = TraceStore()
        trace.record(type: "update", message: "ready")
        let output = RecordingProtocolOutput()
        let handler = SlashCommandHandler(
            page: page,
            trace: trace,
            artifactWriter: LocalArtifactWriter(
                resolver: ArtifactPathResolver(tempDirectory: temporaryDirectory())
            ),
            output: output
        )

        try handler.handle(.trace)

        XCTAssertEqual(output.renderedBlocks.last, """
        <trace>
        {"events":[{"message":"ready","type":"update"}]}
        </trace>

        """)
    }

    func testEvalCommandEvaluatesAgainstActivePageAndRendersInlineResult() throws {
        let page = FakeInspectablePage()
        page.evaluationResults["document.title"] = .string("Example")
        let output = RecordingProtocolOutput()
        let handler = makeHandler(page: page, output: output)

        try handler.handle(.eval("document.title"))

        XCTAssertEqual(page.evaluatedScripts, ["document.title"])
        XCTAssertEqual(output.renderedBlocks.last, """
        <result>
        eval: "Example"
        </result>

        """)
    }

    func testScreenshotCommandWritesFullPageArtifactAndReportsPath() throws {
        let page = FakeInspectablePage()
        page.screenshotData = Data("PNG".utf8)
        let output = RecordingProtocolOutput()
        let tempRoot = temporaryDirectory()
        let handler = makeHandler(page: page, output: output, tempDirectory: tempRoot)

        try handler.handle(.screenshot("shot.png"))

        let expectedPath = tempRoot.appendingPathComponent("shot.png")
        XCTAssertEqual(page.screenshotRequests, [.fullPage])
        XCTAssertEqual(try Data(contentsOf: expectedPath), Data("PNG".utf8))
        XCTAssertEqual(output.renderedBlocks.last, """
        <result>
        artifact: \(expectedPath.path)
        </result>

        """)
    }

    func testHTMLCommandWritesRawCurrentHTMLArtifactAndReportsPath() throws {
        let page = FakeInspectablePage()
        page.html = "<html><body>ok</body></html>"
        let output = RecordingProtocolOutput()
        let tempRoot = temporaryDirectory()
        let handler = makeHandler(page: page, output: output, tempDirectory: tempRoot)

        try handler.handle(.html("page.html"))

        let expectedPath = tempRoot.appendingPathComponent("page.html")
        XCTAssertEqual(try String(contentsOf: expectedPath, encoding: .utf8), page.html)
        XCTAssertEqual(output.renderedBlocks.last, """
        <result>
        artifact: \(expectedPath.path)
        </result>

        """)
    }

    private func makeHandler(
        page: FakeInspectablePage,
        output: RecordingProtocolOutput,
        tempDirectory: URL? = nil
    ) -> SlashCommandHandler {
        SlashCommandHandler(
            page: page,
            trace: TraceStore(),
            artifactWriter: LocalArtifactWriter(
                resolver: ArtifactPathResolver(tempDirectory: tempDirectory ?? temporaryDirectory())
            ),
            output: output
        )
    }

    private func temporaryDirectory() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
