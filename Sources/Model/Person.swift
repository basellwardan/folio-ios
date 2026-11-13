import Foundation
import SwiftData
import SwiftUI

@Model
final class Person {
    @Attribute(.unique) var uid: UUID = UUID()
    var name: String = ""
    var colorHex: String = "3BE16B"
    var createdAt: Date = Date()
    var sortIndex: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \VaultDocument.person)
    var documents: [VaultDocument] = []

    init(name: String, colorHex: String = "3BE16B", sortIndex: Int = 0) {
        self.uid = UUID()
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
        self.sortIndex = sortIndex
    }
}

extension Person {
    static let palette = ["3BE16B", "F5F5F2", "40CCFF", "FFC83D", "FF5A4F", "B58CFF", "FF8FCB"]

    var color: Color { Color(hex: colorHex) }

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }.joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }

    var sortedDocuments: [VaultDocument] {
        documents.sorted {
            if $0.type.order != $1.type.order { return $0.type.order < $1.type.order }
            return $0.createdAt < $1.createdAt
        }
    }

    /// Share of documents that are not expired. `nil` when there are no documents.
    var validPercent: Int? {
        guard !documents.isEmpty else { return nil }
        let valid = documents.filter { $0.status != .expired }.count
        return Int((Double(valid) / Double(documents.count) * 100).rounded())
    }

    var attentionCount: Int { documents.filter { $0.status.needsAttention }.count }

    /// The soonest upcoming (or most recently missed) expiry.
    var nextExpiringDocument: VaultDocument? {
        documents
            .filter { $0.expiryDate != nil }
            .sorted { ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture) }
            .first { ($0.expiryDate ?? .distantPast) >= Calendar.current.startOfDay(for: .now) }
            ?? documents.filter { $0.status == .expired }.first
    }
}
