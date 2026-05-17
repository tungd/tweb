import Foundation

public enum ProtocolBlock: Equatable {
    case ready(url: String)
    case update(String)
    case result(String)
    case error(String)
    case fatal(String)
    case trace(String)
    case needsInput(String)
}

public enum TextProtocolRenderer {
    public static func render(_ block: ProtocolBlock) -> String {
        switch block {
        case .ready(let url):
            return tagged("ready", body: "url: \(url)")
        case .update(let message):
            return tagged("update", body: message)
        case .result(let message):
            return tagged("result", body: message)
        case .error(let message):
            return tagged("error", body: message)
        case .fatal(let message):
            return tagged("fatal", body: message)
        case .trace(let json):
            return tagged("trace", body: json)
        case .needsInput(let message):
            return tagged("needs-input", body: message)
        }
    }

    private static func tagged(_ tag: String, body: String) -> String {
        """
        <\(tag)>
        \(body)
        </\(tag)>

        """
    }
}

public protocol ProtocolOutput: AnyObject {
    func write(_ block: ProtocolBlock)
}

public final class StandardProtocolOutput: ProtocolOutput {
    private let writeString: (String) -> Void

    public init(writeString: @escaping (String) -> Void = { print($0, terminator: "") }) {
        self.writeString = writeString
    }

    public func write(_ block: ProtocolBlock) {
        writeString(TextProtocolRenderer.render(block))
    }
}
