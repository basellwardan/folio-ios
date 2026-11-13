import SwiftUI

/// Bottom glass panel: countdown to the next expiry and a timeline ruler ("Key Dates" in the reference).
struct KeyDatesPanel: View {
    let person: Person?
    let allDocuments: [VaultDocument]

    private var scoped: [VaultDocument] { person?.documents ?? allDocuments }

    private var next: VaultDocument? {
        let today = Calendar.current.startOfDay(for: .now)
        return scoped
            .filter { ($0.expiryDate ?? .distantPast) >= today }
            .min { ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture) }
    }

    private var expiredCount: Int { scoped.filter { $0.status == .expired }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Key Dates")
                        .font(.system(size: 24, weight: .regular))
                    Text(person.map { "\($0.name) · renewals" } ?? "All renewals")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if expiredCount > 0 {
                    StatusChip(status: .expired, compact: true)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(countdown)
                    .font(.system(size: 26, weight: .light))
                    .contentTransition(.numericText())
                Text(nextCaption)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.top, 22)
            .animation(Motion.snappy, value: next?.uid)

            TimelineRuler(documents: scoped, highlighted: next?.uid)
                .frame(height: 96)
                .padding(.top, 14)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 36))
    }

    private var countdown: String {
        guard let days = next?.daysUntilExpiry else { return scoped.isEmpty ? "No documents yet" : "All clear" }
        if days == 0 { return "Today" }
        if days < 45 { return days == 1 ? "1 Day" : "\(days) Days" }
        let months = Int((Double(days) / 30.4).rounded())
        if months < 24 { return "\(months) Months" }
        return "\(Int((Double(days) / 365).rounded())) Years"
    }

    private var nextCaption: String {
        guard let next, let date = next.expiryDate else {
            return scoped.isEmpty ? "Add a document to track its expiry" : "Nothing expires soon"
        }
        let who = person == nil ? (next.person?.firstName ?? "") + " · " : ""
        return "\(who)\(next.displayTitle) · \(date.shortFormatted)"
    }
}

/// Ruler with weekly ticks, month labels, a "We're here" pill and colored expiry markers.
struct TimelineRuler: View {
    let documents: [VaultDocument]
    var highlighted: UUID?

    private let pastDays = 45.0
    private let futureDays = 365.0

    private var start: Date { Calendar.current.date(byAdding: .day, value: -Int(pastDays), to: .now) ?? .now }

    private func fraction(for date: Date) -> CGFloat {
        let span = (pastDays + futureDays) * 86_400
        return CGFloat(max(0, min(1, date.timeIntervalSince(start) / span)))
    }

    var body: some View {
        let markers = documents.compactMap { doc -> (UUID, CGFloat, Color)? in
            guard let d = doc.expiryDate else { return nil }
            return (doc.uid, fraction(for: d), doc.status.color)
        }
        let nowX = fraction(for: .now)

        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                // Ticks + month labels
                Canvas { ctx, size in
                    let baseline: CGFloat = 58
                    let totalDays = Int(pastDays + futureDays)
                    let cal = Calendar.current
                    for day in stride(from: 0, through: totalDays, by: 7) {
                        let x = size.width * CGFloat(Double(day) / Double(totalDays))
                        var p = Path()
                        p.move(to: CGPoint(x: x, y: baseline - 6))
                        p.addLine(to: CGPoint(x: x, y: baseline))
                        ctx.stroke(p, with: .color(.white.opacity(0.22)), lineWidth: 1)
                    }
                    var cursor = cal.date(from: cal.dateComponents([.year, .month], from: start)) ?? start
                    var i = 0
                    while cursor < start.addingTimeInterval((pastDays + futureDays) * 86_400) {
                        if cursor >= start {
                            let x = size.width * fraction(for: cursor)
                            var p = Path()
                            p.move(to: CGPoint(x: x, y: baseline - 14))
                            p.addLine(to: CGPoint(x: x, y: baseline))
                            ctx.stroke(p, with: .color(.white.opacity(0.45)), lineWidth: 1.2)
                            if i % 2 == 0 {
                                let label = Text(cursor.formatted(.dateTime.month(.abbreviated)))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.4))
                                ctx.draw(label, at: CGPoint(x: x, y: baseline + 14))
                            }
                            i += 1
                        }
                        cursor = cal.date(byAdding: .month, value: 1, to: cursor) ?? cursor.addingTimeInterval(2_678_400)
                    }
                }

                // Expiry markers
                ForEach(markers, id: \.0) { marker in
                    Circle()
                        .fill(marker.2)
                        .frame(width: marker.0 == highlighted ? 11 : 8, height: marker.0 == highlighted ? 11 : 8)
                        .shadow(color: marker.2.opacity(0.8), radius: marker.0 == highlighted ? 8 : 4)
                        .position(x: w * marker.1, y: 36)
                }

                // Now line + pill
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 1.5, height: 30)
                    .position(x: w * nowX, y: 46)
                Text("We're here")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .glassEffect(.regular.tint(Theme.accent), in: .capsule)
                    .fixedSize()
                    .position(x: max(52, w * nowX + 30), y: 12)
            }
        }
        .animation(Motion.snappy, value: highlighted)
    }
}
