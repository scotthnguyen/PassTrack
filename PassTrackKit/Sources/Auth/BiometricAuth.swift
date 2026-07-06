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
    case invalidRecoveryCode
}

public struct VaultSetupResult: Sendable {
    public let dataKey: SymmetricKey
    public let recoveryCode: String
}

/// Manages the vault unlock flows: biometric (Keychain + Secure Enclave), passphrase, and recovery code.
public enum BiometricAuth: Sendable {
    private static let service = "com.scottnguyen.passtrack"
    private static let biometricAccount = "vault.datakey.biometric"
    private static let passphraseAccount = "vault.datakey.passphrase"
    private static let saltAccount = "vault.passphrase.salt"
    private static let recoveryWrappedKeyAccount = "vault.datakey.recovery"
    private static let recoverySaltAccount = "vault.recovery.salt"

    // Unambiguous uppercase alphanumeric — no 0/O, 1/I/L
    private static let safeAlphabet = Array("23456789ABCDEFGHJKLMNPQRSTUVWXYZ")

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

    /// First-launch setup. Returns the data key (for immediate unlock) and a recovery code
    /// the user must write down. The recovery code is the only way back in if both Face ID
    /// and the passphrase are unavailable.
    public static func setup(passphrase: String) throws -> VaultSetupResult {
        let dataKey = KeyDerivation.generateDataKey()
        let recoveryCode = generateRecoveryCode()

        try storeForBiometrics(dataKey)
        try storeForPassphrase(dataKey, passphrase: passphrase)
        try storeForRecoveryCode(dataKey, recoveryCode: recoveryCode)

        return VaultSetupResult(dataKey: dataKey, recoveryCode: recoveryCode)
    }

    // MARK: - Reset

    /// Deletes all PassTrack Keychain entries. Call this only during a full vault reset.
    public static func deleteAllKeys() {
        let accounts = [
            biometricAccount, passphraseAccount, saltAccount,
            recoveryWrappedKeyAccount, recoverySaltAccount
        ]
        for account in accounts {
            let query: NSDictionary = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account
            ]
            SecItemDelete(query)
        }
    }

    // MARK: - Change passphrase

    /// Re-wraps the existing data key with a new passphrase. The data key — and all
    /// encrypted vault data — is untouched; only the passphrase-derived wrapper changes.
    public static func changePassphrase(currentKey: SymmetricKey, newPassphrase: String) throws {
        try storeForPassphrase(currentKey, passphrase: newPassphrase)
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

    /// Unlocks using the recovery code generated at signup. Strips dashes and
    /// normalises to uppercase before deriving the key — so formatting doesn't matter.
    public static func unlock(recoveryCode: String) throws -> SymmetricKey {
        let normalized = recoveryCode.uppercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
        guard !normalized.isEmpty else { throw BiometricAuthError.invalidRecoveryCode }

        let salt = try retrieveKeychainData(account: recoverySaltAccount)
        let wrappedKey = try retrieveKeychainData(account: recoveryWrappedKeyAccount)
        let wrappingKey = KeyDerivation.deriveKey(from: normalized, salt: salt)

        do {
            let keyData = try VaultCrypto.decrypt(wrappedKey, using: wrappingKey)
            return SymmetricKey(data: keyData)
        } catch {
            throw BiometricAuthError.invalidRecoveryCode
        }
    }

    // MARK: - Private helpers

    private static func generateRecoveryCode() -> String {
        var bytes = [UInt8](repeating: 0, count: 25)
        _ = SecRandomCopyBytes(kSecRandomDefault, 25, &bytes)
        let chars = bytes.map { safeAlphabet[Int($0) % safeAlphabet.count] }
        let raw = String(chars)
        // Format: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
        return stride(from: 0, to: 25, by: 5).map { offset in
            let start = raw.index(raw.startIndex, offsetBy: offset)
            let end = raw.index(start, offsetBy: 5)
            return String(raw[start..<end])
        }.joined(separator: "-")
    }

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

    private static func storeForRecoveryCode(_ key: SymmetricKey, recoveryCode: String) throws {
        let normalized = recoveryCode.replacingOccurrences(of: "-", with: "")
        let salt = KeyDerivation.generateSalt()
        let wrappingKey = KeyDerivation.deriveKey(from: normalized, salt: salt)
        let keyData = key.withUnsafeBytes { Data($0) }
        let wrappedKey = try VaultCrypto.encrypt(keyData, using: wrappingKey)

        try storeKeychainItem(account: recoverySaltAccount, data: salt)
        try storeKeychainItem(account: recoveryWrappedKeyAccount, data: wrappedKey)
    }

    private static func storeKeychainItem(account: String, data: Data) throws {
        let query: NSDictionary = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
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
