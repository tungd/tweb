import Foundation
@testable import TwebCore

final class RecordingProtocolOutput: ProtocolOutput {
    private(set) var renderedBlocks: [String] = []

    func write(_ block: ProtocolBlock) {
        renderedBlocks.append(TextProtocolRenderer.render(block))
    }
}

final class FakeBrowserSession: BrowserSession {
    var onEvent: ((BrowserEvent) -> Void)?
    private(set) var loadedURLs: [String] = []
    private(set) var closed = false

    var currentURL: String {
        loadedURLs.last ?? "about:blank"
    }

    func startHidden() throws {
        emitStatus("hidden session started")
    }

    func load(_ url: String) throws {
        loadedURLs.append(url)
        onEvent?(.urlChanged(url))
    }

    func close() {
        closed = true
    }

    func emitStatus(_ status: String) {
        onEvent?(.status(status))
    }
}

final class FakeInspectablePage: InspectablePage {
    var evaluationResults: [String: JSONValue] = [:]
    var evaluatedScripts: [String] = []
    var screenshotData = Data()
    var screenshotRequests: [ScreenshotCaptureMode] = []
    var html = ""

    func evaluateJavaScript(_ source: String) throws -> JSONValue {
        evaluatedScripts.append(source)
        return evaluationResults[source] ?? .null
    }

    func captureScreenshot(mode: ScreenshotCaptureMode) throws -> Data {
        screenshotRequests.append(mode)
        return screenshotData
    }

    func currentHTML() throws -> String {
        html
    }
}

final class FakeSecretStore: SecretStore {
    var tokens: [String: String] = [:]

    func saveSecret(_ value: String, forKey key: String) throws {
        tokens[key] = value
    }

    func readSecret(forKey key: String) throws -> String? {
        tokens[key]
    }
}
