import SwiftUI
import CoreMotion
import Observation

/// Publishes a smoothed device tilt in -1...1 for parallax and specular highlights.
/// The neutral position slowly follows how the phone is held, so any grip feels "flat".
@Observable
final class TiltManager {
    var roll: Double = 0
    var pitch: Double = 0

    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private var baseRoll: Double?
    @ObservationIgnored private var basePitch: Double = 0
    @ObservationIgnored private var smoothRoll: Double = 0
    @ObservationIgnored private var smoothPitch: Double = 0

    func start() {
        guard motion.isDeviceMotionAvailable,
              !motion.isDeviceMotionActive,
              !UIAccessibility.isReduceMotionEnabled else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let attitude = data?.attitude else { return }
            self.ingest(roll: attitude.roll, pitch: attitude.pitch)
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        baseRoll = nil
    }

    private func ingest(roll r: Double, pitch p: Double) {
        if baseRoll == nil { baseRoll = r; basePitch = p }
        guard let base = baseRoll else { return }
        // Neutral drifts toward the current grip (~2 s time constant).
        baseRoll = base + (r - base) * 0.008
        basePitch += (p - basePitch) * 0.008

        let targetRoll = max(-1, min(1, (r - base) / 0.5))
        let targetPitch = max(-1, min(1, (p - basePitch) / 0.5))
        smoothRoll += (targetRoll - smoothRoll) * 0.18
        smoothPitch += (targetPitch - smoothPitch) * 0.18

        // Only publish meaningful changes, so idle phones don't redraw.
        if abs(smoothRoll - roll) > 0.003 { roll = smoothRoll }
        if abs(smoothPitch - pitch) > 0.003 { pitch = smoothPitch }
    }
}

/// Shifts content opposite to the tilt, for depth.
struct TiltParallax: ViewModifier {
    @Environment(TiltManager.self) private var tilt
    var amount: CGFloat

    func body(content: Content) -> some View {
        content.offset(x: CGFloat(tilt.roll) * amount, y: CGFloat(tilt.pitch) * amount)
    }
}

/// Rotates content in 3D following the tilt, like holding a real card.
struct TiltRotation: ViewModifier {
    @Environment(TiltManager.self) private var tilt
    var degrees: Double = 7

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(tilt.roll * degrees), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(-tilt.pitch * degrees), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
    }
}

/// Moving specular highlight across glass-like surfaces.
struct ShineOverlay: View {
    @Environment(TiltManager.self) private var tilt
    var intensity: Double = 0.22

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .white.opacity(intensity), location: 0.5),
                .init(color: .clear, location: 1),
            ],
            startPoint: UnitPoint(x: -0.6 + tilt.roll * 0.6, y: -0.4 + tilt.pitch * 0.4),
            endPoint: UnitPoint(x: 0.6 + tilt.roll * 0.6, y: 1.0 + tilt.pitch * 0.4)
        )
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}

extension View {
    func tiltParallax(_ amount: CGFloat) -> some View { modifier(TiltParallax(amount: amount)) }
    func tiltRotation(_ degrees: Double = 7) -> some View { modifier(TiltRotation(degrees: degrees)) }
}
