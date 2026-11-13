import SwiftUI

/// Horizontally scrolling fan of 3D folders (one per person), cover-flow style.
/// All 3D math happens in `visualEffect`, which runs at render time without layout passes,
/// so scrolling stays at the display's full refresh rate.
struct FolderFanView: View {
    let people: [Person]
    @Binding var focusedID: UUID?
    var openedID: UUID? = nil
    let namespace: Namespace.ID
    var onOpen: (Person) -> Void
    var onAdd: () -> Void

    static let addID = UUID(uuidString: "00000000-0000-0000-0000-0000000000AD")!
    static let folderSize = CGSize(width: 160, height: 214)
    /// Zoom-transition source for the person page. It is an invisible rectangle fixed where the
    /// centered folder rests, so the transition never snapshots (or clips) the moving 3D folder.
    static let openSourceID = "open-folder"

    @State private var viewportWidth: CGFloat = 390
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var focusedIndex: Int {
        if focusedID == Self.addID { return people.count }
        return people.firstIndex { $0.uid == focusedID } ?? 0
    }

    private var openIndex: Int? {
        guard let openedID else { return nil }
        return people.firstIndex { $0.uid == openedID }
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: -46) {
                ForEach(Array(people.enumerated()), id: \.element.uid) { index, person in
                    FolderCell(
                        person: person,
                        isFocused: focusedID == person.uid,
                        isOpen: openedID == person.uid,
                        onTap: { handleTap(person) },
                        onOpen: { onOpen(person) }
                    )
                    .depthEntrance(index: index, appeared: appeared)
                    .modifier(MakeRoom(index: index, openIndex: openIndex))
                    .zIndex(openedID == person.uid ? 10 : -Double(abs(index - focusedIndex)))
                    .id(person.uid)
                }

                Button(action: onAdd) { AddFolderView(size: Self.folderSize) }
                    .buttonStyle(PressScaleStyle())
                    .coverFlow(reduceMotion: reduceMotion)
                    .depthEntrance(index: people.count, appeared: appeared)
                    .modifier(MakeRoom(index: people.count, openIndex: openIndex))
                    .zIndex(-Double(abs(people.count - focusedIndex)))
                    .id(Self.addID)
            }
            .scrollTargetLayout()
            .padding(.vertical, 40)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .scrollDisabled(openedID != nil)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $focusedID, anchor: .center)
        .contentMargins(.horizontal, max(0, (viewportWidth - Self.folderSize.width) / 2), for: .scrollContent)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { viewportWidth = $0 }
        .overlay {
            Color.clear
                .frame(width: Self.folderSize.width, height: Self.folderSize.height)
                .matchedTransitionSource(id: Self.openSourceID, in: namespace) { config in
                    config.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .allowsHitTesting(false)
        }
        // The 3D fan math is written for left-to-right; keep it that way in Arabic too.
        .environment(\.layoutDirection, .leftToRight)
        .sensoryFeedback(.selection, trigger: focusedID)
        .onAppear {
            guard !appeared else { return }
            withAnimation { appeared = true }
        }
    }

    private func handleTap(_ person: Person) {
        if focusedID == person.uid {
            onOpen(person)
        } else {
            withAnimation(Motion.snappy) { focusedID = person.uid }
        }
    }
}

/// While a folder is open, its neighbours slide aside and dim so it has the stage.
private struct MakeRoom: ViewModifier {
    let index: Int
    let openIndex: Int?

    func body(content: Content) -> some View {
        let push: CGFloat = {
            guard let openIndex, index != openIndex else { return 0 }
            return index < openIndex ? -54 : 54
        }()
        let dimmed = openIndex != nil && openIndex != index
        content
            .offset(x: push)
            .opacity(dimmed ? 0.35 : 1)
            .blur(radius: dimmed ? 2 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: openIndex)
    }
}

/// One folder. Tapping the centered folder opens it: the flap folds toward you, the documents
/// rise out and fan apart, then the person's page zooms out of the open folder.
private struct FolderCell: View {
    let person: Person
    let isFocused: Bool
    let isOpen: Bool
    var onTap: () -> Void
    var onOpen: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Folder3DView(
            title: person.firstName,
            count: person.documents.count,
            symbols: person.sortedDocuments.prefix(2).map(\.type.symbol),
            isFocused: isFocused,
            size: FolderFanView.folderSize,
            openAmount: isOpen && !reduceMotion ? 1 : 0,
            tint: person.color
        )
        .animation(
            isOpen ? .spring(response: 0.46, dampingFraction: 0.66) : .spring(response: 0.5, dampingFraction: 0.78),
            value: isOpen
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isFocused { onOpen() } else { onTap() }
        }
        .sensoryFeedback(trigger: isOpen) { _, open -> SensoryFeedback? in
            open ? SensoryFeedback.impact(weight: .medium) : SensoryFeedback.impact(flexibility: .soft)
        }
        .coverFlow(reduceMotion: reduceMotion)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(person.name), \(person.documents.count) documents")
        .accessibilityAddTraits(.isButton)
    }
}

private extension View {
    /// Rotates, scales and lowers each item by its distance from the viewport center.
    func coverFlow(reduceMotion: Bool) -> some View {
        visualEffect { content, proxy in
            // `bounds(of:)` is the scroll viewport expressed in this item's own coordinates.
            let viewport = proxy.bounds(of: .scrollView(axis: .horizontal))
                ?? CGRect(origin: .zero, size: proxy.size)
            let half = max(viewport.width / 2, 1)
            let distance = (proxy.size.width / 2 - viewport.midX) / half  // 0 = centered, ±1 = at the edge
            let d = max(-1.8, min(1.8, distance))
            let magnitude = min(abs(d), 1.4)
            return content
                .rotation3DEffect(
                    .degrees(reduceMotion ? 0 : -d * 42),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: d > 0 ? .leading : .trailing,
                    perspective: 0.55
                )
                .scaleEffect(1 - magnitude * 0.16)
                .offset(x: -d * 14, y: magnitude * 18)
                .opacity(1 - max(0, abs(d) - 1.1) * 1.4)
        }
    }
}
