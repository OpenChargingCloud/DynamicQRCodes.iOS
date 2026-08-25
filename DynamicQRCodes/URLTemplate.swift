import Foundation

enum URLTemplateError: LocalizedError, Equatable {
    case missingPlaceholders([String])
    case invalidTemplate
    case invalidURL
    case unsupportedScheme
    case noMatch

    var errorDescription: String? {
        switch self {
        case .missingPlaceholders(let names):
            return "The URL template is missing: \(names.map { "{\($0)}" }.joined(separator: ", "))."
        case .invalidTemplate:
            return "The URL template is invalid."
        case .invalidURL:
            return "The generated URL is invalid."
        case .unsupportedScheme:
            return "The URL must use HTTPS."
        case .noMatch:
            return "The scanned URL does not match the configured template."
        }
    }
}

struct URLTemplate: Equatable, Sendable {
    private static let placeholderPattern = #"\{([A-Za-z0-9_]+)\}"#

    let rawValue: String

    init(_ rawValue: String) throws {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw URLTemplateError.invalidTemplate }

        self.rawValue = trimmed

        let missing = ["evseId", "totp"].filter { !placeholderNames.contains($0) }
        guard missing.isEmpty else { throw URLTemplateError.missingPlaceholders(missing) }
    }

    var placeholderNames: [String] {
        guard let placeholderExpression else { return [] }
        let range = NSRange(rawValue.startIndex..., in: rawValue)
        return placeholderExpression.matches(in: rawValue, range: range).compactMap { match in
            guard let range = Range(match.range(at: 1), in: rawValue) else { return nil }
            return String(rawValue[range])
        }
    }

    func render(evseID: String, totp: String) throws -> URL {
        guard let encodedEVSEID = Self.encodePlaceholderValue(evseID),
              let encodedTOTP = Self.encodePlaceholderValue(totp) else {
            throw URLTemplateError.invalidURL
        }

        let rendered = rawValue
            .replacingOccurrences(of: "{evseId}", with: encodedEVSEID)
            .replacingOccurrences(of: "{totp}", with: encodedTOTP)

        guard let url = URL(string: rendered), url.host != nil else {
            throw URLTemplateError.invalidURL
        }
        guard url.scheme?.lowercased() == "https" else {
            throw URLTemplateError.unsupportedScheme
        }
        return url
    }

    func extract(from scannedValue: String) throws -> [String: String] {
        let matches = placeholderMatches
        guard !matches.isEmpty else { throw URLTemplateError.invalidTemplate }

        var pattern = "^"
        var cursor = rawValue.startIndex

        for match in matches {
            guard let fullRange = Range(match.range, in: rawValue) else {
                throw URLTemplateError.invalidTemplate
            }

            pattern += NSRegularExpression.escapedPattern(for: String(rawValue[cursor..<fullRange.lowerBound]))
            pattern += "([^/?#]+)"
            cursor = fullRange.upperBound
        }

        pattern += NSRegularExpression.escapedPattern(for: String(rawValue[cursor...]))
        pattern += "$"

        let expression = try NSRegularExpression(pattern: pattern)
        let scanned = scannedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let scannedRange = NSRange(scanned.startIndex..., in: scanned)

        guard let result = expression.firstMatch(in: scanned, range: scannedRange) else {
            throw URLTemplateError.noMatch
        }

        var values: [String: String] = [:]
        for (index, name) in placeholderNames.enumerated() {
            guard let valueRange = Range(result.range(at: index + 1), in: scanned) else { continue }
            values[name] = String(scanned[valueRange]).removingPercentEncoding ?? String(scanned[valueRange])
        }
        return values
    }

    private var placeholderMatches: [NSTextCheckingResult] {
        guard let placeholderExpression else { return [] }
        let range = NSRange(rawValue.startIndex..., in: rawValue)
        return placeholderExpression.matches(in: rawValue, range: range)
    }

    private var placeholderExpression: NSRegularExpression? {
        try? NSRegularExpression(pattern: Self.placeholderPattern)
    }

    private static func encodePlaceholderValue(_ value: String) -> String? {
        var allowedCharacters = CharacterSet.urlPathAllowed
        allowedCharacters.remove(charactersIn: "/?#%")
        return value.addingPercentEncoding(withAllowedCharacters: allowedCharacters)
    }
}

struct ScanEvaluation: Equatable, Sendable {
    let scannedValue: String
    let evseID: String?
    let validation: TOTPValidation

    var message: String {
        switch validation {
        case .current: "TOTP valid — current time slot"
        case .previous: "TOTP valid — previous time slot"
        case .next: "TOTP valid — next time slot"
        case .invalid: "TOTP invalid"
        }
    }
}

extension URLTemplate {
    func evaluate(
        scannedValue: String,
        sharedSecret: String,
        validityTime: UInt32,
        totpLength: UInt32,
        alphabet: String,
        timestamp: Int64
    ) throws -> ScanEvaluation {
        let values = try extract(from: scannedValue)
        guard let totp = values["totp"] else { throw URLTemplateError.noMatch }

        let validation = try TOTPGenerator.validate(
            totp,
            sharedSecret: sharedSecret,
            validityTime: validityTime,
            totpLength: totpLength,
            alphabet: alphabet,
            timestamp: timestamp
        )

        return ScanEvaluation(
            scannedValue: scannedValue,
            evseID: values["evseId"],
            validation: validation
        )
    }
}
