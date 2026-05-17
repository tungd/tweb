import Foundation
#if canImport(Security)
import Security
#endif

public protocol SecretStore {
    func saveSecret(_ value: String, forKey key: String) throws
    func readSecret(forKey key: String) throws -> String?
}

public enum SecretStoreError: Error, CustomStringConvertible {
    case unimplemented
    case keychainStatus(OSStatus)
    case invalidData

    public var description: String {
        switch self {
        case .unimplemented:
            return "platform secret store is not available"
        case .keychainStatus(let status):
            return "keychain operation failed: \(status)"
        case .invalidData:
            return "keychain returned invalid data"
        }
    }
}

public final class KeychainSecretStore: SecretStore {
    private let service: String

    public init(service: String = "tweb") {
        self.service = service
    }

    public func saveSecret(_ value: String, forKey key: String) throws {
        #if canImport(Security)
        let data = Data(value.utf8)
        var query = baseQuery(forKey: key)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecretStoreError.keychainStatus(status)
        }
        #else
        throw SecretStoreError.unimplemented
        #endif
    }

    public func readSecret(forKey key: String) throws -> String? {
        #if canImport(Security)
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw SecretStoreError.keychainStatus(status)
        }
        guard
            let data = result as? Data,
            let value = String(data: data, encoding: .utf8)
        else {
            throw SecretStoreError.invalidData
        }
        return value
        #else
        throw SecretStoreError.unimplemented
        #endif
    }

    private func baseQuery(forKey key: String) -> [String: Any] {
        #if canImport(Security)
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        #else
        return [:]
        #endif
    }
}
