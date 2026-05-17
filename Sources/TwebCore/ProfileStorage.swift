import Foundation

public enum ProfileStorageKind: String, Codable, Equatable {
    case webkitWebsiteDataStore
}

public struct PersistentProfile: Codable, Equatable {
    public let name: String
    public let storeUUID: UUID
    public let storageKind: ProfileStorageKind

    public init(
        name: String,
        storeUUID: UUID,
        storageKind: ProfileStorageKind = .webkitWebsiteDataStore
    ) {
        self.name = name
        self.storeUUID = storeUUID
        self.storageKind = storageKind
    }
}

public enum SessionStorage: Equatable {
    case ephemeral
    case persistent(PersistentProfile)
}

public final class ProfileRegistry {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL = ProfileRegistry.defaultFileURL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public static var defaultFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("tweb", isDirectory: true)
            .appendingPathComponent("profiles.json", isDirectory: false)
    }

    public func profile(named name: String) throws -> PersistentProfile {
        var profiles = try loadProfiles()
        if let existing = profiles[name] {
            return existing
        }

        let profile = PersistentProfile(name: name, storeUUID: UUID())
        profiles[name] = profile
        try saveProfiles(profiles)
        return profile
    }

    private func loadProfiles() throws -> [String: PersistentProfile] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return [:]
        }
        return try JSONDecoder().decode(
            [String: PersistentProfile].self,
            from: try Data(contentsOf: fileURL)
        )
    }

    private func saveProfiles(_ profiles: [String: PersistentProfile]) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(profiles).write(to: fileURL)
    }
}

public final class ProfileSelector {
    private let registry: ProfileRegistry

    public init(registry: ProfileRegistry) {
        self.registry = registry
    }

    public func storage(forProfileName name: String?) throws -> SessionStorage {
        guard let name, !name.isEmpty else {
            return .ephemeral
        }
        return .persistent(try registry.profile(named: name))
    }
}

public enum SessionVisibility: Equatable {
    case hidden
    case visible
}

public protocol ManualProfileSession {
    func open(profile: PersistentProfile, visibility: SessionVisibility) throws
}

public enum ManualModeError: Error, Equatable, CustomStringConvertible {
    case missingProfileName

    public var description: String {
        "manual mode requires --profile <name>"
    }
}

public final class ManualMode {
    private let registry: ProfileRegistry
    private let session: ManualProfileSession

    public init(registry: ProfileRegistry, session: ManualProfileSession) {
        self.registry = registry
        self.session = session
    }

    public func run(profileName: String?) throws {
        guard let profileName, !profileName.isEmpty else {
            throw ManualModeError.missingProfileName
        }
        let profile = try registry.profile(named: profileName)
        try session.open(profile: profile, visibility: .visible)
    }
}
