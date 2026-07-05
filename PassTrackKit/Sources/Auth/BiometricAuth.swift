import CryptoKit
import Foundation
import LocalAuthentication
import Security

public enum BiometricAuthError: Error, Sendable {
    case notAvailable
    case setupRequired
    case authFailed
    case keychainError(OSStatus)
    case dataCorrupted
}

/// Manages the vault unlock flows: biometric (Keychain + Secure Enclave) and passphrase.
public enum BiometricAuth: Sendable {
    private static let service = "com.scottnguyen.passtrack"
    private static let biometricAccount = "vault.datakey.biometric"
    private static let passphraseAccount = "vault.datakey.passphrase"
    private static let saltAccount = "vault.passphrase.salt"
    private static let accessGroup = "com.scottnguyen.passtrack"

    // MARK: - Setup

    public static var isSetUp: Bool {
        let query: NSDictionary = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: saltAccount,
            kSecReturnData: false
        ]
        return SecItemCopyMatching(query, nil) == errSecSuccess
    }

    /// First-launch setup: generates the data key and stores it under both unlock paths.
    /// Returns the data key so the store can be unlocked immediately after setup.
    public static func setup(passphrase: String) throws -> SymmetricKey {
        let dataKey = KeyDerivation.generateDataKey()

        try storeForBiometrics(dataKey)
        try storeForPassphrase(dataKey, passphrase: passphrase)

        return dataKey
    }

    // MARK: - Unlock

    public static func unlockWithBiometrics(reason: String = "Unlock PassTrack") async throws -> SymmetricKey {
        let context = LAContext()
        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &policyError) else {
            throw BiometricAuthError.notAvailable
        }

        do {
            try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch {
            throw BiometricAuthError.authFailed
        }

        return try retrieveBiometricKey(context: context)
    }

    public static func unlock(passphrase: String) throws -> SymmetricKey {
        let salt = try retrieveSalt()
        let wrappedKey = try retrievePassphraseWrappedKey()
        let wrappingKey = KeyDerivation.deriveKey(from: passphrase, salt: salt)
        let keyData = try VaultCrypto.decrypt(wrappedKey, using: wrappingKey)
        return SymmetricKey(data: keyData)
    }

    // MARK: - Private helpers

    private static func storeForBiometrics(_ key: SymmetricKey) throws {
        var cfError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryAny,
            &cfError
        ) else {
            throw cfError!.takeRetainedValue() as Error
        }

        let keyData = key.withUnsafeBytes { Data($0) }
        let query: NSDictionary = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: biometricAccount,
            kSecAttrAccessGroup: accessGroup,
            kSecValueData: keyData,
            kSecAttrAccessControl: access
        ]
        SecItemDelete(query)
        let status = SecItemAdd(query, nil)
        guard status == errSecSuccess else { throw BiometricAuthError.keychainError(status) }
    }

    private static func storeForPassphrase(_ key: SymmetricKey, passphrase: String) throws {
        let salt = KeyDerivation.generateSalt()
        let wrappingKey = KeyDerivation.deriveKey(from: passphrase, salt: salt)
        let keyData = key.withUnsafeBytes { Data($0) }
        let wrappedKey = try VaultCrypto.encrypt(keyData, using: wrappingKey)

        try storeKeychainItem(account: saltAccount, data: salt)
        try storeKeychainItem(account: passphraseAccount, data: wrappedKey)
    }

    private static func storeKeychainItem(account: String, data: Data) throws {
        let query: NSDictionary = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessGroup: accessGroup,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query)
        let status = SecItemAdd(query, nil)
        guard status == errSecSuccess else { throw BiometricAuthError.keychainError(status) }
    }

    private static func retrieveBiometricKey(context: LAContext) throws -> SymmetricKey {
        let query: NSDictionary = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: biometricAccount,
            kSecAttrAccessGroup: accessGroup,
            kSecReturnData: true,
            kSecUseAuthenticationContext: context
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw BiometricAuthError.keychainError(status)
        }
        return SymmetricKey(data: data)
    }

    private static func retrieveSalt() throws -> Data {
        try retrieveKeychainData(account: saltAccount)
    }

    private static func retrievePassphraseWrappedKey() throws -> Data {
        try retrieveKeychainData(account: passphraseAccount)
    }

    private static func retrieveKeychainData(account: String) throws -> Data {
        let query: NSDictionary = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessGroup: accessGroup,
            kSecReturnData: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw BiometricAuthError.keychainError(status)
        }
        return data
    }
}
