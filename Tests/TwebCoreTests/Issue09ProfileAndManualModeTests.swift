import XCTest
@testable import TwebCore

final class Issue09ProfileAndManualModeTests: XCTestCase {
    func testSessionsWithoutProfileUseEphemeralSessionState() throws {
        let selector = ProfileSelector(registry: ProfileRegistry(fileURL: temporaryDirectory().appendingPathComponent("profiles.json")))

        XCTAssertEqual(try selector.storage(forProfileName: nil), .ephemeral)
    }

    func testProfileNameSelectsStableUUIDBackedProfileStore() throws {
        let registry = ProfileRegistry(fileURL: temporaryDirectory().appendingPathComponent("profiles.json"))

        let first = try registry.profile(named: "work")
        let second = try registry.profile(named: "work")

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.name, "work")
        XCTAssertNotNil(UUID(uuidString: first.storeUUID.uuidString))
        XCTAssertEqual(first.storageKind, .webkitWebsiteDataStore)
    }

    func testProfileMappingsPersistAcrossRuns() throws {
        let fileURL = temporaryDirectory().appendingPathComponent("profiles.json")
        let firstRegistry = ProfileRegistry(fileURL: fileURL)
        let first = try firstRegistry.profile(named: "personal")

        let secondRegistry = ProfileRegistry(fileURL: fileURL)
        let second = try secondRegistry.profile(named: "personal")

        XCTAssertEqual(first, second)
    }

    func testProfileSelectorCreatesPersistentStorageWhenProfileIsNamed() throws {
        let selector = ProfileSelector(registry: ProfileRegistry(fileURL: temporaryDirectory().appendingPathComponent("profiles.json")))

        let storage = try selector.storage(forProfileName: "work")

        guard case .persistent(let profile) = storage else {
            return XCTFail("Expected persistent profile storage")
        }
        XCTAssertEqual(profile.name, "work")
    }

    func testManualModeOpensVisibleSessionForNamedProfile() throws {
        let registry = ProfileRegistry(fileURL: temporaryDirectory().appendingPathComponent("profiles.json"))
        let manualSession = FakeManualProfileSession()
        let manualMode = ManualMode(registry: registry, session: manualSession)

        try manualMode.run(profileName: "work")

        XCTAssertEqual(manualSession.openedProfiles.map(\.name), ["work"])
        XCTAssertEqual(manualSession.visibility, [.visible])
    }

    private func temporaryDirectory() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
