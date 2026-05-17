import Foundation

public enum BrowserEvent: Equatable {
    case status(String)
    case urlChanged(String)
}

public protocol BrowserSession: AnyObject {
    var onEvent: ((BrowserEvent) -> Void)? { get set }
    var currentURL: String { get }

    func startHidden() throws
    func load(_ url: String) throws
    func close()
}
