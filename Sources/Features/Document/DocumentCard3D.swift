import SwiftUI

enum CardSide { case front, back }

/// A document rendered as a physical glass card: tinted body, scan (if any), rim light and gyro shine.
struct DocumentCard3D: View {
    let document: VaultDocument
    var side: CardSide = .front
    var tilt: Bool = true

    @State private var image: UIImage?

    private var imageID: String? { side == .front ? document.frontImageID : document.backImageID }
    private let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    var body: some View {
        ZStack {
            background
            if side == .front { frontContent } else { backContent }
        }
        .aspectRatio(DocumentType.cardAspect, contentMode: .fit)
        .clipShape(shape)
        .overlay {
            shape.stroke(
                LinearGradient(colors: [.white.opacity(0.7), .white.opacity(0.06), .white.opacity(0.25)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 1)
        }
        .overlay { ShineOverlay(intensity: 0.16).clipShape(shape) }
        .compositingGroup()
        .shadow(color: document.type.tint.opacity(0.22), radius: 22, x: 0, y: 14)
        .shadow(color: .black.opacity(0.55), radius: 10, x: 0, y: 8)
        .modifier(OptionalTilt(enabled: tilt))
        .task(id: imageID) {
            image = await ImageLoader.image(imageID, maxPixel: 1000)
        }
    }

    // MARK: Layers

    @ViewBuilder
    private var background: some View {
        let tint = document.type.tint
        ZStack {
            LinearGradient(colors: [tint.opacity(0.42), Color(white: 0.09), Color(white: 0.05)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.9)
                LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.75)],
                               startPoint: .top, endPoint: .bottom)
            } else {
                // Guilloche-like pattern so empty cards still feel like documents
                GuillochePattern(color: tint)
                    .opacity(0.35)
                Image(systemName: document.type.symbol)
                    .font(.system(size: 120, weight: .bold))
                    .foregroundStyle(tint.opacity(0.10))
                    .offset(x: 90, y: 30)
            }
        }
    }

    private var frontContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: document.type.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(document.type.tint))
                Text(document.displayTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                StatusChip(status: document.status, compact: true)
            }
            Spacer(minLength: 8)
            Text(document.person?.name ?? "")
                .font(.system(size: 20, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(document.maskedNumber)
                .font(.system(size: 15, weight: .regular, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 2)
            HStack(alignment: .bottom) {
                field("ISSUED", document.issueDate?.shortFormatted ?? "—")
                Spacer()
                field("EXPIRES", document.expiryDate?.shortFormatted ?? "—", alignment: .trailing)
            }
            .padding(.top, 12)
        }
        .foregroundStyle(.white)
        .padding(18)
    }

    private var backContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(.black.opacity(0.65))
                .frame(height: 34)
                .padding(.horizontal, -18)
                .padding(.top, 8)
            if image == nil {
                Spacer()
                Text("No back side scanned")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(mrzLine)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .lineLimit(2)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    private var mrzLine: String {
        let num = document.number.uppercased().filter { $0.isLetter || $0.isNumber }
        let base = "\(document.type.shortLabel.uppercased())<<\(num)<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        return String(base.prefix(30)) + "\n" + String(repeating: "<", count: 30)
    }

    private func field(_ label: String, _ value: String, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .kerning(1)
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
        }
    }
}

private struct OptionalTilt: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled { content.tiltRotation(6) } else { content }
    }
}

/// Fine wave pattern reminiscent of banknote / ID guilloche.
struct GuillochePattern: View {
    var color: Color

    var body: some View {
        Canvas { ctx, size in
            for i in 0..<14 {
                var p = Path()
                let phase = Double(i) * 0.45
                let yBase = Double(size.height) * (0.15 + Double(i) * 0.055)
                p.move(to: CGPoint(x: 0, y: yBase))
                for x in stride(from: 0.0, through: Double(size.width), by: 6) {
                    let y = yBase + sin(x / 22 + phase) * 9 + cos(x / 47 + phase) * 6
                    p.addLine(to: CGPoint(x: x, y: y))
                }
                ctx.stroke(p, with: .color(color.opacity(0.35)), lineWidth: 0.6)
            }
        }
    }
}
