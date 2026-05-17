import Foundation
import XCTest
@testable import TwebCore

final class Issue03ModelConfigurationTests: XCTestCase {
    func testSetupModeStoresModelConfigurationInStaticConfigFile() throws {
        let configURL = temporaryDirectory().appendingPathComponent("model.json")
        let store = FileModelConfigurationStore(configFileURL: configURL)
        let setup = SetupMode(configurationStore: store)

        try setup.save(
            baseURL: URL(string: "https://llm.example.test/v1")!,
            modelName: "test-model",
            apiToken: "sk-test"
        )

        let rawConfig = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertTrue(rawConfig.contains("https://llm.example.test/v1"))
        XCTAssertTrue(rawConfig.contains("test-model"))
        XCTAssertTrue(rawConfig.contains("sk-test"))
        XCTAssertTrue(rawConfig.contains(#""reasoning_effort" : "low""#))
        XCTAssertTrue(rawConfig.contains(#""enable_thinking" : false"#))
        XCTAssertTrue(rawConfig.contains(#""clear_thinking" : true"#))
    }

    func testConfigLoadReadsStaticConfigFile() throws {
        let configURL = temporaryDirectory().appendingPathComponent("model.json")
        let store = FileModelConfigurationStore(configFileURL: configURL)

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

    func testConfigLoadReadsRequestOptions() throws {
        let configURL = temporaryDirectory().appendingPathComponent("model.json")
        let store = FileModelConfigurationStore(configFileURL: configURL)

        try store.save(ModelConfiguration(
            baseURL: URL(string: "https://llm.example.test/v1")!,
            modelName: "test-model",
            apiToken: "sk-test",
            requestOptions: ModelConfiguration.lowLatencyRequestOptions
        ))

        XCTAssertEqual(try store.load()?.requestOptions, ModelConfiguration.lowLatencyRequestOptions)
    }

    func testConfigWithoutStaticTokenReportsMissingAPIToken() throws {
        let configURL = temporaryDirectory().appendingPathComponent("model.json")
        try FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(#"{"baseURL":"https://llm.example.test/v1","modelName":"test-model"}"#.utf8)
            .write(to: configURL)
        let store = FileModelConfigurationStore(configFileURL: configURL)

        XCTAssertNil(try store.load())
        XCTAssertEqual(try store.missingRequirements(), ["API token"])
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
