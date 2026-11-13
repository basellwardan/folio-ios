import SwiftUI

/// Near-black canvas with a fine dot grid and a soft green glow, matching the reference design.
struct DotGridBackground: View {
    var glow: Color = Theme.accent
    var glowCenter: UnitPoint = UnitPoint(x: 0.55, y: 0.48)
    var glowStrength: Double = 0.16

    var body: some View {
        ZStack {
            Theme.background
            RadialGradient(
                colors: [glow.opacity(glowStrength), glow.opacity(glowStrength * 0.25), .clear],
                center: glowCenter,
                startRadius: 0,
                endRadius: 420
            )
            .animation(.smooth(duration: 0.8), value: glowCenter)
            DotGrid()
                .padding(-24)
                .tiltParallax(-8)
            // Top and bottom vignettes for depth
            LinearGradient(colors: [.black.opacity(0.45), .clear, .clear, .black.opacity(0.55)],
                           startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct DotGrid: View {
    var spacing: CGFloat = 16
    var dot: CGFloat = 1.3
    var opacity: Double = 0.085

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            var path = Path()
            var y: CGFloat = spacing / 2
            while y < size.height {
                var x: CGFloat = spacing / 2
                while x < size.width {
                    path.addEllipse(in: CGRect(x: x, y: y, width: dot, height: dot))
                    x += spacing
                }
                y += spacing
            }
            context.fill(path, with: .color(.white.opacity(opacity)))
        }
    }
}

/// Covers content in the app switcher.
struct PrivacyShield: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            LogoMark(size: 84)
        }
    }
}

/// White disc with the Folio glyph (top-left of the home screen).
struct LogoMark: View {
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle().fill(.white)
            Image(systemName: "folder.fill")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(.black)
                .offset(y: size * 0.01)
            Circle()
                .fill(Theme.accent)
                .frame(width: size * 0.16, height: size * 0.16)
                .offset(x: size * 0.17, y: size * 0.12)
        }
        .frame(width: size, height: size)
        .shadow(color: .white.opacity(0.18), radius: 16)
    }
}
