import Foundation
import CryptoKit

enum TOTPError: LocalizedError {

    case emptySecret
    case secretContainsWhitespace
    case secretTooShort
    case invalidTOTPLength
    case emptyAlphabet
    case alphabetTooShort
    case duplicateAlphabetChars
    case alphabetContainsWhitespace

    var errorDescription: String? {
        switch self {
        case .emptySecret:                return "The shared secret must not be empty!"
        case .secretContainsWhitespace:   return "The shared secret must not contain whitespace!"
        case .secretTooShort:             return "The shared secret must be at least 16 characters!"
        case .invalidTOTPLength:          return "The TOTP length must be between 4 and 255!"
        case .emptyAlphabet:              return "The alphabet must not be empty!"
        case .alphabetTooShort:           return "The alphabet must contain at least 4 characters!"
        case .duplicateAlphabetChars:     return "The alphabet must not contain duplicate characters!"
        case .alphabetContainsWhitespace: return "The alphabet must not contain whitespace!"
        }
    }

}

struct TOTPGenerator {

    static func generateRandomSecret(length: Int = 16) -> String {
        let allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_+!$%&/()=?@#*"
        return String((0..<length).map { _ in allowedChars.randomElement()! })
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
        guard totpLength >= 4 && totpLength <= 255 else {
            throw TOTPError.invalidTOTPLength
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

        return TOTPResult(previous:      previous,
                          current:       current,
                          next:          next,
                          remainingTime: remainingTime)

    }

    // MARK: - Private

    private static func calcTOTPSlot(
        slot:         Int64,
        totpLength:   Int,
        alphabet:     String,
        sharedSecret: String
    ) -> String {

        // Convert slot to 8-byte array in native byte order.
        // Android: ByteBuffer.allocate(8).putLong(slot) produces big-endian,
        //          then reverseBytes() on little-endian systems -> native endian.
        // Swift:   withUnsafeBytes(of:) directly gives native endian.
        // Both ARM Android and ARM iOS are little-endian, so results match.
        var slotValue = slot
        let slotData  = Data(bytes: &slotValue, count: 8)

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

}
