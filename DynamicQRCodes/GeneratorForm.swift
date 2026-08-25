import Foundation

struct ValidatedInput {
    let configuration: DynamicQRCodeConfiguration
    let timestamp: Int64
}

struct GeneratorFormState: Equatable {
    var timestampText: String
    var urlTemplate: String
    var evseID: String
    var sharedSecret: String
    var validityTimeText: String
    var totpLengthText: String
    var alphabet: String
}

enum InputField: Hashable {
    case timestamp
    case urlTemplate
    case evseID
    case sharedSecret
    case validityTime
    case totpLength
    case alphabet
}

enum GeneratorFormError: LocalizedError {
    case invalidTimestamp
    case invalidValidityTime
    case invalidTOTPLength

    var errorDescription: String? {
        switch self {
        case .invalidTimestamp:
            "Enter a timestamp in the format yyyy-MM-dd HH:mm:ss."
        case .invalidValidityTime:
            "Validity time must be a positive whole number."
        case .invalidTOTPLength:
            "TOTP length must be a whole number between 4 and 255."
        }
    }
}

@MainActor
final class TimestampFormatter {
    private let formatter: DateFormatter

    init(timeZone: TimeZone = .current) {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.isLenient = false
        self.formatter = formatter
    }

    func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    func date(from string: String) -> Date? {
        formatter.date(from: string)
    }
}
