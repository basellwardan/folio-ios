import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// One document: a big 3D card you can flip and spin with your finger, plus its details.
struct DocumentDetailView: View {
    @Bindable var document: VaultDocument

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var flipAngle: Double = 0
    @State private var drag: CGSize = .zero
    @State private var revealNumber = false
    @State private var copied = false
    @State private var showEditor = false
    @State private var viewer: ViewerItem?
    @State private var confirmDelete = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            DotGridBackground(glow: document.type.tint, glowCenter: UnitPoint(x: 0.5, y: 0.18), glowStrength: 0.2)

            ScrollView {
                VStack(spacing: 18) {
                    card
                        .padding(.top, 12)
                        .padding(.horizontal, 6)
                    Text("Tap to flip · drag to spin")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)

                    details
                        .depthEntrance(index: 1, appeared: appeared)
                    scans
                        .depthEntrance(index: 2, appeared: appeared)
                    if !document.notes.isEmpty {
                        GlassSection(title: "Notes") {
                            Text(document.notes)
                                .font(.system(size: 15))
                                .foregroundStyle(.white)
                        }
                        .depthEntrance(index: 3, appeared: appeared)
                    }
                    Button("Delete document", systemImage: "trash", role: .destructive) { confirmDelete = true }
                        .buttonStyle(.glass)
                        .tint(Theme.badge)
                        .padding(.top, 6)
                        .depthEntrance(index: 4, appeared: appeared)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(document.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit", systemImage: "pencil") { showEditor = true }
            }
        }
        .sheet(isPresented: $showEditor) {
            DocumentEditorView(document: document, preselectedPerson: document.person, startWithScanner: false)
        }
        .fullScreenCover(item: $viewer) { item in
            ScanViewer(imageID: item.id, title: item.title)
        }
        .confirmationDialog("Delete this document?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteDocument() }
        } message: {
            Text("The scans are erased from this iPhone. This cannot be undone.")
        }
        .onAppear {
            if !appeared { withAnimation { appeared = true } }
            if LaunchOptions.isDemo && LaunchOptions.screen == "flipped" {
                Task {
                    try? await Task.sleep(for: .milliseconds(1400))
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) { flipAngle = 180 }
                }
            }
        }
    }

    // MARK: Flippable 3D card

    private var card: some View {
        FlipView(
            angle: flipAngle,
            front: DocumentCard3D(document: document, side: .front, tilt: false),
            back: DocumentCard3D(document: document, side: .back, tilt: false)
        )
        .rotation3DEffect(.degrees(Double(drag.width) / 5), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .rotation3DEffect(.degrees(Double(-drag.height) / 5), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
        .tiltRotation(4)
        .scaleEffect(drag == .zero ? 1 : 1.03)
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    guard !reduceMotion else { return }
                    drag = CGSize(width: max(-180, min(180, value.translation.width)),
                                  height: max(-120, min(120, value.translation.height)))
                }
                .onEnded { value in
                    // A strong horizontal fling flips the card.
                    let fling = value.predictedEndTranslation.width - value.translation.width
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) {
                        drag = .zero
                        if abs(fling) > 220 { flipAngle += fling > 0 ? 180 : -180 }
                    }
                }
        )
        .simultaneousGesture(
            TapGesture().onEnded {
                withAnimation(.spring(response: 0.65, dampingFraction: 0.74)) { flipAngle += 180 }
            }
        )
        .sensoryFeedback(.impact(flexibility: .soft), trigger: flipAngle)
    }

    // MARK: Details

    private var details: some View {
        GlassSection(title: "Details") {
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        label("Number")
                        Text(document.number.isEmpty ? "—" : (revealNumber ? document.number : document.maskedNumber))
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .contentTransition(.numericText())
                            .textSelection(.enabled)
                    }
                    Spacer()
                    if !document.number.isEmpty {
                        GlassCircleButton(systemImage: revealNumber ? "eye.slash" : "eye", size: 40) {
                            withAnimation(Motion.snappy) { revealNumber.toggle() }
                        }
                        GlassCircleButton(systemImage: copied ? "checkmark" : "doc.on.doc", size: 40,
                                          tint: copied ? Theme.accent.opacity(0.6) : nil) {
                            copyNumber()
                        }
                    }
                }
                Divider().overlay(Theme.hairline)
                row("Holder", document.person?.name ?? "—")
                row("Type", document.type.label)
                if !document.issuer.isEmpty { row("Issued by", document.issuer) }
                row("Issue date", document.issueDate?.mediumFormatted ?? "—")
                HStack {
                    label("Expiry date")
                    Spacer()
                    Text(document.expiryDate?.mediumFormatted ?? "—")
                        .font(.system(size: 15, weight: .medium))
                    StatusChip(status: document.status, compact: true)
                }
                if let days = document.daysUntilExpiry {
                    Text(days < 0 ? "Expired \(-days) days ago" : days == 0 ? "Expires today" : "Expires in \(days) days")
                        .font(.system(size: 13))
                        .foregroundStyle(document.status.color)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .foregroundStyle(.white)
        }
    }

    private var scans: some View {
        GlassSection(title: "Scans") {
            HStack(spacing: 12) {
                scanThumb(id: document.frontImageID, title: "Front")
                scanThumb(id: document.backImageID, title: "Back")
            }
        }
    }

    private func scanThumb(id: String?, title: String) -> some View {
        Button {
            if let id { viewer = ViewerItem(id: id, title: "\(document.displayTitle) · \(title)") } else { showEditor = true }
        } label: {
            ScanThumbnail(imageID: id, title: title)
        }
        .buttonStyle(PressScaleStyle())
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.textSecondary)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            label(title)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: Actions

    private func copyNumber() {
        UIPasteboard.general.setItems(
            [[UTType.plainText.identifier: document.number]],
            options: [.expirationDate: Date().addingTimeInterval(90), .localOnly: true]
        )
        withAnimation(Motion.snappy) { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(Motion.snappy) { copied = false }
        }
    }

    private func deleteDocument() {
        let target = document
        let context = context
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            SecureStore.shared.delete(target.frontImageID)
            SecureStore.shared.delete(target.backImageID)
            ExpiryReminders.cancel(uid: target.uid)
            context.delete(target)
            try? context.save()
        }
    }
}

struct ViewerItem: Identifiable {
    let id: String
    let title: String
}

/// Two-sided card. Conforms to `Animatable` so the visible face switches exactly at 90°.
struct FlipView<Front: View, Back: View>: View, Animatable {
    var angle: Double
    let front: Front
    let back: Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        let normalized = (angle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let showingBack = normalized > 90 && normalized < 270
        ZStack {
            front.opacity(showingBack ? 0 : 1)
            back
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(showingBack ? 1 : 0)
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
    }
}

struct ScanThumbnail: View {
    let imageID: String?
    let title: String
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                VStack(spacing: 6) {
                    Image(systemName: imageID == nil ? "plus.viewfinder" : "photo")
                        .font(.system(size: 22, weight: .light))
                    Text(imageID == nil ? "Add \(title.lowercased())" : title)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hairline))
        .overlay(alignment: .bottomLeading) {
            if image != nil {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .glassEffect(.regular, in: .capsule)
                    .padding(6)
            }
        }
        .task(id: imageID) { image = await ImageLoader.image(imageID, maxPixel: 600) }
    }
}

/// Full-screen, pinch-to-zoom scan viewer.
struct ScanViewer: View {
    let imageID: String
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { scale = max(1, min(6, lastScale * $0.magnification)) }
                            .onEnded { _ in
                                lastScale = scale
                                if scale <= 1 { withAnimation(Motion.snappy) { offset = .zero; lastOffset = .zero } }
                            }
                            .simultaneously(with: DragGesture()
                                .onChanged { v in
                                    guard scale > 1 else { return }
                                    offset = CGSize(width: lastOffset.width + v.translation.width,
                                                    height: lastOffset.height + v.translation.height)
                                }
                                .onEnded { _ in lastOffset = offset })
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(Motion.snappy) {
                            scale = scale > 1 ? 1 : 2.5
                            lastScale = scale
                            offset = .zero; lastOffset = .zero
                        }
                    }
            } else {
                ProgressView().tint(.white)
            }
        }
        .overlay(alignment: .top) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, 16).frame(height: 44)
                    .glassEffect(.regular, in: .capsule)
                Spacer()
                GlassCircleButton(systemImage: "xmark", size: 44) { dismiss() }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
        }
        .task { image = await ImageLoader.image(imageID, maxPixel: 2400) }
    }
}
