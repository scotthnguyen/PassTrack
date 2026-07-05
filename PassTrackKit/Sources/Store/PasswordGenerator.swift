import Foundation
import Security

public enum PasswordStyle: String, CaseIterable, Sendable {
    case random = "Random"
    case pronounceable = "Pronounceable"
    case passphrase = "Passphrase"
}

public struct PasswordOptions: Sendable {
    public var length: Int = 20
    public var style: PasswordStyle = .random
    public var includeUppercase: Bool = true
    public var includeLowercase: Bool = true
    public var includeNumbers: Bool = true
    public var includeSymbols: Bool = false
    public var wordCount: Int = 4

    public init() {}
}

public enum PasswordGenerator: Sendable {
    public static func generate(options: PasswordOptions = .init()) -> String {
        switch options.style {
        case .random: return generateRandom(options: options)
        case .pronounceable: return generatePronounceable(length: options.length)
        case .passphrase: return generatePassphrase(wordCount: options.wordCount)
        }
    }

    public static func strength(of password: String) -> PasswordStrength {
        let length = password.count
        let hasUpper = password.contains { $0.isUppercase }
        let hasLower = password.contains { $0.isLowercase }
        let hasNumber = password.contains { $0.isNumber }
        let hasSymbol = password.contains { !$0.isLetter && !$0.isNumber }

        var score = 0
        if length >= 8 { score += 1 }
        if length >= 14 { score += 1 }
        if length >= 20 { score += 1 }
        if hasUpper { score += 1 }
        if hasLower { score += 1 }
        if hasNumber { score += 1 }
        if hasSymbol { score += 1 }

        switch score {
        case 0...2: return .weak
        case 3...4: return .fair
        case 5...6: return .strong
        default: return .veryStrong
        }
    }

    private static func generateRandom(options: PasswordOptions) -> String {
        var charset = ""
        if options.includeLowercase { charset += "abcdefghijklmnopqrstuvwxyz" }
        if options.includeUppercase { charset += "ABCDEFGHIJKLMNOPQRSTUVWXYZ" }
        if options.includeNumbers { charset += "0123456789" }
        if options.includeSymbols { charset += "!@#$%^&*()-_=+[]{}|;:,.<>?" }
        guard !charset.isEmpty else { return "" }

        let chars = Array(charset)
        var bytes = [UInt8](repeating: 0, count: options.length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return String(bytes.map { chars[Int($0) % chars.count] })
    }

    private static func generatePronounceable(length: Int) -> String {
        let consonants = Array("bcdfghjklmnpqrstvwxyz")
        let vowels = Array("aeiou")
        var result = ""
        var bytes = [UInt8](repeating: 0, count: length * 2)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        var idx = 0
        while result.count < length {
            result.append(consonants[Int(bytes[idx]) % consonants.count])
            idx += 1
            if result.count < length {
                result.append(vowels[Int(bytes[idx]) % vowels.count])
                idx += 1
            }
        }
        return String(result.prefix(length))
    }

    private static func generatePassphrase(wordCount: Int) -> String {
        let words = [
            "apple", "beach", "cloud", "dance", "eagle", "flame", "grace", "heart",
            "ivory", "jewel", "karma", "lotus", "magic", "night", "ocean", "pearl",
            "quiet", "river", "stone", "tiger", "ultra", "vivid", "water", "xenon",
            "yacht", "zebra", "amber", "blaze", "cedar", "delta", "ember", "frost",
            "gloom", "haven", "inlet", "joker", "kneel", "lemon", "maple", "noble"
        ]
        var bytes = [UInt8](repeating: 0, count: wordCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { words[Int($0) % words.count] }.joined(separator: "-")
    }
}

public enum PasswordStrength: String, Sendable {
    case weak = "Weak"
    case fair = "Fair"
    case strong = "Strong"
    case veryStrong = "Very Strong"

    public var accessibilityDescription: String {
        switch self {
        case .weak: return "Weak — easy to guess, change it"
        case .fair: return "Fair — consider making it longer"
        case .strong: return "Strong password"
        case .veryStrong: return "Very strong password"
        }
    }

    public var symbolName: String {
        switch self {
        case .weak: return "xmark.shield"
        case .fair: return "exclamationmark.shield"
        case .strong: return "checkmark.shield"
        case .veryStrong: return "checkmark.shield.fill"
        }
    }
}
