import Foundation

public struct PageAgentBundle: Equatable {
    public let source: String

    public init(source: String) {
        self.source = source
    }

    public static func vendored() throws -> PageAgentBundle {
        try vendored(bundle: .module)
    }

    public static func vendored(bundle: Bundle) throws -> PageAgentBundle {
        let url = bundle.url(
            forResource: "pageagent.bundle",
            withExtension: "js",
            subdirectory: "PageAgent"
        ) ?? bundle.url(
            forResource: "pageagent.bundle",
            withExtension: "js"
        )
        guard let url else {
            throw EngineInstallationError.bundleNotFound
        }
        return PageAgentBundle(source: try String(contentsOf: url, encoding: .utf8))
    }
}

public enum FrameTarget: Equatable {
    case mainFrame
}

public struct ScriptInjection: Equatable {
    public let script: String
    public let frame: FrameTarget

    public init(script: String, frame: FrameTarget) {
        self.script = script
        self.frame = frame
    }
}

public protocol ScriptInjectingPage: AnyObject {
    func inject(script: String, into frame: FrameTarget) throws
    func evaluateReadinessProbe(_ source: String) throws -> Bool
}

public struct InstalledEngine: Equatable {
    public let name: String
    public let ready: Bool

    public init(name: String, ready: Bool) {
        self.name = name
        self.ready = ready
    }
}

public enum EngineInstallationError: Error, Equatable, CustomStringConvertible {
    case bundleNotFound
    case readinessProbeFailed

    public var description: String {
        switch self {
        case .bundleNotFound:
            return "vendored PageAgent bundle was not found"
        case .readinessProbeFailed:
            return "in-page engine readiness probe failed"
        }
    }
}

public final class InPageEngineInstaller {
    private let readinessProbe: String

    public init(readinessProbe: String = "window.__twebPageAgentReady === true") {
        self.readinessProbe = readinessProbe
    }

    public func install(bundle: PageAgentBundle, into page: ScriptInjectingPage) throws -> InstalledEngine {
        try page.inject(script: bundle.source, into: .mainFrame)
        guard try page.evaluateReadinessProbe(readinessProbe) else {
            throw EngineInstallationError.readinessProbeFailed
        }
        return InstalledEngine(name: "PageAgent", ready: true)
    }
}
