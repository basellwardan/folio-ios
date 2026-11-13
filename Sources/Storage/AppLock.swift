import Foundation
import LocalAuthentication
import Observation

@Observable
@MainActor
final class AppLock {
    var isLocked: Bool
    var isAuthenticating = false
    var lastError: String?

    init() {
        isLocked = !LaunchOptions.isDemo
    }

    var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Passcode"
        }
    }

    var biometrySymbol: String {
        biometryName == "Touch ID" ? "touchid" : (biometryName == "Passcode" ? "lock.fill" : "faceid")
    }

    func lockIfNeeded() {
        guard !LaunchOptions.isDemo else { return }
        isLocked = true
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No passcode is set on this device, so there is nothing to authenticate against.
            isLocked = false
            return
        }
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock your documents"
            )
            if ok {
                lastError = nil
                isLocked = false
            }
        } catch {
            lastError = (error as? LAError)?.code == .userCancel ? nil : error.localizedDescription
        }
    }
}
