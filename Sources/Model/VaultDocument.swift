import Foundation
import SwiftData

@Model
final class VaultDocument {
    @Attribute(.unique) var uid: UUID = UUID()
    var typeRaw: String = "other"
    var title: String = ""
    var number: String = ""
    var issuer: String = ""
    var issueDate: Date?
    var expiryDate: Date?
    var notes: String = ""
    /// IDs of AES-GCM encrypted image files in `SecureStore`.
    var frontImageID: String?
    var backImageID: String?
    var createdAt: Date = Date()
    var person: Person?

    init(
        type: DocumentType,
        title: String = "",
        number: String = "",
        issuer: String = "",
        issueDate: Date? = nil,
        expiryDate: Date? = nil,
        notes: String = ""
    ) {
        self.uid = UUID()
        self.typeRaw = type.rawValue
        self.title = title
        self.number = number
        self.issuer = issuer
        self.issueDate = issueDate
        self.expiryDate = expiryDate
        self.notes = notes
        self.createdAt = Date()
    }
}

extension VaultDocument {
    var type: DocumentType {
        get { DocumentType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var displayTitle: String { title.isEmpty ? type.label : title }

    var status: ExpiryStatus { ExpiryStatus.of(expiryDate) }

    var daysUntilExpiry: Int? { ExpiryStatus.daysUntil(expiryDate) }

    /// "•••• 4821" style masking.
    var maskedNumber: String {
        guard !number.isEmpty else { return tr("No number") }
        let tail = String(number.suffix(4))
        return number.count <= 4 ? number : "•••• \(tail)"
    }
}
