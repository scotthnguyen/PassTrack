import Foundation
import Testing

@testable import PassTrackKit

@Suite("PasswordGenerator")
struct PasswordGeneratorTests {
    @Test("generated password meets length requirement")
    func lengthIsRespected() {
        for length in [8, 14, 20, 32, 64] {
            var options = PasswordOptions()
            options.length = length
            let password = PasswordGenerator.generate(options: options)
            #expect(password.count == length, "Expected length \(length), got \(password.count)")
        }
    }

    @Test("consecutive generations differ")
    func consecutiveGenerationsDiffer() {
        let p1 = PasswordGenerator.generate()
        let p2 = PasswordGenerator.generate()
        #expect(p1 != p2)
    }

    @Test("passphrase contains word-count words")
    func passphraseWordCount() {
        for count in [3, 4, 5, 6] {
            var options = PasswordOptions()
            options.style = .passphrase
            options.wordCount = count
            let passphrase = PasswordGenerator.generate(options: options)
            let wordCount = passphrase.components(separatedBy: "-").count
            #expect(wordCount == count)
        }
    }

    @Test("weak passwords are rated weak")
    func weakPasswordRating() {
        #expect(PasswordGenerator.strength(of: "abc") == .weak)
        #expect(PasswordGenerator.strength(of: "password") == .weak)
    }

    @Test("long mixed password is strong or very strong")
    func strongPasswordRating() {
        let strength = PasswordGenerator.strength(of: "X7kP!mQz9nLr#vW2")
        #expect(strength == .strong || strength == .veryStrong)
    }
}
