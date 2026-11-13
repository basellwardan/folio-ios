import Foundation
import UIKit
import Vision

/// On-device OCR that suggests a document number and dates from a scan.
enum TextExtractor {
    struct Suggestions: Equatable {
        var number: String?
        var expiry: Date?
        var issue: Date?

        var isEmpty: Bool { number == nil && expiry == nil && issue == nil }
    }

    static func suggestions(for image: UIImage) async -> Suggestions {
        let lines = await recognize(image)
        return parse(lines: lines)
    }

    static func recognize(_ image: UIImage) async -> [String] {
        guard let cg = image.normalizedOrientation().cgImage else { return [] }
        return await Task.detached(priority: .userInitiated) { () -> [String] in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
            try? handler.perform([request])
            return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        }.value
    }

    // MARK: - Parsing (pure, unit-tested)

    static func parse(lines: [String], now: Date = .now) -> Suggestions {
        var result = Suggestions()

        // 1. Machine-readable zone (passports TD3, ID cards TD1)
        let mrz = lines
            .map { $0.uppercased().replacingOccurrences(of: " ", with: "") }
            .filter { $0.contains("<") && $0.count >= 28 }
        if let parsed = parseMRZ(mrz) {
            result.number = parsed.number
            result.expiry = parsed.expiry
        }

        // 2. Printed dates
        let expiryWords = ["EXP", "VALID", "UNTIL", "EXPIRY", "EXPIRES", "DATE OF EXPIRY", "انتهاء"]
        let issueWords = ["ISSUE", "ISS", "DATE OF ISSUE", "إصدار"]
        var all: [Date] = []
        var keyedExpiry: Date?
        var keyedIssue: Date?
        for (i, line) in lines.enumerated() {
            let dates = findDates(in: line)
            guard !dates.isEmpty else { continue }
            all.append(contentsOf: dates)
            let context = (line + " " + (i > 0 ? lines[i - 1] : "")).uppercased()
            if keyedExpiry == nil, expiryWords.contains(where: { context.contains($0) }) {
                keyedExpiry = dates.max()
            } else if keyedIssue == nil, issueWords.contains(where: { context.contains($0) }) {
                keyedIssue = dates.min()
            }
        }
        if result.expiry == nil {
            result.expiry = keyedExpiry ?? all.filter { $0 > now }.max()
        }
        result.issue = keyedIssue ?? all.filter { $0 <= now && $0 != result.expiry }.max()

        // 3. Document number
        if result.number == nil {
            result.number = findNumber(in: lines)
        }
        return result
    }

    static func parseMRZ(_ lines: [String]) -> (number: String, expiry: Date?)? {
        // TD3 (passport): 2 lines × 44
        let long = lines.filter { $0.count >= 44 }
        if long.count >= 2, long[0].hasPrefix("P") {
            let chars = Array(long[1])
            let number = String(chars[0..<9]).replacingOccurrences(of: "<", with: "")
            let expiry = mrzDate(String(chars[21..<27]), century: 2000)
            if !number.isEmpty { return (number, expiry) }
        }
        // TD1 (ID card): 3 lines × 30
        let td1 = lines.filter { $0.count >= 30 && $0.count < 40 }
        if td1.count >= 2 {
            let l1 = Array(td1[0]), l2 = Array(td1[1])
            let number = String(l1[5..<14]).replacingOccurrences(of: "<", with: "")
            let expiry = mrzDate(String(l2[8..<14]), century: 2000)
            if !number.isEmpty { return (number, expiry) }
        }
        return nil
    }

    static func mrzDate(_ yymmdd: String, century: Int) -> Date? {
        guard yymmdd.count == 6, let v = Int(yymmdd) else { return nil }
        let yy = v / 10000, mm = (v / 100) % 100, dd = v % 100
        return makeDate(year: century + yy, month: mm, day: dd)
    }

    private static let monthNames = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

    static func findDates(in line: String) -> [Date] {
        var dates: [Date] = []
        let upper = line.uppercased()

        // dd/mm/yyyy, dd.mm.yyyy, dd-mm-yyyy
        for m in matches(#"\b(\d{1,2})[./\-](\d{1,2})[./\-](\d{4})\b"#, in: upper) {
            var d = Int(m[1]) ?? 0, mo = Int(m[2]) ?? 0
            if mo > 12 && d <= 12 { swap(&d, &mo) }
            if let date = makeDate(year: Int(m[3]) ?? 0, month: mo, day: d) { dates.append(date) }
        }
        // yyyy-mm-dd, yyyy/mm/dd
        for m in matches(#"\b(\d{4})[./\-](\d{1,2})[./\-](\d{1,2})\b"#, in: upper) {
            if let date = makeDate(year: Int(m[1]) ?? 0, month: Int(m[2]) ?? 0, day: Int(m[3]) ?? 0) { dates.append(date) }
        }
        // 12 JAN 2030, 12JAN30
        for m in matches(#"\b(\d{1,2})\s?([A-Z]{3})[A-Z]*\.?\s?(\d{4}|\d{2})\b"#, in: upper) {
            guard let monthIndex = monthNames.firstIndex(of: m[2]) else { continue }
            var year = Int(m[3]) ?? 0
            if year < 100 { year += 2000 }
            if let date = makeDate(year: year, month: monthIndex + 1, day: Int(m[1]) ?? 0) { dates.append(date) }
        }
        return dates
    }

    static func findNumber(in lines: [String]) -> String? {
        let keyWords = ["NO", "NUMBER", "ID", "LICENSE", "LICENCE", "DOCUMENT", "رقم"]
        var candidates: [(String, Int)] = []
        for (i, line) in lines.enumerated() {
            let upper = line.uppercased()
            let keyed = keyWords.contains { upper.contains($0) } || (i > 0 && keyWords.contains { lines[i - 1].uppercased().contains($0) })
            for m in matches(#"\b([A-Z]{0,3}[\- ]?\d[\d\- ]{4,16}\d|[A-Z]\d{6,9})\b"#, in: upper) {
                let token = m[1].trimmingCharacters(in: .whitespaces)
                let digits = token.filter(\.isNumber).count
                guard digits >= 5 else { continue }
                if !findDates(in: token).isEmpty { continue }
                candidates.append((token, digits + (keyed ? 10 : 0)))
            }
        }
        return candidates.max { $0.1 < $1.1 }?.0
    }

    // MARK: helpers

    static func makeDate(year: Int, month: Int, day: Int) -> Date? {
        guard (1900...2100).contains(year), (1...12).contains(month), (1...31).contains(day) else { return nil }
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = 12
        return Calendar(identifier: .gregorian).date(from: c)
    }

    private static func matches(_ pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { match in
            (0..<match.numberOfRanges).map { idx in
                let r = match.range(at: idx)
                return r.location == NSNotFound ? "" : ns.substring(with: r)
            }
        }
    }
}
