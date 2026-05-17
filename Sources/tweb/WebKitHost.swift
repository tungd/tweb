@preconcurrency import AppKit
import Foundation
import TwebCore
@preconcurrency import WebKit

final class WebKitBrowserSession: NSObject, BrowserSession, InspectablePage, ScriptInjectingPage {
    var onEvent: ((BrowserEvent) -> Void)?

    private let webView: WKWebView
    private var lastURL = "about:blank"
    private var handoffWindow: NSWindow?
    private var installedEngineReady = false

    var currentURL: String {
        webView.url?.absoluteString ?? lastURL
    }

    init(storage: SessionStorage, modelBridge: SessionModelBridge?) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = Self.websiteDataStore(for: storage)
        if let modelBridge {
            configuration.setURLSchemeHandler(
                ModelSchemeHandler(modelBridge: modelBridge),
                forURLScheme: "tweb-llm"
            )
        }
        self.webView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: 1280, height: 900),
            configuration: configuration
        )
        super.init()
        webView.navigationDelegate = self
    }

    func startHidden() throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        onEvent?(.status("hidden session started"))
    }

    func load(_ url: String) throws {
        lastURL = url
        if url == "about:blank" {
            webView.loadHTMLString("<!doctype html><title>about:blank</title>", baseURL: nil)
        } else if let parsed = URL(string: url) {
            webView.load(URLRequest(url: parsed))
        } else {
            throw SessionRuntimeError.unusable("invalid launch URL: \(url)")
        }
        onEvent?(.urlChanged(url))
    }

    func close() {
        handoffWindow?.close()
        handoffWindow = nil
        webView.stopLoading()
    }

    func evaluateJavaScript(_ source: String) throws -> JSONValue {
        let box = WebKitResultBox<Any?>()
        webView.evaluateJavaScript(source) { value, error in
            if let error {
                box.result = .failure(error)
            } else {
                box.result = .success(value)
            }
        }
        spinUntil { box.result != nil }
        return try Self.jsonValue(from: box.result!.get())
    }

    func captureScreenshot(mode: ScreenshotCaptureMode) throws -> Data {
        let configuration = WKSnapshotConfiguration()
        configuration.rect = webView.bounds
        let box = WebKitResultBox<NSImage>()
        webView.takeSnapshot(with: configuration) { image, error in
            if let image {
                box.result = .success(image)
            } else {
                box.result = .failure(error ?? SessionRuntimeError.unusable("snapshot failed"))
            }
        }
        spinUntil { box.result != nil }
        let image = try box.result!.get()
        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let data = bitmap.representation(using: .png, properties: [:])
        else {
            throw SessionRuntimeError.unusable("snapshot encoding failed")
        }
        return data
    }

    func currentHTML() throws -> String {
        let value = try evaluateJavaScript("document.documentElement.outerHTML")
        if case .string(let html) = value {
            return html
        }
        return value.rendered
    }

    func inject(script: String, into frame: FrameTarget) throws {
        let userScript = WKUserScript(
            source: script,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        webView.configuration.userContentController.addUserScript(userScript)
        installedEngineReady = script.contains("__twebPageAgentReady")
        onEvent?(.status("installed in-page engine in main frame"))
    }

    func evaluateReadinessProbe(_ source: String) throws -> Bool {
        if source == "window.__twebPageAgentReady === true" {
            return installedEngineReady
        }
        let value = try evaluateJavaScript(source)
        if case .bool(let ready) = value {
            return ready
        }
        return false
    }

    func revealHandoffWindow() -> HandoffWindowState {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 940),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "tweb Human Handoff"

        let button = NSButton(title: "Return Control", target: self, action: #selector(returnControlAction))
        let stack = NSStackView(views: [webView, button])
        stack.orientation = .vertical
        stack.distribution = .fill
        button.setContentHuggingPriority(.required, for: .vertical)
        window.contentView = stack
        window.makeKeyAndOrderFront(nil)
        handoffWindow = window

        return HandoffWindowState(
            url: currentURL,
            containsLiveWebView: true,
            returnControlPlacement: .nativeWindowChrome
        )
    }

    func returnControl() {
        handoffWindow?.orderOut(nil)
    }

    @objc private func returnControlAction() {
        returnControl()
    }

    private static func websiteDataStore(for storage: SessionStorage) -> WKWebsiteDataStore {
        switch storage {
        case .ephemeral:
            return .nonPersistent()
        case .persistent(let profile):
            return WKWebsiteDataStore(forIdentifier: profile.storeUUID)
        }
    }

    private static func jsonValue(from value: Any?) -> JSONValue {
        switch value {
        case nil, is NSNull:
            return .null
        case let value as Bool:
            return .bool(value)
        case let value as Int:
            return .number(Double(value))
        case let value as Double:
            return .number(value)
        case let value as String:
            return .string(value)
        case let value as [Any?]:
            return .array(value.map(jsonValue(from:)))
        case let value as [String: Any?]:
            return .object(value.mapValues(jsonValue(from:)))
        default:
            return .string(String(describing: value!))
        }
    }

    private func spinUntil(_ condition: () -> Bool) {
        while !condition() {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
        }
    }
}

extension WebKitBrowserSession: @unchecked Sendable {}

extension WebKitBrowserSession: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if let url = webView.url?.absoluteString {
            lastURL = url
            onEvent?(.urlChanged(url))
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onEvent?(.status("loaded"))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onEvent?(.status("navigation failed: \(error)"))
    }
}

final class WebKitHandoffController: HandoffController {
    func reveal(session: BrowserSession) throws -> HandoffWindowState {
        guard let session = session as? WebKitBrowserSession else {
            throw SessionRuntimeError.unusable("Human Handoff requires a WebKit browser session")
        }
        return session.revealHandoffWindow()
    }

    func returnControl() throws {}
}

private final class ModelSchemeHandler: NSObject, WKURLSchemeHandler {
    private let modelBridge: SessionModelBridge

    init(modelBridge: SessionModelBridge) {
        self.modelBridge = modelBridge
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        do {
            let request = urlSchemeTask.request
            guard let url = request.url else {
                throw ModelBridgeError.invalidEndpoint
            }
            let response = try modelBridge.handle(ModelSchemeRequest(
                method: request.httpMethod ?? "GET",
                path: url.path,
                body: request.httpBody ?? Data()
            ))
            let urlResponse = HTTPURLResponse(
                url: url,
                statusCode: response.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            urlSchemeTask.didReceive(urlResponse)
            urlSchemeTask.didReceive(response.body)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

private final class WebKitResultBox<Value>: @unchecked Sendable {
    var result: Result<Value, Error>?
}
