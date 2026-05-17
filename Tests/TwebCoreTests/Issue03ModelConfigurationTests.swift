import Foundation
import XCTest
@testable import TwebCore

final class Issue03ModelConfigurationTests: XCTestCase {
    func testSetupModeStoresNonSecretsInConfigFileAndTokenInSecretStore() throws {
        let secretStore = FakeSecretStore()
        let configURL = temporaryDirectory().appendingPathComponent("model.json")
        let store = FileModelConfigurationStore(
            configFileURL: configURL,
            secretStore: secretStore
        )
        let setup = SetupMode(configurationStore: store)

        try setup.save(
            baseURL: URL(string: "https://llm.example.test/v1")!,
            modelName: "test-model",
            apiToken: "sk-test"
        )

        let rawConfig = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertTrue(rawConfig.contains("https://llm.example.test/v1"))
        XCTAssertTrue(rawConfig.contains("test-model"))
        XCTAssertFalse(rawConfig.contains("sk-test"))
        XCTAssertEqual(secretStore.tokens[ModelConfigurationStoreDefaults.apiTokenKey], "sk-test")
    }

    func testConfigLoadCombinesLocalConfigAndSecretToken() throws {
        let secretStore = FakeSecretStore()
        let configURL = temporaryDirectory().appendingPathComponent("model.json")
        let store = FileModelConfigurationStore(
            configFileURL: configURL,
            secretStore: secretStore
        )

        try store.save(ModelConfiguration(
            baseURL: URL(string: "https://llm.example.test/v1")!,
            modelName: "test-model",
            apiToken: "sk-test"
        ))

        XCTAssertEqual(try store.load(), ModelConfiguration(
            baseURL: URL(string: "https://llm.example.test/v1")!,
            modelName: "test-model",
            apiToken: "sk-test"
        ))
    }

    func testMissingModelConfigurationWritesFatalAndRefusesStartup() throws {
        let store = InMemoryModelConfigurationStore(configuration: nil)
        let output = RecordingProtocolOutput()
        let gate = ModelConfigurationGate(configurationStore: store, output: output)

        XCTAssertFalse(try gate.ensureReadyForModelBackedSession())
        XCTAssertEqual(output.renderedBlocks.last, """
        <fatal>
        missing model configuration: base URL, model name, API token
        </fatal>

        """)
    }

    func testCompleteModelConfigurationAllowsStartup() throws {
        let store = InMemoryModelConfigurationStore(configuration: ModelConfiguration(
            baseURL: URL(string: "https://llm.example.test/v1")!,
            modelName: "test-model",
            apiToken: "sk-test"
        ))
        let output = RecordingProtocolOutput()
        let gate = ModelConfigurationGate(configurationStore: store, output: output)

        XCTAssertTrue(try gate.ensureReadyForModelBackedSession())
        XCTAssertTrue(output.renderedBlocks.isEmpty)
    }

    private func temporaryDirectory() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
