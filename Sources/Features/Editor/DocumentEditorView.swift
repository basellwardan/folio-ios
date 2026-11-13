import SwiftUI
import SwiftData
import PhotosUI

/// Add or edit a document: scan / import, on-device OCR suggestions, and fields.
struct DocumentEditorView: View {
    let document: VaultDocument?
    var preselectedPerson: Person?
    var startWithScanner: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Person.sortIndex) private var people: [Person]

    @State private var personID: UUID?
    @State private var type: DocumentType = .nationalID
    @State private var title = ""
    @State private var number = ""
    @State private var issuer = ""
    @State private var hasIssueDate = false
    @State private var issueDate = Date()
    @State private var hasExpiry = true
    @State private var expiryDate = Calendar.current.date(byAdding: .year, value: 5, to: .now) ?? .now
    @State private var notes = ""

    @State private var frontImage: UIImage?
    @State private var backImage: UIImage?
    @State private var removedFront = false
    @State private var removedBack = false

    @State private var scanningSide: CardSide?
    @State private var showScanner = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var pickerSide: CardSide = .front
    @State private var suggestions: TextExtractor.Suggestions?
    @State private var isReading = false
    @State private var errorMessage: String?
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    typePicker
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section(tr("Scans")) {
                    HStack(spacing: 12) {
                        imageSlot(side: .front, image: frontImage)
                        imageSlot(side: .back, image: backImage)
                    }
                    .padding(.vertical, 4)
                    if isReading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(tr("Reading text on device…")).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    if let s = suggestions, !s.isEmpty { suggestionRow(s) }
                }

                Section(tr("Owner")) {
                    Picker(tr("Person"), selection: $personID) {
                        ForEach(people) { p in
                            Text(p.name).tag(Optional(p.uid))
                        }
                    }
                }

                Section(tr("Details")) {
                    TextField(tr("Title (optional)"), text: $title, prompt: Text(type.label))
                    TextField(tr("Document number"), text: $number)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                    TextField(tr("Issued by"), text: $issuer)
                }

                Section(tr("Dates")) {
                    Toggle(tr("Issue date"), isOn: $hasIssueDate.animation(Motion.snappy))
                    if hasIssueDate {
                        DatePicker(tr("Issued"), selection: $issueDate, displayedComponents: .date)
                    }
                    Toggle(tr("Expires"), isOn: $hasExpiry.animation(Motion.snappy))
                    if hasExpiry {
                        DatePicker(tr("Expiry"), selection: $expiryDate, displayedComponents: .date)
                        Text(tr("You'll get reminders 90, 30 and 7 days before."))
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Section(tr("Notes")) {
                    TextField(tr("Anything else"), text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(Theme.badge) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DotGridBackground(glow: type.tint, glowCenter: UnitPoint(x: 0.5, y: 0.1), glowStrength: 0.16))
            .navigationTitle(document == nil ? tr("New document") : tr("Edit document"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Cancel"), systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Save"), systemImage: "checkmark") { save() }
                        .disabled(personID == nil || saving)
                }
            }
            .fullScreenCover(isPresented: $showScanner) {
                DocumentScannerView { pages in
                    showScanner = false
                    applyScan(pages)
                } onCancel: {
                    showScanner = false
                }
                .ignoresSafeArea()
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task { await loadPicked(item) }
            }
        }
        .onAppear(perform: load)
    }

    // MARK: Pieces

    private var typePicker: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(DocumentType.allCases) { t in
                        Button {
                            withAnimation(Motion.snappy) { type = t }
                        } label: {
                            Label(t.shortLabel, systemImage: t.symbol)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(type == t ? Color.black : Color.white)
                                .padding(.horizontal, 14)
                                .frame(height: 40)
                        }
                        .buttonStyle(PressScaleStyle())
                        .glassEffect(type == t ? Glass.regular.tint(t.tint).interactive() : Glass.regular.interactive(),
                                     in: .capsule)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: type)
    }

    private func imageSlot(side: CardSide, image: UIImage?) -> some View {
        let existingID = side == .front
            ? (removedFront ? nil : document?.frontImageID)
            : (removedBack ? nil : document?.backImageID)
        return VStack(spacing: 8) {
            ZStack {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else if existingID != nil {
                    ScanThumbnail(imageID: existingID, title: side == .front ? tr("Front") : tr("Back"))
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 22, weight: .light))
                        Text(side == .front ? tr("Front") : tr("Back"))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.hairline))

            HStack(spacing: 6) {
                if DocumentScannerView.isSupported {
                    Button {
                        scanningSide = side
                        showScanner = true
                    } label: {
                        Image(systemName: "camera.viewfinder").frame(width: 34, height: 30)
                    }
                    .buttonStyle(.glass)
                }
                PhotosPicker(selection: Binding(
                    get: { pickerItem },
                    set: { pickerSide = side; pickerItem = $0 }
                ), matching: .images) {
                    Image(systemName: "photo").frame(width: 34, height: 30)
                }
                .buttonStyle(.glass)
                if image != nil || existingID != nil {
                    Button(role: .destructive) {
                        withAnimation(Motion.snappy) { removeImage(side) }
                    } label: {
                        Image(systemName: "trash").frame(width: 30, height: 30)
                    }
                    .buttonStyle(.glass)
                }
            }
            .labelStyle(.iconOnly)
        }
    }

    private func suggestionRow(_ s: TextExtractor.Suggestions) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(tr("Found on the scan"), systemImage: "text.viewfinder")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    if let n = s.number, n != number {
                        suggestionChip(tr("No. %@", n)) { number = n }
                    }
                    if let e = s.expiry {
                        suggestionChip(tr("Expires %@", e.mediumFormatted)) { hasExpiry = true; expiryDate = e }
                    }
                    if let i = s.issue {
                        suggestionChip(tr("Issued %@", i.mediumFormatted)) { hasIssueDate = true; issueDate = i }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func suggestionChip(_ text: String, apply: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Motion.snappy) { apply() }
        } label: {
            Label(text, systemImage: "plus")
                .font(.system(size: 13, weight: .medium))
        }
        .buttonStyle(.glass)
        .tint(Theme.accent)
    }

    // MARK: Logic

    private func load() {
        if let document {
            personID = document.person?.uid
            type = document.type
            title = document.title
            number = document.number
            issuer = document.issuer
            if let d = document.issueDate { hasIssueDate = true; issueDate = d }
            if let d = document.expiryDate { hasExpiry = true; expiryDate = d } else { hasExpiry = false }
            notes = document.notes
        } else {
            personID = preselectedPerson?.uid ?? people.first?.uid
            if startWithScanner && DocumentScannerView.isSupported {
                scanningSide = .front
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    showScanner = true
                }
            }
        }
    }

    private func applyScan(_ pages: [UIImage]) {
        guard !pages.isEmpty else { return }
        if scanningSide == .back {
            backImage = pages[0]
        } else {
            frontImage = pages[0]
            if pages.count > 1 { backImage = pages[1] }
            readText(from: pages[0])
        }
    }

    private func loadPicked(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            errorMessage = tr("That photo could not be opened.")
            return
        }
        if pickerSide == .front {
            frontImage = image
            readText(from: image)
        } else {
            backImage = image
        }
    }

    private func removeImage(_ side: CardSide) {
        if side == .front { frontImage = nil; removedFront = true } else { backImage = nil; removedBack = true }
    }

    private func readText(from image: UIImage) {
        isReading = true
        Task {
            let found = await TextExtractor.suggestions(for: image)
            withAnimation(Motion.snappy) {
                isReading = false
                suggestions = found
                // Fill empty fields automatically; existing values stay and are offered as chips.
                if number.isEmpty, let n = found.number { number = n }
                if let e = found.expiry, document?.expiryDate == nil { hasExpiry = true; expiryDate = e }
                if !hasIssueDate, let i = found.issue { hasIssueDate = true; issueDate = i }
            }
        }
    }

    private func save() {
        guard let person = people.first(where: { $0.uid == personID }) else { return }
        saving = true
        do {
            let doc: VaultDocument
            if let document {
                doc = document
            } else {
                doc = VaultDocument(type: type)
                context.insert(doc)
            }
            doc.type = type
            doc.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            doc.number = number.trimmingCharacters(in: .whitespacesAndNewlines)
            doc.issuer = issuer.trimmingCharacters(in: .whitespacesAndNewlines)
            doc.issueDate = hasIssueDate ? issueDate : nil
            doc.expiryDate = hasExpiry ? expiryDate : nil
            doc.notes = notes
            doc.person = person

            if let frontImage {
                let old = doc.frontImageID
                doc.frontImageID = try SecureStore.shared.saveImage(frontImage)
                SecureStore.shared.delete(old); ImageLoader.evict(old)
            } else if removedFront {
                SecureStore.shared.delete(doc.frontImageID); ImageLoader.evict(doc.frontImageID)
                doc.frontImageID = nil
            }
            if let backImage {
                let old = doc.backImageID
                doc.backImageID = try SecureStore.shared.saveImage(backImage)
                SecureStore.shared.delete(old); ImageLoader.evict(old)
            } else if removedBack {
                SecureStore.shared.delete(doc.backImageID); ImageLoader.evict(doc.backImageID)
                doc.backImageID = nil
            }

            try context.save()

            let uid = doc.uid, docTitle = doc.displayTitle, name = person.firstName, expiry = doc.expiryDate
            Task {
                if expiry != nil { await ExpiryReminders.requestAuthorization() }
                ExpiryReminders.schedule(uid: uid, title: docTitle, personName: name, expiry: expiry)
            }
            dismiss()
        } catch {
            saving = false
            errorMessage = error.localizedDescription
        }
    }
}
