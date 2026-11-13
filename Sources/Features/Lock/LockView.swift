import SwiftUI

struct LockView: View {
    @Environment(AppLock.self) private var lock
    @Environment(\.scenePhase) private var scenePhase
    @State private var needsPrompt = true
    @State private var floating = false

    var body: some View {
        ZStack {
            DotGridBackground(glow: Theme.accent, glowCenter: UnitPoint(x: 0.5, y: 0.42), glowStrength: 0.2)

            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    Folder3DView(title: "Folio", count: 0, symbols: ["person.text.rectangle.fill", "book.closed.fill"], isFocused: true)
                        .rotation3DEffect(.degrees(floating ? -10 : 10), axis: (x: 0.2, y: 1, z: 0), perspective: 0.5)
                        .offset(y: floating ? -8 : 8)
                        .tiltRotation(12)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .glassEffect(.regular.tint(.black.opacity(0.3)), in: .circle)
                        .offset(y: 30)
                }
                .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: floating)

                Text(tr("Folio is locked"))
                    .font(.system(size: 26, weight: .regular))
                    .padding(.top, 44)
                Text(tr("Your documents stay encrypted on this iPhone."))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 6)
                if let error = lock.lastError {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.badge)
                        .padding(.top, 10)
                }
                Spacer()
                Button {
                    Task { await lock.unlock() }
                } label: {
                    Label(tr("Unlock with %@", lock.biometryName), systemImage: lock.biometrySymbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 26)
                        .frame(height: 56)
                }
                .buttonStyle(PressScaleStyle())
                .glassEffect(.regular.tint(Theme.accent).interactive(), in: .capsule)
                .disabled(lock.isAuthenticating)
                .padding(.bottom, 40)
            }
            .foregroundStyle(.white)
        }
        .onAppear {
            floating = true
            if scenePhase == .active && needsPrompt {
                needsPrompt = false
                Task { await lock.unlock() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { needsPrompt = true }
            if phase == .active && needsPrompt {
                needsPrompt = false
                Task { await lock.unlock() }
            }
        }
    }
}
