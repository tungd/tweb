import XCTest
@testable import TwebCore

final class Issue05InPageEngineTests: XCTestCase {
    func testVendoredPageAgentBundleCanBeLoaded() throws {
        let bundle = try PageAgentBundle.vendored()

        XCTAssertTrue(bundle.source.contains("__twebPageAgentReady"))
        XCTAssertTrue(bundle.source.contains("runTwebTask"))
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
        let installer = InPageEngineInstaller()

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
