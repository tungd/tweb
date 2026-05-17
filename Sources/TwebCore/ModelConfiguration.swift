import Foundation

public struct ModelConfiguration: Equatable {
    public let baseURL: URL
    public let modelName: String
    public let apiToken: String
    public let requestOptions: [String: JSONValue]

    public static let lowLatencyRequestOptions: [String: JSONValue] = [
        "reasoning_effort": .string("low"),
        "chat_template_kwargs": .object([
            "enable_thinking": .bool(false),
            "clear_thinking": .bool(true)
        ])
    ]

    public init(
        baseURL: URL,
        modelName: String,
        apiToken: String,
        requestOptions: [String: JSONValue] = [:]
    ) {
        self.baseURL = baseURL
        self.modelName = modelName
        self.apiToken = apiToken
        self.requestOptions = requestOptions
    }
}

public enum ModelConfigurationStoreDefaults {
    public static var defaultConfigFileURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("tweb", isDirectory: true)
            .appendingPathComponent("model.json", isDirectory: false)
    }
}

public protocol ModelConfigurationStore {
    func save(_ configuration: ModelConfiguration) throws
    func load() throws -> ModelConfiguration?
    func missingRequirements() throws -> [String]
}

public final class FileModelConfigurationStore: ModelConfigurationStore {
    private struct StoredConfiguration: Codable {
        let baseURL: String
        let modelName: String
        let apiToken: String?
        let requestOptions: [String: JSONValue]?
    }

    private let configFileURL: URL
    private let fileManager: FileManager

    public init(
        configFileURL: URL = ModelConfigurationStoreDefaults.defaultConfigFileURL,
        fileManager: FileManager = .default
    ) {
        self.configFileURL = configFileURL
        self.fileManager = fileManager
    }

    public func save(_ configuration: ModelConfiguration) throws {
        try fileManager.createDirectory(
            at: configFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let stored = StoredConfiguration(
            baseURL: configuration.baseURL.absoluteString,
            modelName: configuration.modelName,
            apiToken: configuration.apiToken,
            requestOptions: configuration.requestOptions.isEmpty ? nil : configuration.requestOptions
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(stored)
        try data.write(to: configFileURL)
    }

    public func load() throws -> ModelConfiguration? {
        guard fileManager.fileExists(atPath: configFileURL.path) else {
            return nil
        }

        let stored = try JSONDecoder().decode(
            StoredConfiguration.self,
            from: try Data(contentsOf: configFileURL)
        )
        guard
            let baseURL = URL(string: stored.baseURL),
            !stored.modelName.isEmpty,
            let apiToken = stored.apiToken,
            !apiToken.isEmpty
        else {
            return nil
        }

        return ModelConfiguration(
            baseURL: baseURL,
            modelName: stored.modelName,
            apiToken: apiToken,
            requestOptions: stored.requestOptions ?? [:]
        )
    }

    public func missingRequirements() throws -> [String] {
        guard fileManager.fileExists(atPath: configFileURL.path) else {
            return ["base URL", "model name", "API token"]
        }

        var missing: [String] = []
        let data = try Data(contentsOf: configFileURL)
        let stored = try JSONDecoder().decode(StoredConfiguration.self, from: data)

        if URL(string: stored.baseURL) == nil || stored.baseURL.isEmpty {
            missing.append("base URL")
        }
        if stored.modelName.isEmpty {
            missing.append("model name")
        }
        if stored.apiToken?.isEmpty ?? true {
            missing.append("API token")
        }
        return missing
    }
}

public final class InMemoryModelConfigurationStore: ModelConfigurationStore {
    public var configuration: ModelConfiguration?

    public init(configuration: ModelConfiguration?) {
        self.configuration = configuration
    }

    public func save(_ configuration: ModelConfiguration) throws {
        self.configuration = configuration
    }

    public func load() throws -> ModelConfiguration? {
        configuration
    }

    public func missingRequirements() throws -> [String] {
        configuration == nil ? ["base URL", "model name", "API token"] : []
    }
}

public final class ModelConfigurationGate {
    private let configurationStore: ModelConfigurationStore
    private let output: ProtocolOutput

    public init(configurationStore: ModelConfigurationStore, output: ProtocolOutput) {
        self.configurationStore = configurationStore
        self.output = output
    }

    public func ensureReadyForModelBackedSession() throws -> Bool {
        guard try configurationStore.load() != nil else {
            let missing = try configurationStore.missingRequirements().joined(separator: ", ")
            output.write(.fatal("missing model configuration: \(missing)"))
            return false
        }

        return true
    }
}

public final class SetupMode {
    private let configurationStore: ModelConfigurationStore

    public init(configurationStore: ModelConfigurationStore) {
        self.configurationStore = configurationStore
    }

    public func save(
        baseURL: URL,
        modelName: String,
        apiToken: String,
        requestOptions: [String: JSONValue] = ModelConfiguration.lowLatencyRequestOptions
    ) throws {
        try configurationStore.save(ModelConfiguration(
            baseURL: baseURL,
            modelName: modelName,
            apiToken: apiToken,
            requestOptions: requestOptions
        ))
    }
}
