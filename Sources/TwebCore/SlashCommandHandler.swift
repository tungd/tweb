import Foundation

public final class SlashCommandHandler {
    private let page: InspectablePage
    private let trace: TraceStore
    private let artifactWriter: ArtifactWriter
    private let output: ProtocolOutput

    public init(
        page: InspectablePage,
        trace: TraceStore,
        artifactWriter: ArtifactWriter,
        output: ProtocolOutput
    ) {
        self.page = page
        self.trace = trace
        self.artifactWriter = artifactWriter
        self.output = output
    }

    @discardableResult
    public func handle(_ command: SlashCommand) throws -> SessionReceiveOutcome {
        switch command {
        case .trace:
            output.write(.trace(trace.renderJSON()))
        case .eval(let source):
            let result = try page.evaluateJavaScript(source)
            output.write(.result("eval: \(result.rendered)"))
        case .screenshot(let requestedPath):
            let data = try page.captureScreenshot(mode: .fullPage)
            let url = try artifactWriter.write(data: data, requestedPath: requestedPath)
            output.write(.result("artifact: \(url.path)"))
        case .html(let requestedPath):
            let html = try page.currentHTML()
            let url = try artifactWriter.write(text: html, requestedPath: requestedPath)
            output.write(.result("artifact: \(url.path)"))
        case .human, .interrupt:
            output.write(.error("unsupported command in this session state"))
        case .quit:
            return .exit
        }

        return .continueSession
    }
}
