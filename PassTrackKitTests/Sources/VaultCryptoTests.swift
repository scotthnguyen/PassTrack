import CryptoKit
import Foundation
import Testing

@testable import PassTrackKit

@Suite("VaultCrypto")
struct VaultCryptoTests {
    @Test("encrypt then decrypt round-trips correctly")
    func encryptDecryptRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let original = "supersecret_password_123!"

        let encrypted = try VaultCrypto.encrypt(original, using: key)
        let decrypted = try VaultCrypto.decryptString(encrypted, using: key)

        #expect(decrypted == original)
    }

    @Test("ciphertext differs from plaintext")
    func ciphertextDiffersFromPlaintext() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("hello world".utf8)

        let ciphertext = try VaultCrypto.encrypt(plaintext, using: key)

        #expect(ciphertext != plaintext)
    }

    @Test("wrong key fails to decrypt")
    func wrongKeyFailsDecryption() throws {
        let key1 = SymmetricKey(size: .bits256)
        let key2 = SymmetricKey(size: .bits256)
        let original = Data("secret".utf8)

        let encrypted = try VaultCrypto.encrypt(original, using: key1)

        #expect(throws: (any Error).self) {
            try VaultCrypto.decrypt(encrypted, using: key2)
        }
    }

    @Test("each encryption produces unique ciphertext (random nonce)")
    func uniqueNoncePerEncryption() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = "same plaintext"

        let c1 = try VaultCrypto.encrypt(plaintext, using: key)
        let c2 = try VaultCrypto.encrypt(plaintext, using: key)

        #expect(c1 != c2)
    }

    @Test("encrypt empty string succeeds")
    func encryptEmptyString() throws {
        let key = SymmetricKey(size: .bits256)
        let encrypted = try VaultCrypto.encrypt("", using: key)
        let decrypted = try VaultCrypto.decryptString(encrypted, using: key)
        #expect(decrypted == "")
    }

    @Test("large payload round-trips")
    func largePayloadRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let large = String(repeating: "a", count: 100_000)

        let encrypted = try VaultCrypto.encrypt(large, using: key)
        let decrypted = try VaultCrypto.decryptString(encrypted, using: key)

        #expect(decrypted == large)
    }
}
