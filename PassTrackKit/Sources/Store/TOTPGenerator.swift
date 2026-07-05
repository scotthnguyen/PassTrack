import CryptoKit
import Foundation

public enum TOTPGenerator: Sendable {
    /// Generates a 6-digit TOTP code per RFC 6238 (HMAC-SHA1, 30-second steps).
    public static func generate(secret: String, time: Date = .now) -> String {
        guard let secretData = base32Decode(secret.uppercased()) else { return "------" }

        let counter = UInt64(time.timeIntervalSince1970 / 30).bigEndian
        let counterData = withUnsafeBytes(of: counter) { Data($0) }

        let key = SymmetricKey(data: secretData)
        let mac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key)
        let macBytes = Array(mac)

        let offset = Int(macBytes[19] & 0x0f)
        let truncated =
            (UInt32(macBytes[offset] & 0x7f) << 24) |
            (UInt32(macBytes[offset + 1]) << 16) |
            (UInt32(macBytes[offset + 2]) << 8) |
            UInt32(macBytes[offset + 3])

        let code = truncated % 1_000_000
        return String(format: "%06d", code)
    }

    public static func secondsRemaining(at time: Date = .now) -> Int {
        30 - (Int(time.timeIntervalSince1970) % 30)
    }

    private static func base32Decode(_ input: String) -> Data? {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        var output = Data()
        var buffer: UInt64 = 0
        var bitsLeft = 0

        for char in input {
            guard let value = alphabet.firstIndex(of: char) else {
                if char == "=" || char == " " { continue }
                return nil
            }
            buffer = (buffer << 5) | UInt64(alphabet.distance(from: alphabet.startIndex, to: value))
            bitsLeft += 5
            if bitsLeft >= 8 {
                bitsLeft -= 8
                output.append(UInt8((buffer >> bitsLeft) & 0xff))
            }
        }
        return output.isEmpty ? nil : output
    }
}
