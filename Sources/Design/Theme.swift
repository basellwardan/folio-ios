import SwiftUI

enum Theme {
    static let background = Color(red: 0.043, green: 0.043, blue: 0.047)
    static let surface = Color(white: 0.11)
    static let accent = Color(red: 0.231, green: 0.882, blue: 0.420)      // #3BE16B
    static let accentDeep = Color(red: 0.086, green: 0.560, blue: 0.239)  // #168F3D
    static let badge = Color(red: 1.0, green: 0.231, blue: 0.188)        // iOS red
    static let warn = Color(red: 1.0, green: 0.784, blue: 0.239)         // #FFC83D
    static let info = Color(red: 0.25, green: 0.80, blue: 1.0)           // #40CCFF
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.32)
    static let hairline = Color.white.opacity(0.12)
}

enum Motion {
    static let snappy = Animation.spring(response: 0.38, dampingFraction: 0.82)
    static let bouncy = Animation.spring(response: 0.52, dampingFraction: 0.66)
    static let smooth = Animation.smooth(duration: 0.5)
    static func stagger(_ index: Int, base: Animation = Motion.bouncy) -> Animation {
        base.delay(Double(min(index, 10)) * 0.055)
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: Double
        if cleaned.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        } else {
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}

extension Date {
    var shortFormatted: String { formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()) }
    var mediumFormatted: String { formatted(.dateTime.day().month(.abbreviated).year()) }
}

/// Button style that adds a quick, springy press-down; used with glass and 3D objects.
struct PressScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.95
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
