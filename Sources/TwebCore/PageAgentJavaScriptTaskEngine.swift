import Foundation

public protocol PageAgentScriptPage: AnyObject {
    func callAsyncJavaScript(_ source: String, arguments: [String: String]) throws -> JSONValue
}

public enum PageAgentJavaScriptTaskEngineError: Error, Equatable, CustomStringConvertible {
    case invalidResult(String)
    case missingText
    case invalidCompactEvidence

    public var description: String {
        switch self {
        case .invalidResult(let rendered):
            return "PageAgent returned an invalid task result: \(rendered)"
        case .missingText:
            return "PageAgent task result is missing text"
        case .invalidCompactEvidence:
            return "PageAgent task result has invalid compact evidence"
        }
    }
}

public final class PageAgentJavaScriptTaskEngine: InterruptibleInPageTaskEngine {
    private let page: PageAgentScriptPage

    public init(page: PageAgentScriptPage) {
        self.page = page
    }

    public func runTask(_ request: InPageTaskRequest) throws -> TaskTurnResult {
        let result = try page.callAsyncJavaScript(Self.runTaskSource, arguments: [
            "task": request.text,
            "currentURL": request.currentURL,
            "modelEndpoint": "tweb-llm://model\(SessionModelBridge.chatCompletionsPath)"
        ])
        return try Self.taskTurnResult(from: result)
    }

    public func interruptTask() {
        _ = try? page.callAsyncJavaScript(Self.stopTaskSource, arguments: [:])
    }

    private static let runTaskSource = """
    if (!window.__twebPageAgent || typeof window.__twebPageAgent.runTwebTask !== "function") {
      throw new Error("PageAgent is not installed");
    }

    return await window.__twebPageAgent.runTwebTask(task, {
      currentURL: currentURL,
      modelEndpoint: modelEndpoint
    });
    """

    private static let stopTaskSource = """
    if (window.__twebPageAgent && typeof window.__twebPageAgent.stopTwebTask === "function") {
      window.__twebPageAgent.stopTwebTask();
    }

    return null;
    """

    private static func taskTurnResult(from value: JSONValue) throws -> TaskTurnResult {
        guard case .object(let object) = value else {
            throw PageAgentJavaScriptTaskEngineError.invalidResult(value.rendered)
        }
        guard case let .string(text)? = object["text"] else {
            throw PageAgentJavaScriptTaskEngineError.missingText
        }

        let evidenceValue = object["compactEvidence"] ?? .array([])
        guard case .array(let evidenceItems) = evidenceValue else {
            throw PageAgentJavaScriptTaskEngineError.invalidCompactEvidence
        }

        let evidence = try evidenceItems.map { item -> CompactEvidence in
            guard
                case let .object(evidenceObject) = item,
                case let .string(source)? = evidenceObject["source"],
                case let .string(quote)? = evidenceObject["quote"]
            else {
                throw PageAgentJavaScriptTaskEngineError.invalidCompactEvidence
            }
            return CompactEvidence(source: source, quote: quote)
        }

        return TaskTurnResult(text: text, compactEvidence: evidence)
    }
}
