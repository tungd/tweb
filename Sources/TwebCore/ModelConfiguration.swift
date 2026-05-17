import Foundation

public struct ModelConfiguration: Equatable {
    public let baseURL: URL
    public let modelName: String
    public let apiToken: String

    public init(baseURL: URL, modelName: String, apiToken: String) {
        self.baseURL = baseURL
        self.modelName = modelName
        self.apiToken = apiToken
    }
}

public enum ModelConfigurationStoreDefaults {
    public static let apiTokenKey = "tweb.model.apiToken"

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
    }

    private let configFileURL: URL
    private let secretStore: SecretStore
    private let fileManager: FileManager

    public init(
        configFileURL: URL = ModelConfigurationStoreDefaults.defaultConfigFileURL,
        secretStore: SecretStore = KeychainSecretStore(),
        fileManager: FileManager = .default
    ) {
        self.configFileURL = configFileURL
        self.secretStore = secretStore
        self.fileManager = fileManager
    }

    public func save(_ configuration: ModelConfiguration) throws {
        try fileManager.createDirectory(
            at: configFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let stored = StoredConfiguration(
            baseURL: configuration.baseURL.absoluteString,
            modelName: configuration.modelName
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let data = try encoder.encode(stored)
        try data.write(to: configFileURL)
        try secretStore.saveSecret(
            configuration.apiToken,
            forKey: ModelConfigurationStoreDefaults.apiTokenKey
        )
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
            let token = try secretStore.readSecret(forKey: ModelConfigurationStoreDefaults.apiTokenKey),
            !stored.modelName.isEmpty,
            !token.isEmpty
        else {
            return nil
        }

        return ModelConfiguration(
            baseURL: baseURL,
            modelName: stored.modelName,
            apiToken: token
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
        let token = try secretStore.readSecret(forKey: ModelConfigurationStoreDefaults.apiTokenKey)
        if token?.isEmpty ?? true {
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

    public func save(baseURL: URL, modelName: String, apiToken: String) throws {
        try configurationStore.save(ModelConfiguration(
            baseURL: baseURL,
            modelName: modelName,
            apiToken: apiToken
        ))
    }
}
