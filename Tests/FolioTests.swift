import XCTest
import CryptoKit
@testable import Folio

final class SecureStoreTests: XCTestCase {
    func testSealOpenRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let plain = Data("passport-scan-bytes".utf8)
        let sealed = try SecureStore.seal(plain, key: key)
        XCTAssertNotEqual(sealed, plain)
        XCTAssertEqual(try SecureStore.open(sealed, key: key), plain)
    }

    func testWrongKeyFails() throws {
        let sealed = try SecureStore.seal(Data("secret".utf8), key: SymmetricKey(size: .bits256))
        XCTAssertThrowsError(try SecureStore.open(sealed, key: SymmetricKey(size: .bits256)))
    }
}

final class ExpiryStatusTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)
    let now = Date(timeIntervalSince1970: 1_780_000_000)

    func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: now)! }

    func testStatuses() {
        XCTAssertEqual(ExpiryStatus.of(nil, now: now, calendar: cal), .noExpiry)
        XCTAssertEqual(ExpiryStatus.of(day(-1), now: now, calendar: cal), .expired)
        XCTAssertEqual(ExpiryStatus.of(day(0), now: now, calendar: cal), .expiringSoon)
        XCTAssertEqual(ExpiryStatus.of(day(90), now: now, calendar: cal), .expiringSoon)
        XCTAssertEqual(ExpiryStatus.of(day(91), now: now, calendar: cal), .valid)
    }

    func testDaysUntil() {
        XCTAssertEqual(ExpiryStatus.daysUntil(day(30), now: now, calendar: cal), 30)
        XCTAssertEqual(ExpiryStatus.daysUntil(day(-5), now: now, calendar: cal), -5)
    }
}

final class TextExtractorTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)

    func ymd(_ d: Date?) -> [Int] {
        guard let d else { return [] }
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return [c.year!, c.month!, c.day!]
    }

    func testPassportMRZ() {
        let lines = [
            "PASSPORT",
            "P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<",
            "L898902C36UTO7408122F1204159ZE184226B<<<<<10",
        ]
        let s = TextExtractor.parse(lines: lines, now: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(s.number, "L898902C3")
        XCTAssertEqual(ymd(s.expiry), [2012, 4, 15])
    }

    func testPrintedDatesWithKeywords() {
        let lines = [
            "DRIVING LICENCE",
            "No. DL-55102938",
            "Date of Issue 03/02/2021",
            "Date of Expiry 14/08/2031",
        ]
        let s = TextExtractor.parse(lines: lines, now: cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!)
        XCTAssertEqual(ymd(s.expiry), [2031, 8, 14])
        XCTAssertEqual(ymd(s.issue), [2021, 2, 3])
        XCTAssertEqual(s.number?.filter(\.isNumber), "55102938")
    }

    func testMonthNameDates() {
        let dates = TextExtractor.findDates(in: "EXP 12 JAN 2030")
        XCTAssertEqual(dates.map { ymd($0) }, [[2030, 1, 12]])
    }
}

final class LocalizationTests: XCTestCase {
    /// Every Arabic translation must use the same placeholders as its English key,
    /// otherwise String(format:) would crash or drop values.
    func testArabicPlaceholdersMatch() {
        let pattern = try! NSRegularExpression(pattern: #"%(\d\$)?@"#)
        func count(_ s: String) -> Int {
            pattern.numberOfMatches(in: s, range: NSRange(s.startIndex..., in: s))
        }
        for (english, arabic) in L10n.arabic {
            XCTAssertFalse(arabic.isEmpty, english)
            XCTAssertEqual(count(english), count(arabic), "placeholder mismatch for \"\(english)\"")
        }
    }

    func testEveryDocumentTypeIsTranslated() {
        for type in DocumentType.allCases {
            XCTAssertNotNil(L10n.arabic[type.englishLabel], type.englishLabel)
            XCTAssertNotNil(L10n.arabic[type.englishShortLabel], type.englishShortLabel)
        }
        for status in [ExpiryStatus.valid, .expiringSoon, .expired, .noExpiry] {
            XCTAssertNotNil(L10n.arabic[status.englishLabel], status.englishLabel)
        }
    }
}
