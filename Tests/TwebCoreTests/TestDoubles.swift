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
