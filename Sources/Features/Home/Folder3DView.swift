import SwiftUI

/// A single 3D folder: tabbed back panel, document sheets peeking out, and a frosted front flap.
/// Drawn with layered gradients, so it stays crisp and fast inside 3D projection transforms.
struct Folder3DView: View {
    let title: String
    let count: Int
    let symbols: [String]
    var isFocused: Bool
    var size = CGSize(width: 150, height: 200)
    /// 0 = closed, 1 = open (flap folded toward the viewer, documents lifted out).
    var openAmount: CGFloat = 0
    /// The person's color. The selected folder is painted in it; the others carry a faint hint of it.
    var tint: Color = Theme.accent

    private var deep: Color { tint.mix(with: .black, by: 0.42) }
    private var greyLight: Color { Color(white: 0.78).mix(with: tint, by: 0.14) }
    private var greyDark: Color { Color(white: 0.42).mix(with: tint, by: 0.14) }

    var body: some View {
        let o = openAmount
        let flap = RoundedRectangle(cornerRadius: 20, style: .continuous)
        ZStack(alignment: .bottom) {
            back
                .overlay {
                    // the inside of the folder darkens as it opens
                    FolderBackShape()
                        .fill(Color.black.opacity(0.28 * o))
                        .allowsHitTesting(false)
                }
            papers
                .padding(.horizontal, 12)
                .padding(.bottom, size.height * 0.30)
                .offset(y: -size.height * 0.34 * o)
                .scaleEffect(1 + 0.06 * o, anchor: .bottom)
            front
                .frame(height: size.height * 0.64)
                .overlay {
                    // light catches the flap as it tips toward you
                    flap.fill(LinearGradient(colors: [.white.opacity(0.32 * o), .black.opacity(0.22 * o)],
                                             startPoint: .top, endPoint: .bottom))
                        .allowsHitTesting(false)
                }
                .rotation3DEffect(.degrees(-62 * o), axis: (x: 1, y: 0, z: 0),
                                  anchor: .bottom, perspective: 0.42)
        }
        .frame(width: size.width, height: size.height)
        .compositingGroup()
        .shadow(color: isFocused ? tint.opacity(0.45 + 0.25 * o) : .black.opacity(0.6),
                radius: isFocused ? 26 + 18 * o : 14, x: 0, y: isFocused ? 10 + 10 * o : 12)
        .scaleEffect(1 + 0.1 * o)
        .offset(y: -12 * o)
        .animation(Motion.snappy, value: isFocused)
        .animation(.smooth(duration: 0.45), value: tint)
    }

    // MARK: Layers

    private var back: some View {
        FolderBackShape()
            .fill(LinearGradient(
                colors: isFocused
                    ? [tint.opacity(0.85), deep.opacity(0.9)]
                    : [greyLight.opacity(0.42), greyLight.opacity(0.14)],
                startPoint: .top, endPoint: .bottom))
            .overlay(FolderBackShape().stroke(Color.white.opacity(isFocused ? 0.45 : 0.3), lineWidth: 0.8))
    }

    private var papers: some View {
        let o = openAmount
        return ZStack {
            paper(opacity: 0.55 + 0.3 * o, symbol: symbols.dropFirst().first)
                .rotationEffect(.degrees(-4 - 8 * o))
                .offset(x: -6 - 16 * o, y: 8 - 4 * o)
            paper(opacity: 0.92, symbol: symbols.first)
                .rotationEffect(.degrees(3 + 6 * o))
                .offset(x: 6 + 12 * o, y: -10 * o)
        }
        .frame(height: size.height * 0.6)
    }

    private func paper(opacity: Double, symbol: String?) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(opacity))
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: symbol ?? "doc.text.fill")
                            .font(.system(size: 10, weight: .bold))
                        Capsule().frame(width: 34, height: 5)
                    }
                    Capsule().frame(width: 70, height: 4)
                    Capsule().frame(width: 52, height: 4)
                    HStack(spacing: 3) {
                        ForEach(0..<6, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1).frame(width: 7, height: 9)
                        }
                    }
                    .padding(.top, 2)
                }
                .foregroundStyle(Color.black.opacity(0.22))
                .padding(10)
            }
    }

    private var front: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return shape
            .fill(LinearGradient(
                colors: isFocused
                    ? [tint.opacity(0.96), deep.opacity(0.94)]
                    : [greyLight.opacity(0.86), greyDark.opacity(0.82)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
            // inner glow on the top edge (glass rim)
            .overlay(
                shape.stroke(
                    LinearGradient(colors: [.white.opacity(0.85), .white.opacity(0.08), .white.opacity(0.3)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1.1)
            )
            .overlay(alignment: .top) {
                shape
                    .fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center))
                    .frame(height: 46)
                    .padding(3)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc.fill")
                    Text("\(count)")
                        .contentTransition(.numericText())
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isFocused ? Color.black.opacity(0.75) : Color.black.opacity(0.6))
                .padding(14)
            }
            .overlay(alignment: .bottomLeading) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(isFocused ? Color.black.opacity(0.85) : Color.black.opacity(0.7))
                    .padding(14)
            }
    }
}

/// Folder silhouette with a tab on the top-left.
struct FolderBackShape: Shape {
    var tabWidthRatio: CGFloat = 0.46
    var tabHeight: CGFloat = 16
    var radius: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let tw = rect.width * tabWidthRatio
        let top = rect.minY + tabHeight
        let r = radius
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + tw - 14, y: rect.minY))
        p.addCurve(to: CGPoint(x: rect.minX + tw + 12, y: top),
                   control1: CGPoint(x: rect.minX + tw + 2, y: rect.minY),
                   control2: CGPoint(x: rect.minX + tw - 2, y: top))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: top))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: top + r), control: CGPoint(x: rect.maxX, y: top))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Dashed "new person" folder at the end of the fan.
struct AddFolderView: View {
    var size = CGSize(width: 150, height: 200)

    var body: some View {
        ZStack {
            FolderBackShape()
                .fill(Color.white.opacity(0.05))
            FolderBackShape()
                .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.2, dash: [6, 5]))
            VStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 52, height: 52)
                    .glassEffect(.regular.tint(Theme.accent.opacity(0.35)), in: .circle)
                Text(tr("New person"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.top, 16)
        }
        .frame(width: size.width, height: size.height)
    }
}
