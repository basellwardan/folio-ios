import Foundation
import SwiftData

/// Sample data used only with the `-demoData` launch argument (CI screenshots / previews).
enum DemoData {
    static func seed(into context: ModelContext) {
        let cal = Calendar.current
        func inDays(_ d: Int) -> Date { cal.date(byAdding: .day, value: d, to: .now) ?? .now }

        let people: [(String, String, [(DocumentType, String, Int?, Int?)])] = [
            ("Alex Morgan", "F5F5F2", [
                (.nationalID, "1098 4471 2236", -900, 1200),
                (.driverLicense, "DL-55102938", -400, 48),
                (.healthInsurance, "HI-77821", -200, 160),
            ]),
            ("Sara Khan", "3BE16B", [
                (.passport, "P48291746", -700, 2900),
                (.nationalID, "2201 9934 0071", -300, 1500),
                (.driverLicense, "DL-88123004", -1000, 21),
                (.residency, "RP-302281", -500, -12),
            ]),
            ("Omar Haddad", "40CCFF", [
                (.passport, "N1928374", -1500, 300),
                (.vehicle, "VR-4410-KS", -100, 260),
            ]),
            ("Lina Park", "FFC83D", [
                (.nationalID, "3301 2290 1188", -100, 3000),
                (.birthCertificate, "BC-1999-0412", -9000, nil),
            ]),
            ("Noah Reed", "B58CFF", [
                (.passport, "X7720019", -60, 3500),
                (.healthInsurance, "HI-10293", -30, 330),
                (.other, "LIB-2231", -10, nil),
            ]),
        ]

        for (index, entry) in people.enumerated() {
            let person = Person(name: entry.0, colorHex: entry.1, sortIndex: index)
            context.insert(person)
            for doc in entry.2 {
                let d = VaultDocument(
                    type: doc.0,
                    number: doc.1,
                    issuer: doc.0 == .passport ? "Ministry of Interior" : "Civil Affairs",
                    issueDate: doc.2.map(inDays),
                    expiryDate: doc.3.map(inDays)
                )
                context.insert(d)
                d.person = person
            }
        }
        try? context.save()
    }
}
