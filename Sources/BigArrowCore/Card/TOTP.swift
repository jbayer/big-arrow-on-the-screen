import CommonCrypto
import Foundation

/// Time-based one-time passwords, RFC 6238 (https://www.rfc-editor.org/rfc/rfc6238) with the
/// defaults every authenticator app uses: HMAC-SHA1, 30-second steps, 6 digits.
public struct TOTP: Equatable, Sendable {
    public let key: Data
    public let digits: Int
    public let period: Double

    public static let defaultDigits = 6
    public static let defaultPeriod: Double = 30

    /// A base32 seed (spaces and case ignored) or an `otpauth://totp/...?secret=...` URI.
    public init(seed: String) throws {
        let trimmed = seed.trimmingCharacters(in: .whitespacesAndNewlines)
        var digits = Self.defaultDigits
        var period = Self.defaultPeriod
        var secret = trimmed
        if trimmed.lowercased().hasPrefix("otpauth://") {
            let items = URLComponents(string: trimmed)?.queryItems ?? []
            let query = Dictionary(items.map { ($0.name.lowercased(), $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
            secret = query["secret"] ?? ""
            digits = query["digits"].flatMap(Int.init) ?? digits
            period = query["period"].flatMap(Double.init) ?? period
        }
        guard let key = Base32.decode(secret), !key.isEmpty, (6...8).contains(digits), period > 0 else {
            throw BigArrowError.badInput("the TOTP seed is not base32 or an otpauth:// URI")
        }
        self.init(key: key, digits: digits, period: period)
    }

    public init(key: Data, digits: Int = defaultDigits, period: Double = defaultPeriod) {
        self.key = key
        self.digits = digits
        self.period = period
    }

    /// The code at `date`, zero-padded.
    public func code(at date: Date) -> String {
        let counter = UInt64(floor(date.timeIntervalSince1970 / period))
        var bigEndian = counter.bigEndian
        let message = Data(bytes: &bigEndian, count: MemoryLayout<UInt64>.size)
        var mac = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        key.withUnsafeBytes { keyBytes in
            message.withUnsafeBytes { messageBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), keyBytes.baseAddress, key.count, messageBytes.baseAddress, message.count, &mac)
            }
        }
        let offset = Int(mac[mac.count - 1] & 0x0F)
        let binary = (UInt32(mac[offset] & 0x7F) << 24) | (UInt32(mac[offset + 1]) << 16)
            | (UInt32(mac[offset + 2]) << 8) | UInt32(mac[offset + 3])
        let modulo = (0..<digits).reduce(UInt32(1)) { value, _ in value * 10 }
        let code = String(binary % modulo)
        return String(repeating: "0", count: digits - code.count) + code
    }

    /// Seconds until the next code.
    public func remaining(at date: Date) -> Double {
        period - date.timeIntervalSince1970.truncatingRemainder(dividingBy: period)
    }
}

/// RFC 4648 base32 without padding requirements, as authenticator seeds are written.
public enum Base32 {
    static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

    public static func decode(_ text: String) -> Data? {
        let clean = text.uppercased().filter { !" -=".contains($0) }
        var bits: UInt64 = 0
        var count = 0
        var bytes: [UInt8] = []
        for character in clean {
            guard let index = alphabet.firstIndex(of: character) else { return nil }
            bits = (bits << 5) | UInt64(index)
            count += 5
            if count >= 8 {
                count -= 8
                bytes.append(UInt8((bits >> UInt64(count)) & 0xFF))
            }
        }
        return Data(bytes)
    }
}
