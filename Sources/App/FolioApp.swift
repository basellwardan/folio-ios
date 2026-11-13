import SwiftUI
import SwiftData

@main
struct FolioApp: App {
    @State private var lock = AppLock()
    @State private var tilt = TiltManager()
    @Environment(\.scenePhase) private var scenePhase

    let container: ModelContainer

    init() {
        let schema = Schema([Person.self, VaultDocument.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: LaunchOptions.isDemo)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not open the document store: \(error)")
        }
        if LaunchOptions.isDemo {
            DemoData.seed(into: container.mainContext)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(lock)
                .environment(tilt)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                tilt.start()
            case .background:
                tilt.stop()
                lock.lockIfNeeded()
            default:
                break
            }
        }
    }
}

/// Hosts the app content, the lock screen and the app-switcher privacy shield.
struct RootView: View {
    @Environment(AppLock.self) private var lock
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            HomeView()

            if lock.isLocked {
                LockView()
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity.combined(with: .scale(scale: 1.15))
                    ))
                    .zIndex(2)
            }

            if scenePhase != .active && !lock.isLocked {
                PrivacyShield()
                    .transition(.opacity)
                    .zIndex(3)
            }
        }
        .animation(.smooth(duration: 0.5), value: lock.isLocked)
        .animation(.easeOut(duration: 0.2), value: scenePhase)
    }
}

enum LaunchOptions {
    /// `-demoData YES` loads sample people in memory and skips the lock (used for CI screenshots).
    static var isDemo: Bool { ProcessInfo.processInfo.arguments.contains("-demoData") }
    /// `-screen <name>` opens a specific screen in demo mode.
    static var screen: String? { UserDefaults.standard.string(forKey: "screen") }
}
