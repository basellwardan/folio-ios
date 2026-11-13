import Foundation
import SwiftUI

enum DocumentType: String, CaseIterable, Identifiable, Codable {
    case nationalID
    case passport
    case driverLicense
    case residency
    case healthInsurance
    case birthCertificate
    case vehicle
    case other

    var id: String { rawValue }

    var label: String { tr(englishLabel) }

    var englishLabel: String {
        switch self {
        case .nationalID: "National ID"
        case .passport: "Passport"
        case .driverLicense: "Driver's License"
        case .residency: "Residence Permit"
        case .healthInsurance: "Health Insurance"
        case .birthCertificate: "Birth Certificate"
        case .vehicle: "Vehicle Registration"
        case .other: "Other"
        }
    }

    var shortLabel: String { tr(englishShortLabel) }

    /// Untranslated; also used for the machine-readable line printed on the card back.
    var englishShortLabel: String {
        switch self {
        case .nationalID: "ID"
        case .passport: "Passport"
        case .driverLicense: "License"
        case .residency: "Residency"
        case .healthInsurance: "Insurance"
        case .birthCertificate: "Birth"
        case .vehicle: "Vehicle"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .nationalID: "person.text.rectangle.fill"
        case .passport: "book.closed.fill"
        case .driverLicense: "car.fill"
        case .residency: "building.columns.fill"
        case .healthInsurance: "cross.case.fill"
        case .birthCertificate: "doc.text.fill"
        case .vehicle: "car.side.fill"
        case .other: "doc.fill"
        }
    }

    /// Accent used on cards, kept inside the black / green / white palette with small signal colors.
    var tint: Color {
        switch self {
        case .nationalID: Color(white: 0.92)
        case .passport: Theme.accent
        case .driverLicense: Theme.info
        case .residency: Theme.warn
        case .healthInsurance: Theme.badge
        case .birthCertificate: Color(hex: "B58CFF")
        case .vehicle: Color(hex: "40CCFF")
        case .other: Color(white: 0.7)
        }
    }

    var order: Int { DocumentType.allCases.firstIndex(of: self) ?? 99 }

    /// Standard card aspect ratio (ID-1 = 85.6 × 54 mm). Passports use the same frame for consistency.
    static let cardAspect: CGFloat = 1.586
}

enum ExpiryStatus: Equatable {
    case valid
    case expiringSoon
    case expired
    case noExpiry

    static let soonThresholdDays = 90

    static func daysUntil(_ date: Date?, now: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let date else { return nil }
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: end).day
    }

    static func of(_ date: Date?, now: Date = .now, calendar: Calendar = .current) -> ExpiryStatus {
        guard let days = daysUntil(date, now: now, calendar: calendar) else { return .noExpiry }
        if days < 0 { return .expired }
        if days <= soonThresholdDays { return .expiringSoon }
        return .valid
    }

    var label: String { tr(englishLabel) }

    var englishLabel: String {
        switch self {
        case .valid: "Valid"
        case .expiringSoon: "Expiring"
        case .expired: "Expired"
        case .noExpiry: "No expiry"
        }
    }

    var color: Color {
        switch self {
        case .valid: Theme.accent
        case .expiringSoon: Theme.warn
        case .expired: Theme.badge
        case .noExpiry: Color(white: 0.6)
        }
    }

    var needsAttention: Bool { self == .expiringSoon || self == .expired }
}
