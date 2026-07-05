import CryptoKit
import Foundation
import Security

public enum KeyDerivation: Sendable {
    private static let hkdfInfo = Data("PassTrack-vault-key-v1".utf8)

    /// Derives a 256-bit symmetric key from a passphrase and salt using HKDF-SHA256.
    public static func deriveKey(from passphrase: String, salt: Data) -> SymmetricKey {
        let inputKeyMaterial = SymmetricKey(data: Data(passphrase.utf8))
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKeyMaterial,
            salt: salt,
            info: hkdfInfo,
            outputByteCount: 32
        )
    }

    /// Returns 32 bytes of cryptographically random data for use as a salt.
    public static func generateSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    /// Returns a new random 256-bit symmetric key.
    public static func generateDataKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }
}
