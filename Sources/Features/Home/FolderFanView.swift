import SwiftUI

/// Horizontally scrolling fan of 3D folders (one per person), cover-flow style.
/// All 3D math happens in `visualEffect`, which runs at render time without layout passes,
/// so scrolling stays at the display's full refresh rate.
struct FolderFanView: View {
    let people: [Person]
    @Binding var focusedID: UUID?
    let namespace: Namespace.ID
    var onOpen: (Person) -> Void
    var onAdd: () -> Void

    static let addID = UUID(uuidString: "00000000-0000-0000-0000-0000000000AD")!
    static let folderSize = CGSize(width: 150, height: 200)

    @State private var viewportWidth: CGFloat = 390
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var focusedIndex: Int {
        if focusedID == Self.addID { return people.count }
        return people.firstIndex { $0.uid == focusedID } ?? 0
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: -38) {
                ForEach(Array(people.enumerated()), id: \.element.uid) { index, person in
                    FolderCell(
                        person: person,
                        isFocused: focusedID == person.uid,
                        namespace: namespace,
                        onTap: { handleTap(person) },
                        onOpen: { onOpen(person) }
                    )
                    .depthEntrance(index: index, appeared: appeared)
                    .zIndex(-Double(abs(index - focusedIndex)))
                    .id(person.uid)
                }

                Button(action: onAdd) { AddFolderView(size: Self.folderSize) }
                    .buttonStyle(PressScaleStyle())
                    .coverFlow(reduceMotion: reduceMotion)
                    .depthEntrance(index: people.count, appeared: appeared)
                    .zIndex(-Double(abs(people.count - focusedIndex)))
                    .id(Self.addID)
            }
            .scrollTargetLayout()
            .padding(.vertical, 40)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $focusedID, anchor: .center)
        .contentMargins(.horizontal, max(0, (viewportWidth - Self.folderSize.width) / 2), for: .scrollContent)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { viewportWidth = $0 }
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

/// One folder with its "jump toward the screen" keyframe animation.
private struct FolderCell: View {
    let person: Person
    let isFocused: Bool
    let namespace: Namespace.ID
    var onTap: () -> Void
    var onOpen: () -> Void

    @State private var jumps = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Folder3DView(
            title: person.firstName,
            count: person.documents.count,
            symbols: person.sortedDocuments.prefix(2).map(\.type.symbol),
            isFocused: isFocused,
            size: FolderFanView.folderSize
        )
        .keyframeAnimator(initialValue: JumpValues(), trigger: jumps) { content, v in
            content
                .scaleEffect(v.scale)
                .rotation3DEffect(.degrees(v.tiltX), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
                .rotationEffect(.degrees(v.spin))
                .offset(y: v.lift)
                .brightness(v.glow)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                CubicKeyframe(0.93, duration: 0.08)
                SpringKeyframe(1.34, duration: 0.26, spring: .bouncy)
                SpringKeyframe(1.0, duration: 0.5, spring: .smooth)
            }
            KeyframeTrack(\.lift) {
                CubicKeyframe(8, duration: 0.08)
                SpringKeyframe(-58, duration: 0.26, spring: .bouncy)
                SpringKeyframe(0, duration: 0.5, spring: .smooth)
            }
            KeyframeTrack(\.tiltX) {
                CubicKeyframe(6, duration: 0.08)
                SpringKeyframe(-20, duration: 0.26)
                SpringKeyframe(0, duration: 0.5, spring: .smooth)
            }
            KeyframeTrack(\.spin) {
                CubicKeyframe(0, duration: 0.1)
                CubicKeyframe(-3.5, duration: 0.12)
                CubicKeyframe(2.5, duration: 0.14)
                SpringKeyframe(0, duration: 0.35)
            }
            KeyframeTrack(\.glow) {
                CubicKeyframe(0, duration: 0.08)
                CubicKeyframe(0.12, duration: 0.2)
                CubicKeyframe(0, duration: 0.4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isFocused {
                jumps += 1
                Task {
                    try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 300))
                    onOpen()
                }
            } else {
                onTap()
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: jumps)
        .matchedTransitionSource(id: person.uid, in: namespace) { config in
            config.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .coverFlow(reduceMotion: reduceMotion)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(person.name), \(person.documents.count) documents")
        .accessibilityAddTraits(.isButton)
    }
}

private struct JumpValues {
    var scale: CGFloat = 1
    var lift: CGFloat = 0
    var tiltX: Double = 0
    var spin: Double = 0
    var glow: Double = 0
}

private extension View {
    /// Rotates, scales and lowers each item by its distance from the viewport center.
    func coverFlow(reduceMotion: Bool) -> some View {
        visualEffect { content, proxy in
            let frame = proxy.frame(in: .scrollView(axis: .horizontal))
            let viewport = proxy.bounds(of: .scrollView(axis: .horizontal)) ?? .zero
            let half = max(viewport.width / 2, 1)
            let distance = (frame.midX - viewport.midX) / half          // 0 = centered, ±1 = at the edge
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
