@preconcurrency import AppKit
import Foundation
import TwebCore
@preconcurrency import WebKit

final class WebKitBrowserSession: NSObject, BrowserSession, InspectablePage, ScriptInjectingPage, PageAgentScriptPage {
    var onEvent: ((BrowserEvent) -> Void)?

    private let webView: WKWebView
    private let modelBridge: SessionModelBridge?
    private var lastURL = "about:blank"
    private var handoffWindow: NSWindow?
    private var pendingLoad: WKNavigation?
    private var pendingLoadError: Error?
    private var registeredEngineScript: String?
    private static let nativeModelPrompt = "__tweb_model_request__"

    var currentURL: String {
        runOnMain { currentURLOnMain }
    }

    init(storage: SessionStorage, modelBridge: SessionModelBridge?) {
        self.modelBridge = modelBridge
        if Thread.isMainThread {
            self.webView = MainActor.assumeIsolated {
                Self.makeWebView(storage: storage)
            }
        } else {
            self.webView = DispatchQueue.main.sync {
                MainActor.assumeIsolated {
                    Self.makeWebView(storage: storage)
                }
            }
        }
        super.init()
        runOnMainVoid {
            webView.navigationDelegate = self
            webView.uiDelegate = self
        }
    }

    @MainActor
    private static func makeWebView(storage: SessionStorage) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = websiteDataStore(for: storage)
        return WKWebView(
            frame: CGRect(x: 0, y: 0, width: 1280, height: 900),
            configuration: configuration
        )
    }

    func startHidden() throws {
        runOnMain {
            _ = NSApplication.shared
            NSApp.setActivationPolicy(.accessory)
            onEvent?(.status("hidden session started"))
        }
    }

    func load(_ url: String) throws {
        try runOnMain { try loadOnMain(url) }
    }

    @MainActor
    private func loadOnMain(_ url: String) throws {
        lastURL = url
        if url == "about:blank" {
            onEvent?(.urlChanged(url))
            return
        }

        pendingLoadError = nil
        let navigation: WKNavigation?
        if let parsed = URL(string: url) {
            navigation = webView.load(URLRequest(url: parsed))
        } else {
            throw SessionRuntimeError.unusable("invalid launch URL: \(url)")
        }
        if let navigation {
            pendingLoad = navigation
            if !spinUntil(timeout: 5, { pendingLoad == nil }) {
                pendingLoad = nil
            }
            if let pendingLoadError {
                self.pendingLoadError = nil
                throw pendingLoadError
            }
        }
        lastURL = currentURLOnMain
        onEvent?(.urlChanged(currentURLOnMain))
    }

    func close() {
        runOnMain { closeOnMain() }
    }

    @MainActor
    private func closeOnMain() {
        handoffWindow?.close()
        handoffWindow = nil
        webView.stopLoading()
    }

    func evaluateJavaScript(_ source: String) throws -> JSONValue {
        try runOnMain {
            try evaluateJavaScriptOnMain(
                """
                (() => {
                  const render = (value) => {
                    if (value === undefined) {
                      return "null";
                    }
                    try {
                      const encoded = JSON.stringify(value);
                      if (encoded !== undefined) {
                        return encoded;
                      }
                    } catch (_) {}
                    return JSON.stringify(String(value));
                  };
                  return render((
                \(source)
                  ));
                })()
                """
            )
        }
    }

    @MainActor
    private func evaluateJavaScriptOnMain(_ source: String) throws -> JSONValue {
        let box = WebKitResultBox<Any?>()
        webView.evaluateJavaScript(source) { value, error in
            if let error {
                box.result = .failure(error)
            } else {
                box.result = .success(value)
            }
        }
        spinUntil { box.result != nil }
        let value = try box.result!.get()
        if
            let rendered = value as? String,
            let data = rendered.data(using: .utf8),
            let decoded = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        {
            return Self.jsonValue(from: decoded)
        }
        return Self.jsonValue(from: value)
    }

    func callAsyncJavaScript(_ source: String, arguments: [String: String]) throws -> JSONValue {
        try runOnMain {
            try callAsyncJavaScriptOnMain(source, arguments: arguments, timeout: nil)
        }
    }

    @MainActor
    private func callAsyncJavaScriptOnMain(
        _ source: String,
        arguments: [String: String],
        timeout: TimeInterval?
    ) throws -> JSONValue {
        let box = WebKitResultBox<Any?>()
        webView.callAsyncJavaScript(
            source,
            arguments: arguments,
            in: nil,
            in: .page
        ) { result in
            switch result {
            case .success(let value):
                box.result = .success(value)
            case .failure(let error):
                box.result = .failure(error)
            }
        }
        guard spinUntil(timeout: timeout, { box.result != nil }) else {
            throw SessionRuntimeError.unusable("timed out evaluating JavaScript")
        }
        return try Self.jsonValue(from: box.result!.get())
    }

    func captureScreenshot(mode: ScreenshotCaptureMode) throws -> Data {
        try runOnMain {
            try captureScreenshotOnMain(mode: mode)
        }
    }

    @MainActor
    private func captureScreenshotOnMain(mode: ScreenshotCaptureMode) throws -> Data {
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
        try runOnMain { try injectOnMain(script: script, into: frame) }
    }

    @MainActor
    private func injectOnMain(script: String, into frame: FrameTarget) throws {
        let userScript = WKUserScript(
            source: script,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        if registeredEngineScript != script {
            webView.configuration.userContentController.addUserScript(userScript)
            registeredEngineScript = script
            try reloadForRegisteredUserScriptOnMain()
        }
        onEvent?(.status("installed in-page engine in main frame"))
    }

    func evaluateReadinessProbe(_ source: String) throws -> Bool {
        try runOnMain { try evaluateReadinessProbeOnMain(source) }
    }

    @MainActor
    private func evaluateReadinessProbeOnMain(_ source: String) throws -> Bool {
        let box = WebKitResultBox<Any?>()
        webView.evaluateJavaScript("Boolean(\(source))") { value, error in
            if let error {
                box.result = .failure(error)
            } else {
                box.result = .success(value)
            }
        }
        spinUntil { box.result != nil }
        return (try box.result!.get() as? Bool) ?? false
    }

    func revealHandoffWindow() -> HandoffWindowState {
        runOnMain { revealHandoffWindowOnMain() }
    }

    @MainActor
    private func revealHandoffWindowOnMain() -> HandoffWindowState {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 940),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "tweb Human Handoff"

        let button = NSButton(
            title: "Return Control",
            target: self,
            action: #selector(returnControlAction)
        )
        let stack = NSStackView(views: [webView, button])
        stack.orientation = .vertical
        stack.distribution = .fill
        button.setContentHuggingPriority(.required, for: .vertical)
        window.contentView = stack
        window.makeKeyAndOrderFront(nil)
        handoffWindow = window

        return HandoffWindowState(
            url: currentURLOnMain,
            containsLiveWebView: true,
            returnControlPlacement: .nativeWindowChrome
        )
    }

    func returnControl() {
        runOnMain { returnControlOnMain() }
    }

    @MainActor
    private func returnControlOnMain() {
        handoffWindow?.orderOut(nil)
    }

    @MainActor @objc private func returnControlAction() {
        returnControlOnMain()
    }

    @MainActor
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

    private func handleNativeModelPrompt(_ text: String?) -> String {
        guard let modelBridge else {
            return Self.nativeModelPromptError("model bridge is unavailable")
        }
        guard let text, let data = text.data(using: .utf8) else {
            return Self.nativeModelPromptError("model bridge request was empty")
        }

        do {
            let request = try JSONDecoder().decode(NativeModelPromptRequest.self, from: data)
            guard let url = URL(string: request.url) else {
                throw ModelBridgeError.invalidEndpoint
            }
            let response = try modelBridge.handle(ModelSchemeRequest(
                method: request.method ?? "GET",
                path: url.path,
                body: Data((request.body ?? "").utf8)
            ))
            return Self.nativeModelPromptResponse(
                status: response.statusCode,
                body: String(data: response.body, encoding: .utf8) ?? ""
            )
        } catch {
            return Self.nativeModelPromptError(String(describing: error))
        }
    }

    private static func nativeModelPromptResponse(status: Int, body: String) -> String {
        let payload: [String: Any] = [
            "status": status,
            "body": body,
            "headers": [
                "Content-Type": "application/json"
            ]
        ]
        guard
            let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
            let rendered = String(data: data, encoding: .utf8)
        else {
            return #"{"status":599,"body":"{\"error\":{\"message\":\"failed to encode native model response\"}}","headers":{"Content-Type":"application/json"}}"#
        }
        return rendered
    }

    private static func nativeModelPromptError(_ message: String) -> String {
        let bodyObject: [String: Any] = [
            "error": [
                "message": message
            ]
        ]
        let bodyData = try? JSONSerialization.data(withJSONObject: bodyObject, options: [])
        let body = bodyData.flatMap { String(data: $0, encoding: .utf8) }
            ?? #"{"error":{"message":"native model bridge failed"}}"#
        return nativeModelPromptResponse(status: 599, body: body)
    }

    @MainActor
    private func reloadForRegisteredUserScriptOnMain() throws {
        pendingLoadError = nil
        let navigation: WKNavigation?
        if webView.url == nil || currentURLOnMain == "about:blank" {
            navigation = webView.loadHTMLString("<!doctype html><title>about:blank</title>", baseURL: nil)
        } else {
            navigation = webView.reload()
        }

        guard let navigation else {
            return
        }
        pendingLoad = navigation
        if !spinUntil(timeout: 10, { pendingLoad == nil }) {
            pendingLoad = nil
        }
        if let pendingLoadError {
            self.pendingLoadError = nil
            throw pendingLoadError
        }
    }

    @discardableResult
    private func spinUntil(timeout: TimeInterval? = nil, _ condition: () -> Bool) -> Bool {
        let deadline = timeout.map { Date(timeIntervalSinceNow: $0) }
        while !condition() {
            if let deadline, Date() >= deadline {
                return false
            }
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
        }
        return true
    }

    private func runOnMain<T: Sendable>(_ body: @MainActor () -> T) -> T {
        if Thread.isMainThread {
            return MainActor.assumeIsolated(body)
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated(body)
        }
    }

    private func runOnMainVoid(_ body: @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated(body)
        } else {
            DispatchQueue.main.sync { MainActor.assumeIsolated(body) }
        }
    }

    private func runOnMain<T: Sendable>(_ body: @MainActor () throws -> T) throws -> T {
        if Thread.isMainThread {
            return try MainActor.assumeIsolated(body)
        }
        return try DispatchQueue.main.sync {
            try MainActor.assumeIsolated(body)
        }
    }

    @MainActor
    private var currentURLOnMain: String {
        webView.url?.absoluteString ?? lastURL
    }
}

extension WebKitBrowserSession: @unchecked Sendable {}

extension WebKitBrowserSession: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        runOnMain {
            if let url = webView.url?.absoluteString {
                lastURL = url
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        runOnMain {
            onEvent?(.status("loaded"))
            if navigation === pendingLoad {
                pendingLoad = nil
                return
            }
            if let url = webView.url?.absoluteString {
                lastURL = url
                onEvent?(.urlChanged(url))
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        runOnMain {
            if navigation === pendingLoad {
                pendingLoadError = error
                pendingLoad = nil
            }
            onEvent?(.status("navigation failed: \(error)"))
        }
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        runOnMain {
            if navigation === pendingLoad {
                pendingLoadError = error
                pendingLoad = nil
            }
            onEvent?(.status("navigation failed: \(error)"))
        }
    }
}

extension WebKitBrowserSession: WKUIDelegate {
    @MainActor
    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor @Sendable (String?) -> Void
    ) {
        runOnMain {
            guard prompt == Self.nativeModelPrompt else {
                completionHandler(nil)
                return
            }
            completionHandler(handleNativeModelPrompt(defaultText))
        }
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

private struct NativeModelPromptRequest: Decodable {
    let method: String?
    let url: String
    let body: String?
}

private final class WebKitResultBox<Value>: @unchecked Sendable {
    var result: Result<Value, Error>?
}
