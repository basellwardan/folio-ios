import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.sortIndex) private var people: [Person]
    @Query private var documents: [VaultDocument]

    @State private var path = NavigationPath()
    @State private var focusedID: UUID?
    @State private var sheet: HomeSheet?
    @Namespace private var zoom

    private var focusedPerson: Person? {
        people.first { $0.uid == focusedID } ?? (focusedID == FolderFanView.addID ? nil : people.first)
    }

    private var attentionCount: Int { documents.filter { $0.status.needsAttention }.count }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                DotGridBackground(glow: Theme.accent, glowCenter: UnitPoint(x: 0.6, y: 0.47))

                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        header
                            .padding(.horizontal, 20)
                            .padding(.top, 6)
                        actions
                            .padding(.top, 18)
                        fanSection
                            .padding(.top, 8)
                        KeyDatesPanel(person: focusedPerson, allDocuments: documents)
                            .padding(.horizontal, 14)
                            .padding(.top, 4)
                            .padding(.bottom, 24)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: Person.self) { person in
                PersonDetailView(person: person, namespace: zoom)
                    .navigationTransition(.zoom(sourceID: person.uid, in: zoom))
            }
            .navigationDestination(for: VaultDocument.self) { document in
                DocumentDetailView(document: document)
                    .navigationTransition(.zoom(sourceID: document.uid, in: zoom))
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .addPerson:
                PersonEditorView(person: nil) { newPerson in
                    withAnimation(Motion.snappy) { focusedID = newPerson.uid }
                }
            case .addDocument(let scan):
                DocumentEditorView(document: nil, preselectedPerson: focusedPerson, startWithScanner: scan)
                    .navigationTransition(.zoom(sourceID: scan ? "scan" : "add-doc", in: zoom))
            case .expiring:
                ExpiringListView(documents: documents) { doc in
                    self.sheet = nil
                    Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        if let p = doc.person { path.append(p) }
                        path.append(doc)
                    }
                }
                .presentationDetents([.medium, .large])
                .navigationTransition(.zoom(sourceID: "bell", in: zoom))
            }
        }
        .onAppear {
            if focusedID == nil { focusedID = people.first?.uid }
        }
        .onChange(of: people.count) { _, _ in
            if focusedPerson == nil && focusedID != FolderFanView.addID { focusedID = people.first?.uid }
        }
        .task { await runDemoScreen() }
    }

    // MARK: Header (logo, people, bell)

    private var header: some View {
        HStack(alignment: .center) {
            LogoMark(size: 54)
            Spacer()
            GlassEffectContainer(spacing: 0) {
                HStack(spacing: -8) {
                    ForEach(people.prefix(3)) { person in
                        Button {
                            withAnimation(Motion.snappy) { focusedID = person.uid }
                        } label: {
                            AvatarBubble(initials: person.initials, color: person.color, size: 46,
                                         isSelected: focusedID == person.uid)
                        }
                        .buttonStyle(PressScaleStyle(scale: 0.9))
                        .glassEffect(
                            Glass.regular
                                .tint(focusedID == person.uid ? Theme.accent : Color.white.opacity(0.06))
                                .interactive(),
                            in: .circle
                        )
                        .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 0.8).allowsHitTesting(false))
                    }
                }
                .animation(Motion.snappy, value: focusedID)
            }
            GlassCircleButton(systemImage: "bell", size: 50, badge: attentionCount) {
                sheet = .expiring
            }
            .matchedTransitionSource(id: "bell", in: zoom)
            .padding(.leading, 6)
        }
    }

    // MARK: Action pills

    private var actions: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 10) {
                    GlassPill(title: "Scan", systemImage: "doc.viewfinder") {
                        sheet = people.isEmpty ? .addPerson : .addDocument(scan: true)
                    }
                    .matchedTransitionSource(id: "scan", in: zoom)

                    GlassPill(title: "Expiring", systemImage: "clock.badge.exclamationmark") {
                        sheet = .expiring
                    }

                    GlassPill(title: "Add Document", systemImage: "plus", prominent: true) {
                        sheet = people.isEmpty ? .addPerson : .addDocument(scan: false)
                    }
                    .matchedTransitionSource(id: "add-doc", in: zoom)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    // MARK: Folder fan + floating focus card

    private var fanSection: some View {
        ZStack(alignment: .topLeading) {
            FolderFanView(
                people: people,
                focusedID: $focusedID,
                namespace: zoom,
                onOpen: { path.append($0) },
                onAdd: { sheet = .addPerson }
            )
            .padding(.top, 84)

            if let person = focusedPerson {
                FocusCard(person: person) { path.append(person) }
                    .padding(.leading, 20)
                    .transition(.scale(scale: 0.85, anchor: .topLeading).combined(with: .opacity))
            } else if people.isEmpty {
                EmptyFocusCard { sheet = .addPerson }
                    .padding(.leading, 20)
            }
        }
        .animation(Motion.snappy, value: focusedPerson?.uid)
    }

    // MARK: Demo routing for CI screenshots

    private func runDemoScreen() async {
        guard LaunchOptions.isDemo, let screen = LaunchOptions.screen else { return }
        try? await Task.sleep(for: .milliseconds(900))
        let second = people.count > 1 ? people[1] : people.first
        switch screen {
        case "fan":
            withAnimation(Motion.snappy) { focusedID = people.count > 2 ? people[2].uid : second?.uid }
        case "person":
            if let second { path.append(second) }
        case "document", "flipped":
            if let second {
                path.append(second)
                try? await Task.sleep(for: .milliseconds(600))
                if let doc = second.sortedDocuments.first { path.append(doc) }
            }
        case "expiring":
            sheet = .expiring
        case "add":
            focusedID = second?.uid
            sheet = .addDocument(scan: false)
        default:
            withAnimation(Motion.snappy) { focusedID = second?.uid }
        }
    }
}

enum HomeSheet: Identifiable, Hashable {
    case addPerson
    case addDocument(scan: Bool)
    case expiring

    var id: String {
        switch self {
        case .addPerson: "person"
        case .addDocument(let scan): "doc-\(scan)"
        case .expiring: "expiring"
        }
    }
}

// MARK: - Floating glass card for the focused person ("Corporate 87%" in the reference)

struct FocusCard: View {
    let person: Person
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(person.name)
                            .font(.system(size: 19, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 4)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(person.validPercent.map { "\($0)" } ?? "—")
                        .font(.system(size: 40, weight: .thin))
                        .contentTransition(.numericText())
                    Text(person.validPercent == nil ? "" : "%  valid")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 6)
            }
            .foregroundStyle(.white)
            .padding(18)
            .frame(width: 214, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 26))
        }
        .buttonStyle(PressScaleStyle(scale: 0.97))
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 26))
        .id(person.uid)
    }

    private var subtitle: String {
        let n = person.documents.count
        let docs = n == 1 ? "1 document" : "\(n) documents"
        let attention = person.attentionCount
        return attention > 0 ? "\(docs) · \(attention) need attention" : docs
    }
}

struct EmptyFocusCard: View {
    var onAdd: () -> Void
    var body: some View {
        Button(action: onAdd) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to Folio")
                    .font(.system(size: 19, weight: .medium))
                Text("Create a folder for each person, then add their IDs, passports and licenses.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label("Add a person", systemImage: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 6)
            }
            .foregroundStyle(.white)
            .padding(18)
            .frame(width: 250, alignment: .leading)
        }
        .buttonStyle(PressScaleStyle(scale: 0.97))
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 26))
    }
}
