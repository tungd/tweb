import Foundation

public protocol EngineReinstaller {
    func reinstall(afterTopLevelNavigationTo url: String) throws
}

public final class MainFrameEngineReinstaller: EngineReinstaller {
    private let page: ScriptInjectingPage
    private let bundle: PageAgentBundle
    private let installer: InPageEngineInstaller

    public init(
        page: ScriptInjectingPage,
        bundle: PageAgentBundle,
        installer: InPageEngineInstaller = InPageEngineInstaller()
    ) {
        self.page = page
        self.bundle = bundle
        self.installer = installer
    }

    public func reinstall(afterTopLevelNavigationTo url: String) throws {
        _ = try installer.install(bundle: bundle, into: page)
    }
}
