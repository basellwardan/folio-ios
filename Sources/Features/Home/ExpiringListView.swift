import SwiftUI

/// Documents that are expired or expire within 90 days, soonest first.
struct ExpiringListView: View {
    let documents: [VaultDocument]
    var onSelect: (VaultDocument) -> Void

    @State private var appeared = false

    private var items: [VaultDocument] {
        documents
            .filter { $0.status.needsAttention }
            .sorted { ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if items.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Theme.accent)
                            Text(tr("Everything is up to date"))
                                .font(.system(size: 18, weight: .medium))
                            Text(tr("Nothing expires in the next 90 days."))
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.top, 40)
                    }
                    ForEach(Array(items.enumerated()), id: \.element.uid) { index, doc in
                        Button { onSelect(doc) } label: { row(doc) }
                            .buttonStyle(PressScaleStyle(scale: 0.97))
                            .depthEntrance(index: index, appeared: appeared)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .foregroundStyle(.white)
            }
            .navigationTitle(tr("Needs attention"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { withAnimation { appeared = true } }
    }

    private func row(_ doc: VaultDocument) -> some View {
        HStack(spacing: 14) {
            Image(systemName: doc.type.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 42, height: 42)
                .background(Circle().fill(doc.type.tint))
            VStack(alignment: .leading, spacing: 3) {
                Text(doc.displayTitle)
                    .font(.system(size: 16, weight: .medium))
                Text(doc.person?.name ?? "")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                StatusChip(status: doc.status, compact: true)
                if let days = doc.daysUntilExpiry {
                    Text(days < 0 ? tr("%@ ago", L10n.days(-days)) : tr("in %@", L10n.days(days)))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(doc.status.color)
                }
            }
        }
        .padding(14)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
    }
}
