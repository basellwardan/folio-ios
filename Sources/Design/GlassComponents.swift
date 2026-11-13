import SwiftUI

// Building blocks on top of Apple's iOS 26 Liquid Glass APIs:
// `glassEffect(_:in:)`, `Glass.regular / .clear`, `.tint(_:)`, `.interactive()`,
// `GlassEffectContainer`, `glassEffectID(_:in:)` and `glassEffectUnion(id:namespace:)`.

extension View {
    /// Rounded Liquid Glass panel.
    func glassPanel(cornerRadius: CGFloat = 28, tint: Color? = nil, interactive: Bool = false) -> some View {
        glassEffect(Glass.regular.tint(tint).interactive(interactive), in: .rect(cornerRadius: cornerRadius))
    }
}

/// Capsule glass action (the "Export / View tasks / Add Contracts" row in the reference).
struct GlassPill: View {
    let title: String
    let systemImage: String
    var prominent = false
    let action: () -> Void

    @State private var tapCount = 0

    var body: some View {
        Button {
            tapCount += 1
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(prominent ? Color.black : Color.white)
            .padding(.horizontal, 18)
            .frame(height: 46)
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
        .glassEffect(
            prominent ? Glass.regular.tint(Theme.accent).interactive() : Glass.regular.interactive(),
            in: .capsule
        )
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
    }
}

/// Circular glass icon button with an optional red badge.
struct GlassCircleButton: View {
    let systemImage: String
    var size: CGFloat = 48
    var badge: Int = 0
    var tint: Color? = nil
    let action: () -> Void

    @State private var tapCount = 0

    var body: some View {
        Button {
            tapCount += 1
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.36, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleStyle(scale: 0.9))
        .glassEffect(Glass.regular.tint(tint).interactive(), in: .circle)
        .overlay(alignment: .topTrailing) {
            if badge > 0 {
                BadgeView(count: badge)
                    .offset(x: 5, y: -5)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(Motion.bouncy, value: badge)
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
    }
}

struct BadgeView: View {
    let count: Int
    var body: some View {
        Text("\(count)")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(minWidth: 22, minHeight: 22)
            .background(Capsule().fill(Theme.badge))
            .overlay(Capsule().stroke(Theme.background, lineWidth: 2))
            .contentTransition(.numericText())
    }
}

/// Initials bubble used in the avatar stack.
struct AvatarBubble: View {
    let initials: String
    let color: Color
    var size: CGFloat = 48
    var isSelected = false

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.32, weight: .semibold, design: .rounded))
            .foregroundStyle(isSelected ? Color.black : Color.white)
            .frame(width: size, height: size)
            .contentShape(Circle())
    }
}

/// Small status capsule (Valid / Expiring / Expired). Non-glass so it can live inside 3D objects.
struct StatusChip: View {
    let status: ExpiryStatus
    var compact = false

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(status.color).frame(width: 6, height: 6)
            Text(status.label)
                .font(.system(size: compact ? 11 : 12, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 6)
        .background(Capsule().fill(status.color.opacity(0.18)))
        .overlay(Capsule().stroke(status.color.opacity(0.35), lineWidth: 0.6))
    }
}

/// Glass section card with a heading, used on detail screens.
struct GlassSection<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .kerning(1.2)
                    .foregroundStyle(Theme.textSecondary)
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 28)
    }
}

/// "Fly in from depth" entrance used for lists of 3D objects.
struct DepthEntrance: ViewModifier {
    let index: Int
    let appeared: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.55)
            .rotation3DEffect(.degrees(appeared || reduceMotion ? 0 : 65), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .offset(y: appeared || reduceMotion ? 0 : 140)
            .animation(reduceMotion ? .easeOut(duration: 0.25) : Motion.stagger(index), value: appeared)
    }
}

extension View {
    func depthEntrance(index: Int, appeared: Bool) -> some View {
        modifier(DepthEntrance(index: index, appeared: appeared))
    }
}
