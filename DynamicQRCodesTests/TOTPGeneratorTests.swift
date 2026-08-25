import XCTest
@testable import DynamicQRCodes

final class TOTPGeneratorTests: XCTestCase {
    func testCurrentBuildStoreResetsDateWhenVersionOrBuildChanges() throws {
        let suiteName = "CurrentBuildStoreTests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let firstBuildLaunch = Date(timeIntervalSince1970: 1_000)
        let repeatedLaunch = Date(timeIntervalSince1970: 2_000)
        let newBuildLaunch = Date(timeIntervalSince1970: 3_000)
        let newVersionLaunch = Date(timeIntervalSince1970: 4_000)

        XCTAssertEqual(
            CurrentBuildStore.date(
                version: "1.2",
                build: "3",
                userDefaults: userDefaults,
                now: firstBuildLaunch
            ),
            firstBuildLaunch
        )
        XCTAssertEqual(
            CurrentBuildStore.date(
                version: "1.2",
                build: "3",
                userDefaults: userDefaults,
                now: repeatedLaunch
            ),
            firstBuildLaunch
        )
        XCTAssertEqual(
            CurrentBuildStore.date(
                version: "1.2",
                build: "4",
                userDefaults: userDefaults,
                now: newBuildLaunch
            ),
            newBuildLaunch
        )
        XCTAssertEqual(
            CurrentBuildStore.date(
                version: "1.3",
                build: "4",
                userDefaults: userDefaults,
                now: newVersionLaunch
            ),
            newVersionLaunch
        )
    }

    @MainActor
    func testTimestampFormatterUsesConfiguredTimeZone() throws {
        let timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 2 * 60 * 60))
        let formatter = TimestampFormatter(timeZone: timeZone)
        let unixEpoch = Date(timeIntervalSince1970: 0)

        XCTAssertEqual(formatter.string(from: unixEpoch), "1970-01-01 02:00:00")
        XCTAssertEqual(formatter.date(from: "1970-01-01 02:00:00"), unixEpoch)
    }

    func testRandomSecretUsesRequestedLength() {
        XCTAssertEqual(TOTPGenerator.generateRandomSecret(length: 32).count, 32)
        XCTAssertEqual(TOTPGenerator.generateRandomSecret(length: 0), "")
        XCTAssertEqual(TOTPGenerator.generateRandomSecret(length: -1), "")
    }

    private struct Vector {
        let name: String
        let secret: String
        let timestamp: Int64
        let validityTime: UInt32
        let length: UInt32
        let alphabet: String
        let expected: TOTPResult
    }

    private let defaultAlphabet = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

    func testOCPPConformanceVectors() throws {
        for vector in vectors {
            let result = try TOTPGenerator.generate(
                sharedSecret: vector.secret,
                validityTime: vector.validityTime,
                totpLength: vector.length,
                alphabet: vector.alphabet,
                timestamp: vector.timestamp
            )
            XCTAssertEqual(result, vector.expected, vector.name)
        }
    }

    func testInvalidInputsAreRejected() {
        assertError(.emptySecret, secret: "")
        assertError(.emptySecret, secret: "        ")
        assertError(.secretTooShort, secret: "secure!Charging")
        assertError(.secretContainsWhitespace, secret: "secure Charging!")
        assertError(.invalidTOTPLength, length: 3)
        assertError(.invalidTOTPLength, length: 256)
        assertError(.invalidValidityTime, validityTime: 0)
        assertError(.negativeTimestamp, timestamp: -1_000)
        assertError(.emptyAlphabet, alphabet: "")
        assertError(.emptyAlphabet, alphabet: "   ")
        assertError(.alphabetTooShort, alphabet: "abc")
        assertError(.duplicateAlphabetChars, alphabet: "abcdeff")
        assertError(.alphabetContainsWhitespace, alphabet: "ab cdef")
    }

    func testValidationAcceptsNeighbouringSlots() throws {
        let timestamp: Int64 = 1_716_423_785_000
        let result = try TOTPGenerator.generate(sharedSecret: "secure!Charging!", timestamp: timestamp)

        XCTAssertEqual(try TOTPGenerator.validate(result.current, sharedSecret: "secure!Charging!", timestamp: timestamp), .current)
        XCTAssertEqual(try TOTPGenerator.validate(result.previous, sharedSecret: "secure!Charging!", timestamp: timestamp), .previous)
        XCTAssertEqual(try TOTPGenerator.validate(result.next, sharedSecret: "secure!Charging!", timestamp: timestamp), .next)
        XCTAssertEqual(try TOTPGenerator.validate("000000000000", sharedSecret: "secure!Charging!", timestamp: timestamp), .invalid)
    }

    private func assertError(
        _ expected: TOTPError,
        secret: String = "secure!Charging!",
        length: UInt32 = 12,
        validityTime: UInt32 = 30,
        alphabet: String = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
        timestamp: Int64 = 1_716_423_785_000
    ) {
        XCTAssertThrowsError(
            try TOTPGenerator.generate(
                sharedSecret: secret,
                validityTime: validityTime,
                totpLength: length,
                alphabet: alphabet,
                timestamp: timestamp
            )
        ) { error in
            XCTAssertEqual(error as? TOTPError, expected)
        }
    }

    private var vectors: [Vector] {
        let secret = "secure!Charging!"
        return [
            vector("defaults-slot-boundary", secret, 1_718_611_200_000, 30, 12, defaultAlphabet, "QT1cCdKsIb9e", "akF3c7qY2uiu", "1U70OgaBA48M", 30),
            vector("defaults-mid-slot", secret, 1_716_423_785_000, 30, 12, defaultAlphabet, "MdPU0jCm5tXz", "CN63y502maVh", "dI54vnA25m2h", 25),
            vector("length-23", secret, 1_716_423_785_000, 30, 23, defaultAlphabet, "MdPU0jCm5tXzkaPrPj61KwI", "CN63y502maVhAsv27Sd7JlE", "dI54vnA25m2hWW3bUcdY13q", 25),
            vector("alphabet-decimal", secret, 1_716_423_785_000, 30, 12, "0123456789", "233045043555", "894361286613", "545817627227", 25),
            vector("validity-60", secret, 1_716_423_785_000, 60, 12, defaultAlphabet, "nTdkiuG6yUyg", "XJZr0L1DGKn0", "ft0ONZ62MdMj", 55),
            vector("epoch-previous-slot-wraps", secret, 0, 30, 12, defaultAlphabet, "SzcwtcR5qcY7", "u5CoKdo5HUS1", "tVGiyLys7Y1V", 30),
            vector("length-64-sha256-ring-buffer", secret, 1_718_611_200_000, 30, 64, defaultAlphabet, "QT1cCdKsIb9e1gSulDAx9PYnnkX3e9h0QT1cCdKsIb9e1gSulDAx9PYnnkX3e9h0", "akF3c7qY2uiuO4rpyU0SC0W8VFE6nvxzakF3c7qY2uiuO4rpyU0SC0W8VFE6nvxz", "1U70OgaBA48Mul8hQCdP4MZ0eskSGKY31U70OgaBA48Mul8hQCdP4MZ0eskSGKY3", 30),
            vector("length-6-decimal", secret, 1_718_611_200_000, 30, 6, "0123456789", "277289", "441749", "127406", 30),
            vector("length-min-4", secret, 1_716_423_785_000, 30, 4, defaultAlphabet, "MdPU", "CN63", "dI54", 25),
            vector("length-33-sha256", secret, 1_716_423_785_000, 30, 33, defaultAlphabet, "MdPU0jCm5tXzkaPrPj61KwIMNKAF7gMtM", "CN63y502maVhAsv27Sd7JlErFxtg9tAUC", "dI54vnA25m2hWW3bUcdY13qmNkNzzB06d", 25),
            vector("alphabet-min-4", secret, 1_716_423_785_000, 30, 12, "ACGT", "ACCAACAACTCT", "GCGTATGAGACT", "TACATTAGTGGC", 25),
            vector("alphabet-hex", secret, 1_716_423_785_000, 30, 12, "0123456789abcdef", "cd14cd44d753", "61e30fec245b", "bc50f3423621", 25),
            vector("alphabet-base32", secret, 1_716_423_785_000, 30, 12, "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567", "MNRU4NEU5XVD", "GR6DA764SEVL", "LMFA7TECDWCR", 25),
            vector("alphabet-base64url", secret, 1_716_423_785_000, 30, 12, "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_", "IdNQYdAkZnRz", "CN-3w_-Yi4Rb", "bI50vjA23m2h", 25),
            vector("validity-1", secret, 1_716_423_785_000, 1, 12, defaultAlphabet, "4tCOMnYC1jyO", "QypcM5hxJ94T", "NaZqaahbFnb0", 1),
            vector("validity-5", secret, 1_716_423_785_000, 5, 12, defaultAlphabet, "LYhXalw0w2O5", "3bp8qljbQ6Th", "ZELD377HHJpx", 5),
            vector("validity-7", secret, 1_716_423_785_000, 7, 12, defaultAlphabet, "9tmY7YPiGS9k", "RpYIMd0IlQCZ", "ihflnOIQeXKG", 1),
            vector("validity-86400", secret, 1_716_423_785_000, 86_400, 12, defaultAlphabet, "YRo0d3AAG9h3", "FRmyHBzwle4I", "qr4tp5AYFetR", 85_015),
            vector("remaining-1-second", secret, 1_716_423_779_000, 30, 12, defaultAlphabet, "nl0iABVo6jRY", "MdPU0jCm5tXz", "CN63y502maVh", 1),
            vector("milliseconds-floor", secret, 1_716_423_785_999, 30, 12, defaultAlphabet, "MdPU0jCm5tXz", "CN63y502maVh", "dI54vnA25m2h", 25),
            vector("milliseconds-floor-slot-edge", secret, 1_716_423_809_999, 30, 12, defaultAlphabet, "MdPU0jCm5tXz", "CN63y502maVh", "dI54vnA25m2h", 1),
            vector("timestamp-y2038", secret, 2_147_483_647_000, 30, 12, defaultAlphabet, "jf6k3NFpulnR", "cSNjvhC7U5UN", "ozVde74ViFzJ", 23),
            vector("timestamp-year-9999", secret, 253_402_300_768_000, 30, 12, defaultAlphabet, "nYAGviXNwhe0", "9ko7CWj5OI4E", "qt0uZS0w35J0", 2),
            vector("secret-utf8", "sécürè!Chärgîng!", 1_716_423_785_000, 30, 12, defaultAlphabet, "2z9YFjk3E4Cs", "SLuwWQOYh3g0", "gG7F7AI3znvY", 25),
            vector("secret-64-chars", "0ZPatRVe1DTLBHRipD5cyOU9d1TCsdLLYhtLXGajUATuOwaVSVFPnbUAJyTFrPFI", 1_716_423_785_000, 30, 12, defaultAlphabet, "zxI4teacfH85", "9Sk0VMKOc9nx", "WOdiJz2UlhES", 25),
            vector("secret-surrounding-whitespace", "  secure!Charging!  ", 1_716_423_785_000, 30, 12, defaultAlphabet, "MdPU0jCm5tXz", "CN63y502maVh", "dI54vnA25m2h", 25),
            vector("alphabet-surrounding-whitespace", secret, 1_716_423_785_000, 30, 12, " 0123456789 ", "233045043555", "894361286613", "545817627227", 25),
            vector("ocpp-v1-length-8", secret, 1_716_423_785_000, 30, 8, defaultAlphabet, "MdPU0jCm", "CN63y502", "dI54vnA2", 25),
            vector("ocpp-v1-min-profile", secret, 1_716_423_785_000, 3_600, 6, defaultAlphabet, "kDDM3V", "Ik0dNs", "7eNFbx", 2_215)
        ]
    }

    private func vector(
        _ name: String,
        _ secret: String,
        _ timestamp: Int64,
        _ validityTime: UInt32,
        _ length: UInt32,
        _ alphabet: String,
        _ previous: String,
        _ current: String,
        _ next: String,
        _ remainingTime: UInt64
    ) -> Vector {
        Vector(
            name: name,
            secret: secret,
            timestamp: timestamp,
            validityTime: validityTime,
            length: length,
            alphabet: alphabet,
            expected: TOTPResult(
                previous: previous,
                current: current,
                next: next,
                remainingTime: remainingTime
            )
        )
    }
}
