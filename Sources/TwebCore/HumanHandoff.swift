import Foundation

public enum ReturnControlPlacement: Equatable {
    case nativeWindowChrome
}

public struct HandoffWindowState: Equatable {
    public let url: String
    public let containsLiveWebView: Bool
    public let returnControlPlacement: ReturnControlPlacement

    public init(
        url: String,
        containsLiveWebView: Bool,
        returnControlPlacement: ReturnControlPlacement
    ) {
        self.url = url
        self.containsLiveWebView = containsLiveWebView
        self.returnControlPlacement = returnControlPlacement
    }
}

public protocol HandoffController {
    func reveal(session: BrowserSession) throws -> HandoffWindowState
    func returnControl() throws
}
