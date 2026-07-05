import CryptoKit
import Foundation

public enum VaultCryptoError: Error, Sendable {
    case sealFailed
    case invalidCombinedData
}

public enum VaultCrypto: Sendable {
    /// Encrypts data using AES-GCM. Returns nonce + ciphertext + tag as a single blob.
    public static func encrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw VaultCryptoError.sealFailed
        }
        return combined
    }

    public static func decrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    public static func encrypt(_ string: String, using key: SymmetricKey) throws -> Data {
        try encrypt(Data(string.utf8), using: key)
    }

    public static func decryptString(_ data: Data, using key: SymmetricKey) throws -> String {
        let plaintext = try decrypt(data, using: key)
        guard let string = String(data: plaintext, encoding: .utf8) else {
            throw VaultCryptoError.invalidCombinedData
        }
        return string
    }
}
