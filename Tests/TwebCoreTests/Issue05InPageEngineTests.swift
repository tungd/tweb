import XCTest
@testable import TwebCore

final class Issue05InPageEngineTests: XCTestCase {
    func testPinnedPageAgentLoaderBundleCanBeLoaded() throws {
        let bundle = try PageAgentBundle.pinnedCDNLoader(
            vendorSource: "window.PageAgent = function PageAgent() {};"
        )

        XCTAssertTrue(bundle.source.contains("page-agent@1.8.2/dist/iife/page-agent.demo.js?autoInit=false"))
        XCTAssertTrue(bundle.source.contains("window.PageAgent = function PageAgent() {};"))
        XCTAssertTrue(bundle.source.contains("__twebPageAgentRestoreCurrentScript"))
        XCTAssertTrue(bundle.source.contains("__twebPageAgentReady"))
        XCTAssertTrue(bundle.source.contains("runTwebTask"))
        XCTAssertFalse(bundle.source.contains("document.createElement(\"script\");\n  script.src"))
    }

    func testPinnedPageAgentLoaderUsesAlibabaPageAgentThroughTwebModelBridge() throws {
        let bundle = try PageAgentBundle.pinnedCDNLoader(
            vendorSource: "window.PageAgent = function PageAgent() {};"
        )

        XCTAssertTrue(bundle.source.contains("cdn.jsdelivr.net/npm/page-agent@1.8.2"))
        XCTAssertTrue(bundle.source.contains(#"baseURL: "tweb-llm://model/v1""#))
        XCTAssertTrue(bundle.source.contains("customFetch: nativeModelFetch"))
        XCTAssertTrue(bundle.source.contains(#"window.prompt("__tweb_model_request__""#))
        XCTAssertTrue(bundle.source.contains("agent.execute(task)"))
        XCTAssertTrue(bundle.source.contains("displayText(result && result.data"))
        XCTAssertTrue(bundle.source.contains("Use line breaks for lists"))
        XCTAssertFalse(bundle.source.contains("PageAgent fixture executed the task"))
        XCTAssertFalse(bundle.source.contains(#""completed: " + task"#))
    }

    func testInstallerInjectsBundleIntoMainFrameAndVerifiesReadiness() throws {
        let page = FakeScriptInjectingPage()
        page.readinessResult = true
        let bundle = PageAgentBundle(source: "window.__twebPageAgentReady = true;")
        let installer = InPageEngineInstaller(readinessProbe: "window.__twebPageAgentReady === true")

        let installed = try installer.install(bundle: bundle, into: page)

        XCTAssertEqual(installed, InstalledEngine(name: "PageAgent", ready: true))
        XCTAssertEqual(page.injections, [
            ScriptInjection(script: bundle.source, frame: .mainFrame)
        ])
        XCTAssertEqual(page.readinessProbes, ["window.__twebPageAgentReady === true"])
    }

    func testInstallerFailsWhenReadinessSignalIsMissing() throws {
        let page = FakeScriptInjectingPage()
        page.readinessResult = false
        let installer = InPageEngineInstaller(readinessTimeout: 0, pollInterval: 0)

        XCTAssertThrowsError(try installer.install(
            bundle: PageAgentBundle(source: "window.noop = true;"),
            into: page
        )) { error in
            XCTAssertEqual(error as? EngineInstallationError, .readinessProbeFailed)
        }
    }

    func testExternalSlashCommandContractDoesNotExposePageAgentSpecificAPIs() {
        XCTAssertThrowsError(try SlashCommand.parse("/pageagent.step"))
    }
}
