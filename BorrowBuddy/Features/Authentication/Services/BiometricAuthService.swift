//
//  BiometricAuthService.swift
//  BorrowBuddy
//

import LocalAuthentication

@MainActor
final class BiometricAuthService {
    static let shared = BiometricAuthService()

    /// Keep LAContext alive for the duration of an evaluate call.
    private var activeContext: LAContext?

    var biometryAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    var biometryTypeName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Biometrics"
        }
    }

    var availabilityMessage: String? {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return nil
        }
        guard let error else {
            return "\(biometryTypeName) isn't available on this device."
        }
        switch LAError.Code(rawValue: error.code) {
        case .biometryNotEnrolled:
            return "\(biometryTypeName) isn't set up. On Simulator: Features → Face ID → Enrolled. On device: Settings → Face ID & Passcode."
        case .biometryLockout:
            return "\(biometryTypeName) is locked. Unlock your device with your passcode, then try again."
        case .passcodeNotSet:
            return "Set a device passcode in Settings before enabling \(biometryTypeName)."
        case .biometryNotAvailable:
            return "\(biometryTypeName) hardware isn't available here."
        default:
            return error.localizedDescription
        }
    }

    func authenticate(reason: String) async throws -> Bool {
        guard activeContext == nil else {
            throw BiometricError.unavailable("Authentication is already in progress.")
        }
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = "" // Force Face ID / Touch ID — no password fallback sheet.
        activeContext = context

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            activeContext = nil
            if let message = availabilityMessage {
                throw BiometricError.unavailable(message)
            }
            throw error ?? BiometricError.unavailable("\(biometryTypeName) isn't available.")
        }

        var timedOut = false
        let timeoutTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(20))
            } catch {
                return
            }
            timedOut = true
            context.invalidate()
        }
        defer {
            timeoutTask.cancel()
            activeContext = nil
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            activeContext = nil
            return success
        } catch {
            activeContext = nil
            if timedOut {
                #if targetEnvironment(simulator)
                throw BiometricError.failed("Face ID timed out. The simulator needs a simulated face match. Try again or choose Maybe Later.")
                #else
                throw BiometricError.failed("Face ID timed out. Try again or choose Maybe Later.")
                #endif
            }
            let laError = error as? LAError
            switch laError?.code {
            case .userCancel, .appCancel, .systemCancel:
                throw BiometricError.cancelled
            case .userFallback:
                throw BiometricError.cancelled
            case .biometryNotEnrolled:
                throw BiometricError.unavailable(availabilityMessage ?? error.localizedDescription)
            default:
                throw BiometricError.failed(error.localizedDescription)
            }
        }
    }
}

enum BiometricError: LocalizedError {
    case unavailable(String)
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let message): return message
        case .cancelled: return "Face ID was cancelled."
        case .failed(let message): return message
        }
    }
}
