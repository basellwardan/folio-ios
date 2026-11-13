import SwiftUI
import SwiftData

/// A person's folder opened: profile header and their documents as 3D glass cards.
struct PersonDetailView: View {
    @Bindable var person: Person
    let namespace: Namespace.ID

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false
    @State private var dealt = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showAddDocument = false
    @State private var showEditPerson = false
    @State private var confirmDelete = false

    var body: some View {
        let docs = person.sortedDocuments
        ZStack {
            DotGridBackground(glow: person.color, glowCenter: UnitPoint(x: 0.5, y: 0.05), glowStrength: 0.2)

            ScrollView {
                VStack(spacing: 22) {
                    header
                        .depthEntrance(index: 0, appeared: appeared)
                    stats(docs)
                        .depthEntrance(index: 1, appeared: appeared)

                    if docs.isEmpty {
                        emptyState
                            .depthEntrance(index: 2, appeared: appeared)
                    } else {
                        LazyVStack(spacing: 20) {
                            ForEach(Array(docs.enumerated()), id: \.element.uid) { index, doc in
                                NavigationLink(value: doc) {
                                    DocumentCard3D(document: doc)
                                }
                                .buttonStyle(PressScaleStyle(scale: 0.96))
                                .matchedTransitionSource(id: doc.uid, in: namespace) { config in
                                    config.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                }
                                .modifier(DealEntrance(index: index, shown: dealt))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(person.firstName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(tr("Edit person"), systemImage: "pencil") { showEditPerson = true }
                    Button(tr("Delete person"), systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Button(tr("Add document"), systemImage: "plus") { showAddDocument = true }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.accent)
            }
        }
        .sheet(isPresented: $showAddDocument) {
            DocumentEditorView(document: nil, preselectedPerson: person, startWithScanner: false)
        }
        .sheet(isPresented: $showEditPerson) {
            PersonEditorView(person: person, onSaved: nil)
        }
        .confirmationDialog(tr("Delete %@?", person.name), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(tr("Delete person and %@", L10n.documents(person.documents.count)), role: .destructive) { deletePerson() }
        } message: {
            Text(tr("Their scans are erased from this iPhone. This cannot be undone."))
        }
        .onAppear {
            if !appeared {
                withAnimation { appeared = true }
            }
            guard !dealt else { return }
            // Deal the cards once the zoom out of the folder has settled, so nothing moves mid-transition.
            Task {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 320))
                dealt = true
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            AvatarBubble(initials: person.initials, color: person.color, size: 72, isSelected: true)
                .glassEffect(.regular.tint(person.color.opacity(0.85)), in: .circle)
            VStack(alignment: .leading, spacing: 4) {
                Text(person.name)
                    .font(.system(size: 28, weight: .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(tr("Folder since %@", person.createdAt.mediumFormatted))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.top, 8)
    }

    private func stats(_ docs: [VaultDocument]) -> some View {
        let valid = docs.filter { $0.status == .valid || $0.status == .noExpiry }.count
        let soon = docs.filter { $0.status == .expiringSoon }.count
        let expired = docs.filter { $0.status == .expired }.count
        return GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                stat("\(docs.count)", tr("Documents"), .white)
                stat("\(valid)", tr("Valid"), Theme.accent)
                stat("\(soon)", tr("Expiring"), Theme.warn)
                stat("\(expired)", tr("Expired"), Theme.badge)
            }
        }
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.accent)
            Text(tr("This folder is empty"))
                .font(.system(size: 18, weight: .medium))
            Text(tr("Scan or import %@'s ID, passport or license.", person.firstName))
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button(tr("Add first document"), systemImage: "plus") { showAddDocument = true }
                .buttonStyle(.glassProminent)
                .tint(Theme.accent)
                .foregroundStyle(.black)
                .padding(.top, 4)
        }
        .foregroundStyle(.white)
        .padding(28)
        .frame(maxWidth: .infinity)
        .glassPanel(cornerRadius: 30)
        .padding(.top, 20)
    }

}

/// Cards slide down out of the opened folder one after another, tipping flat as they land.
/// Every card ends exactly flat, so there is no snap afterwards.
private struct DealEntrance: ViewModifier {
    let index: Int
    let shown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown || reduceMotion ? 1 : 0.78, anchor: .top)
            .rotation3DEffect(.degrees(shown || reduceMotion ? 0 : 48), axis: (x: 1, y: 0, z: 0),
                              anchor: .top, perspective: 0.5)
            .offset(y: shown || reduceMotion ? 0 : -90)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.2)
                    : .spring(response: 0.58, dampingFraction: 0.8).delay(Double(min(index, 6)) * 0.07),
                value: shown
            )
    }
}

private extension PersonDetailView {
    func deletePerson() {
        let target = person
        let context = context
        // Leave the screen first so no view reads the model after it is deleted.
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            for doc in target.documents {
                SecureStore.shared.delete(doc.frontImageID)
                SecureStore.shared.delete(doc.backImageID)
                ExpiryReminders.cancel(uid: doc.uid)
            }
            context.delete(target)
            try? context.save()
        }
    }
}
