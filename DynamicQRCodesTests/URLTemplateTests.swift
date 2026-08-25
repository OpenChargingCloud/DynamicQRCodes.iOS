import XCTest
@testable import DynamicQRCodes

final class URLTemplateTests: XCTestCase {
    func testRendersSecureURL() throws {
        let template = try URLTemplate("https://charging.cloud/{evseId}/{totp}")

        let url = try template.render(evseID: "DE*GEF*E12345*678*1", totp: "CN63y502maVh")

        XCTAssertEqual(url.absoluteString, "https://charging.cloud/DE*GEF*E12345*678*1/CN63y502maVh")
    }

    func testExtractsValuesFromMatchingURL() throws {
        let template = try URLTemplate("https://charging.cloud/{evseId}/{totp}")

        let values = try template.extract(from: "https://charging.cloud/DE*GEF*E12345*678*1/CN63y502maVh")

        XCTAssertEqual(values["evseId"], "DE*GEF*E12345*678*1")
        XCTAssertEqual(values["totp"], "CN63y502maVh")
    }

    func testEncodesPlaceholderValuesWithoutChangingPathStructure() throws {
        let template = try URLTemplate("https://charging.cloud/{evseId}/{totp}")

        let url = try template.render(evseID: "DE test/1", totp: "abc/123")
        let values = try template.extract(from: url.absoluteString)

        XCTAssertEqual(url.absoluteString, "https://charging.cloud/DE%20test%2F1/abc%2F123")
        XCTAssertEqual(values["evseId"], "DE test/1")
        XCTAssertEqual(values["totp"], "abc/123")
    }

    func testRejectsNonMatchingURL() throws {
        let template = try URLTemplate("https://charging.cloud/{evseId}/{totp}")

        XCTAssertThrowsError(try template.extract(from: "https://example.com/sticker/fraud")) { error in
            XCTAssertEqual(error as? URLTemplateError, .noMatch)
        }
    }

    func testEvaluatesCurrentToken() throws {
        let template = try URLTemplate("https://charging.cloud/{evseId}/{totp}")

        let result = try template.evaluate(
            scannedValue: "https://charging.cloud/DE*GEF*E12345*678*1/CN63y502maVh",
            sharedSecret: "secure!Charging!",
            validityTime: 30,
            totpLength: 12,
            alphabet: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
            timestamp: 1_716_423_785_000
        )

        XCTAssertEqual(result.validation, .current)
        XCTAssertEqual(result.evseID, "DE*GEF*E12345*678*1")
    }

    func testRequiresHTTPSAndBothPlaceholders() throws {
        XCTAssertThrowsError(try URLTemplate("https://charging.cloud/{totp}"))

        let insecure = try URLTemplate("http://charging.cloud/{evseId}/{totp}")
        XCTAssertThrowsError(try insecure.render(evseID: "DE*GEF*E12345*678*1", totp: "token")) { error in
            XCTAssertEqual(error as? URLTemplateError, .unsupportedScheme)
        }
    }
}
