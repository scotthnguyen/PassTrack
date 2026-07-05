import CryptoKit
import Foundation
import Security

public enum SecureEnclaveKeyError: Error, Sendable {
    case creationFailed(CFError)
    case encryptionFailed(CFError)
    case decryptionFailed(CFError)
    case publicKeyUnavailable
    case notAvailable
}

/// Wraps and unwraps the vault data key using a P-256 key held in the Secure Enclave.
/// The private key is non-exportable and requires biometric auth to use for decryption.
public final class SecureEnclaveKey: Sendable {
    private static let tag = "com.scottnguyen.passtrack.sekey".data(using: .utf8)!
    private static let algorithm = SecKeyAlgorithm.eciesEncryptionStandardX963SHA256AESGCM

    /// Creates a new non-exportable P-256 key in the Secure Enclave.
    /// This key requires biometric authentication to decrypt (unwrap) with.
    public static func create() throws -> SecKey {
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryAny],
            &error
        ) else {
            throw SecureEnclaveKeyError.creationFailed(error!.takeRetainedValue())
        }

        let attributes: NSDictionary = [
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits: 256,
            kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs: [
                kSecAttrIsPermanent: true,
                kSecAttrApplicationTag: tag,
                kSecAttrAccessControl: access
            ]
        ]

        guard let key = SecKeyCreateRandomKey(attributes, &error) else {
            throw SecureEnclaveKeyError.creationFailed(error!.takeRetainedValue())
        }
        return key
    }

    /// Loads an existing SE key from the Secure Enclave.
    public static func load() throws -> SecKey {
        let query: NSDictionary = [
            kSecClass: kSecClassKey,
            kSecAttrApplicationTag: tag,
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)
        guard status == errSecSuccess, let key = result else {
            throw SecureEnclaveKeyError.notAvailable
        }
        return key as! SecKey
    }

    public static func createOrLoad() throws -> SecKey {
        if let key = try? load() { return key }
        return try create()
    }

    /// Encrypts the data key using the SE public key (no biometric required to encrypt).
    public static func wrap(_ dataKey: SymmetricKey, using privateKey: SecKey) throws -> Data {
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw SecureEnclaveKeyError.publicKeyUnavailable
        }
        let keyData = dataKey.withUnsafeBytes { Data($0) }
        var error: Unmanaged<CFError>?
        guard let encrypted = SecKeyCreateEncryptedData(publicKey, algorithm, keyData as CFData, &error) else {
            throw SecureEnclaveKeyError.encryptionFailed(error!.takeRetainedValue())
        }
        return encrypted as Data
    }

    /// Decrypts the wrapped data key using the SE private key. Triggers biometric auth.
    public static func unwrap(_ wrappedKey: Data, using privateKey: SecKey) throws -> SymmetricKey {
        var error: Unmanaged<CFError>?
        guard let decrypted = SecKeyCreateDecryptedData(privateKey, algorithm, wrappedKey as CFData, &error) else {
            throw SecureEnclaveKeyError.decryptionFailed(error!.takeRetainedValue())
        }
        return SymmetricKey(data: decrypted as Data)
    }
}
