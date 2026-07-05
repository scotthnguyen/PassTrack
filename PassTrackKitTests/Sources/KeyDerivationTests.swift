import CryptoKit
import Foundation
import Testing

@testable import PassTrackKit

@Suite("KeyDerivation")
struct KeyDerivationTests {
    @Test("same passphrase and salt produces same key")
    func deterministicDerivation() {
        let passphrase = "my-secure-passphrase"
        let salt = KeyDerivation.generateSalt()

        let key1 = KeyDerivation.deriveKey(from: passphrase, salt: salt)
        let key2 = KeyDerivation.deriveKey(from: passphrase, salt: salt)

        let k1Bytes = key1.withUnsafeBytes { Data($0) }
        let k2Bytes = key2.withUnsafeBytes { Data($0) }
        #expect(k1Bytes == k2Bytes)
    }

    @Test("different passphrases produce different keys")
    func differentPassphrasesProduceDifferentKeys() {
        let salt = KeyDerivation.generateSalt()

        let key1 = KeyDerivation.deriveKey(from: "passphrase-one", salt: salt)
        let key2 = KeyDerivation.deriveKey(from: "passphrase-two", salt: salt)

        let k1Bytes = key1.withUnsafeBytes { Data($0) }
        let k2Bytes = key2.withUnsafeBytes { Data($0) }
        #expect(k1Bytes != k2Bytes)
    }

    @Test("different salts produce different keys")
    func differentSaltsProduceDifferentKeys() {
        let passphrase = "same-passphrase"

        let key1 = KeyDerivation.deriveKey(from: passphrase, salt: KeyDerivation.generateSalt())
        let key2 = KeyDerivation.deriveKey(from: passphrase, salt: KeyDerivation.generateSalt())

        let k1Bytes = key1.withUnsafeBytes { Data($0) }
        let k2Bytes = key2.withUnsafeBytes { Data($0) }
        #expect(k1Bytes != k2Bytes)
    }

    @Test("derived key is 256 bits")
    func derivedKeyLength() {
        let key = KeyDerivation.deriveKey(from: "passphrase", salt: KeyDerivation.generateSalt())
        let keyBytes = key.withUnsafeBytes { Data($0) }
        #expect(keyBytes.count == 32)
    }

    @Test("salt is 32 bytes")
    func saltLength() {
        let salt = KeyDerivation.generateSalt()
        #expect(salt.count == 32)
    }

    @Test("derived key can encrypt and decrypt successfully")
    func derivedKeyCanEncryptDecrypt() throws {
        let passphrase = "test-passphrase"
        let salt = KeyDerivation.generateSalt()
        let key = KeyDerivation.deriveKey(from: passphrase, salt: salt)

        let original = "top-secret-data"
        let encrypted = try VaultCrypto.encrypt(original, using: key)
        let decrypted = try VaultCrypto.decryptString(encrypted, using: key)

        #expect(decrypted == original)
    }
}
