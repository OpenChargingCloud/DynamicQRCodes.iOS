import Foundation

struct GeneratedDynamicQRCode: Equatable, Sendable {
    let url: URL
    let totp: TOTPResult
}

struct DynamicQRCodeConfiguration: Equatable, Sendable {
    let template: URLTemplate
    let evseID: String
    let sharedSecret: String
    let validityTime: UInt32
    let totpLength: UInt32
    let alphabet: String

    func generate(timestamp: Int64) throws -> GeneratedDynamicQRCode {
        let result = try TOTPGenerator.generate(
            sharedSecret: sharedSecret,
            validityTime: validityTime,
            totpLength: totpLength,
            alphabet: alphabet,
            timestamp: timestamp
        )
        let url = try template.render(evseID: evseID, totp: result.current)
        return GeneratedDynamicQRCode(url: url, totp: result)
    }

    func evaluate(scannedValue: String, timestamp: Int64) throws -> ScanEvaluation {
        try template.evaluate(
            scannedValue: scannedValue,
            sharedSecret: sharedSecret,
            validityTime: validityTime,
            totpLength: totpLength,
            alphabet: alphabet,
            timestamp: timestamp
        )
    }
}
