import Foundation

public struct PageAgentBundle: Equatable {
    public let source: String

    public init(source: String) {
        self.source = source
    }

    public static let pinnedCDNURL = URL(
        string: "https://cdn.jsdelivr.net/npm/page-agent@1.8.2/dist/iife/page-agent.demo.js?autoInit=false"
    )!

    public static func pinnedCDNLoader() throws -> PageAgentBundle {
        try pinnedCDNLoader(
            vendorSource: loadPinnedCDNVendorSource()
        )
    }

    public static func pinnedCDNLoader(vendorSource: String) throws -> PageAgentBundle {
        let sources = [
            currentScriptShim(sourceURL: pinnedCDNURL),
            vendorSource,
            adapterSource
        ]
        return PageAgentBundle(source: sources.joined(separator: "\n;\n"))
    }

    private static func loadPinnedCDNVendorSource() throws -> String {
        let cacheURL = pinnedCDNCacheURL()
        if
            let cached = try? String(contentsOf: cacheURL, encoding: .utf8),
            !cached.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return cached
        }

        let source = try String(contentsOf: pinnedCDNURL, encoding: .utf8)
        try FileManager.default.createDirectory(
            at: cacheURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try source.write(to: cacheURL, atomically: true, encoding: .utf8)
        return source
    }

    private static func pinnedCDNCacheURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache", isDirectory: true)
            .appendingPathComponent("tweb", isDirectory: true)
            .appendingPathComponent("page-agent", isDirectory: true)
            .appendingPathComponent("1.8.2", isDirectory: true)
            .appendingPathComponent("page-agent.demo.js", isDirectory: false)
    }

    private static func currentScriptShim(sourceURL: URL) -> String {
        let sourceLiteral = javascriptStringLiteral(sourceURL.absoluteString)
        return """
        (function () {
          "use strict";

          var fakeScript = document.createElement("script");
          fakeScript.src = \(sourceLiteral);
          var originalCurrentScript = Object.getOwnPropertyDescriptor(Document.prototype, "currentScript");
          Object.defineProperty(Document.prototype, "currentScript", {
            configurable: true,
            get: function () {
              return fakeScript;
            }
          });
          window.__twebPageAgentRestoreCurrentScript = function () {
            if (originalCurrentScript) {
              Object.defineProperty(Document.prototype, "currentScript", originalCurrentScript);
            }
            delete window.__twebPageAgentRestoreCurrentScript;
          };
        })();
        """
    }

    private static let adapterSource = #"""
    (function () {
      "use strict";

      if (typeof window.__twebPageAgentRestoreCurrentScript === "function") {
        window.__twebPageAgentRestoreCurrentScript();
      }

      function compactText(value, limit) {
        return String(value || "")
          .replace(/\s+/g, " ")
          .trim()
          .slice(0, limit);
      }

      function displayText(value, limit) {
        return String(value || "")
          .trim()
          .slice(0, limit);
      }

      function evidenceFromResult(result) {
        var history = result && Array.isArray(result.history) ? result.history : [];
        for (var index = history.length - 1; index >= 0; index -= 1) {
          var event = history[index];
          if (event && event.type === "step" && event.action) {
            var output = event.action.output || event.action.input && event.action.input.text;
            var quote = compactText(output, 220);
            if (quote) {
              return quote;
            }
          }
          if (event && event.type === "observation") {
            var observation = compactText(event.content, 220);
            if (observation) {
              return observation;
            }
          }
        }
        return compactText(document.title || location.href, 220);
      }

      function agentConfig() {
        return {
          model: "tweb-configured-model",
          baseURL: "tweb-llm://model/v1",
          apiKey: "",
          customFetch: nativeModelFetch,
          language: "en-US",
          enableMask: false,
          promptForNextTask: false,
          maxSteps: 40,
          stepDelay: 0.2,
          customTools: {
            ask_user: null
          },
          instructions: {
            system: [
              "You are Alibaba PageAgent running inside tweb.",
              "Use the active page and PageAgent page tools to complete the parent Agent's task.",
              "Finish by calling done with the concise final answer.",
              "Use line breaks for lists, sections, and multi-point answers.",
              "If the task requires a page unload or browser capability that the in-page runtime cannot continue through, report that limitation explicitly."
            ].join(" ")
          }
        };
      }

      async function nativeModelFetch(url, options) {
        options = options || {};
        window.__twebPageAgentModelTurnCount = (window.__twebPageAgentModelTurnCount || 0) + 1;
        if (options.body && typeof options.body !== "string") {
          throw new Error("Unsupported native model request body");
        }
        if (options.signal && options.signal.aborted) {
          throw new DOMException("Native model request aborted", "AbortError");
        }
        var rawResponse = window.prompt("__tweb_model_request__", JSON.stringify({
          method: options.method || "GET",
          url: String(url),
          body: options.body || ""
        }));
        if (options.signal && options.signal.aborted) {
          throw new DOMException("Native model request aborted", "AbortError");
        }
        if (!rawResponse) {
          throw new Error("Native model bridge returned no response");
        }

        var response = JSON.parse(rawResponse);
        return new Response(response.body || "", {
          status: response.status || 200,
          headers: response.headers || {
            "Content-Type": "application/json"
          }
        });
      }

      function ensureAgent() {
        if (typeof window.PageAgent !== "function") {
          throw new Error("Alibaba PageAgent failed to load");
        }
        if (!window.__twebAlibabaPageAgent || window.__twebAlibabaPageAgent.disposed) {
          window.__twebAlibabaPageAgent = new window.PageAgent(agentConfig());
        }
        return window.__twebAlibabaPageAgent;
      }

      window.__twebPageAgentReady = typeof window.PageAgent === "function";
      if (!window.__twebPageAgentReady) {
        throw new Error("Alibaba PageAgent failed to load");
      }

      window.__twebPageAgent = {
        async runTwebTask(task, context) {
          window.__twebPageAgentModelTurnCount = 0;
          var agent = ensureAgent(context || {});
          var result = await agent.execute(task);
          var text = displayText(result && result.data, 8000) || "PageAgent completed without returning text.";
          return {
            text: text,
            compactEvidence: [
              {
                source: location.href,
                quote: evidenceFromResult(result)
              }
            ]
          };
        },

        stopTwebTask() {
          if (window.__twebAlibabaPageAgent && typeof window.__twebAlibabaPageAgent.stop === "function") {
            window.__twebAlibabaPageAgent.stop();
          }
        }
      };
    })();
    """#

    private static func javascriptStringLiteral(_ value: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let data = try? encoder.encode(value)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\(value)\""
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
            return "PageAgent bundle was not found"
        case .readinessProbeFailed:
            return "in-page engine readiness probe failed"
        }
    }
}

public final class InPageEngineInstaller {
    private let readinessProbe: String
    private let readinessTimeout: TimeInterval
    private let pollInterval: TimeInterval

    public init(
        readinessProbe: String = "window.__twebPageAgentReady === true",
        readinessTimeout: TimeInterval = 10,
        pollInterval: TimeInterval = 0.05
    ) {
        self.readinessProbe = readinessProbe
        self.readinessTimeout = readinessTimeout
        self.pollInterval = pollInterval
    }

    public convenience init(readinessProbe: String) {
        self.init(
            readinessProbe: readinessProbe,
            readinessTimeout: 10,
            pollInterval: 0.05
        )
    }

    public func install(bundle: PageAgentBundle, into page: ScriptInjectingPage) throws -> InstalledEngine {
        try page.inject(script: bundle.source, into: .mainFrame)
        let deadline = Date(timeIntervalSinceNow: readinessTimeout)
        repeat {
            if try page.evaluateReadinessProbe(readinessProbe) {
                return InstalledEngine(name: "PageAgent", ready: true)
            }
            if pollInterval > 0 {
                Thread.sleep(forTimeInterval: pollInterval)
            }
        } while Date() < deadline

        if try page.evaluateReadinessProbe(readinessProbe) {
            return InstalledEngine(name: "PageAgent", ready: true)
        }
        throw EngineInstallationError.readinessProbeFailed
    }
}
