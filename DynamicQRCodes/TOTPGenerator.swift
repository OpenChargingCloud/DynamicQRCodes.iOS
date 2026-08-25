import Foundation
import CryptoKit

enum TOTPError: LocalizedError, Equatable {

    case emptySecret
    case secretContainsWhitespace
    case secretTooShort
    case invalidValidityTime
    case invalidTOTPLength
    case negativeTimestamp
    case emptyAlphabet
    case alphabetTooShort
    case duplicateAlphabetChars
    case alphabetContainsWhitespace

    var errorDescription: String? {
        switch self {
        case .emptySecret:                return "The shared secret must not be empty!"
        case .secretContainsWhitespace:   return "The shared secret must not contain whitespace!"
        case .secretTooShort:             return "The shared secret must be at least 16 characters!"
        case .invalidValidityTime:        return "The validity time must be a positive number of seconds!"
        case .invalidTOTPLength:          return "The TOTP length must be between 4 and 255!"
        case .negativeTimestamp:          return "The timestamp must be a non-negative Unix timestamp in milliseconds!"
        case .emptyAlphabet:              return "The alphabet must not be empty!"
        case .alphabetTooShort:           return "The alphabet must contain at least 4 characters!"
        case .duplicateAlphabetChars:     return "The alphabet must not contain duplicate characters!"
        case .alphabetContainsWhitespace: return "The alphabet must not contain whitespace!"
        }
    }

}

enum TOTPValidation: String, Equatable, Sendable {
    case previous
    case current
    case next
    case invalid

    var isValid: Bool { self != .invalid }
}

struct TOTPGenerator {

    static func generateRandomSecret(length: Int = 16) -> String {
        guard length > 0 else { return "" }

        let allowedCharacters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_+!$%&/()=?@#*")
        var generator = SystemRandomNumberGenerator()

        return String((0..<length).map { _ in
            allowedCharacters[Int.random(in: allowedCharacters.indices, using: &generator)]
        })
    }

    static func generate(
        sharedSecret:  String,
        validityTime:  UInt32   = 30,
        totpLength:    UInt32   = 12,
        alphabet:      String   = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
        timestamp:     Int64?   = nil
    ) throws -> TOTPResult {

        let secret          = sharedSecret.trimmingCharacters(in: .whitespaces)
        let alphabetTrimmed = alphabet.trimmingCharacters(in: .whitespaces)

        // Validation (matches Android version)
        guard !secret.isEmpty else {
            throw TOTPError.emptySecret
        }
        guard !secret.contains(where: { $0.isWhitespace }) else {
            throw TOTPError.secretContainsWhitespace
        }
        guard secret.count >= 16 else {
            throw TOTPError.secretTooShort
        }
        guard validityTime > 0 else {
            throw TOTPError.invalidValidityTime
        }
        guard totpLength >= 4 && totpLength <= 255 else {
            throw TOTPError.invalidTOTPLength
        }
        if let timestamp, timestamp < 0 {
            throw TOTPError.negativeTimestamp
        }
        guard !alphabetTrimmed.isEmpty else {
            throw TOTPError.emptyAlphabet
        }
        guard alphabetTrimmed.count >= 4 else {
            throw TOTPError.alphabetTooShort
        }
        guard Set(alphabetTrimmed).count == alphabetTrimmed.count else {
            throw TOTPError.duplicateAlphabetChars
        }
        guard !alphabetTrimmed.contains(where: { $0.isWhitespace }) else {
            throw TOTPError.alphabetContainsWhitespace
        }

        let currentUnixTime = (timestamp ?? Int64(Date().timeIntervalSince1970 * 1000)) / 1000
        let validityTimeInt = Int64(validityTime)
        let currentSlot     = currentUnixTime / validityTimeInt
        let remainingTime   = UInt64(validityTimeInt - (currentUnixTime % validityTimeInt))

        let previous = calcTOTPSlot(slot: currentSlot - 1,
                                    totpLength: Int(totpLength),
                                    alphabet: alphabetTrimmed,
                                    sharedSecret: secret)

        let current  = calcTOTPSlot(slot: currentSlot,
                                    totpLength: Int(totpLength),
                                    alphabet: alphabetTrimmed,
                                    sharedSecret: secret)

        let next     = calcTOTPSlot(slot: currentSlot + 1,
                                    totpLength: Int(totpLength),
                                    alphabet: alphabetTrimmed,
                                    sharedSecret: secret)

        return TOTPResult(
            previous: previous,
            current: current,
            next: next,
            remainingTime: remainingTime
        )

    }

    // MARK: - Private

    private static func calcTOTPSlot(
        slot:         Int64,
        totpLength:   Int,
        alphabet:     String,
        sharedSecret: String
    ) -> String {

        // OCPP 2.1 C25 TOTP algorithm version 1 hashes the time interval as
        // an eight-byte, big-endian signed integer on every architecture.
        var slotValue = slot.bigEndian
        let slotData = withUnsafeBytes(of: &slotValue) { Data($0) }

        // HMAC-SHA256
        let key  = SymmetricKey(data: Data(sharedSecret.utf8))
        let hmac = HMAC<SHA256>.authenticationCode(for: slotData, using: key)
        let hash = Array(hmac)

        // Dynamic binary code extraction
        let offset        = Int(hash[hash.count - 1] & 0x0F)
        let alphabetArray = Array(alphabet)
        var result        = ""

        for i in 0..<totpLength {
            let byteIndex = (offset + i) % hash.count
            let charIndex = Int(hash[byteIndex] & 0xFF) % alphabetArray.count
            result.append(alphabetArray[charIndex])
        }

        return result

    }

    static func validate(
        _ totp: String,
        sharedSecret: String,
        validityTime: UInt32 = 30,
        totpLength: UInt32 = 12,
        alphabet: String = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
        timestamp: Int64? = nil
    ) throws -> TOTPValidation {
        let expected = try generate(
            sharedSecret: sharedSecret,
            validityTime: validityTime,
            totpLength: totpLength,
            alphabet: alphabet,
            timestamp: timestamp
        )

        if timingSafeEqual(totp, expected.current) { return .current }
        if timingSafeEqual(totp, expected.previous) { return .previous }
        if timingSafeEqual(totp, expected.next) { return .next }
        return .invalid
    }

    private static func timingSafeEqual(_ lhs: String, _ rhs: String) -> Bool {
        let lhsBytes = Array(lhs.utf8)
        let rhsBytes = Array(rhs.utf8)
        let comparedCount = max(lhsBytes.count, rhsBytes.count)
        var difference = lhsBytes.count ^ rhsBytes.count

        for index in 0..<comparedCount {
            let lhsByte = index < lhsBytes.count ? lhsBytes[index] : 0
            let rhsByte = index < rhsBytes.count ? rhsBytes[index] : 0
            difference |= Int(lhsByte ^ rhsByte)
        }

        return difference == 0
    }

}
