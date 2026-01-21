import Foundation
import LocalAuthentication

@MainActor
class BiometricAuth {
    private let context = LAContext()
    private var authError: NSError?

    enum BiometricType {
        case none
        case touchID
        case faceID
        case unknown
    }

    func biometricType() -> BiometricType {
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
            switch context.biometryType {
            case .touchID:
                return .touchID
            case .faceID:
                return .faceID
            case .none:
                return .none
            @unknown default:
                return .unknown
            }
        }
        return .none
    }

    func canUseBiometrics() -> Bool {
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError)
    }

    func authenticateUser(reason: String = "Authenticate to access your account") async -> Bool {
        guard canUseBiometrics() else {
            return false
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                if success {
                    continuation.resume(returning: true)
                } else {
                    if let error = error as? LAError {
                        print("Biometric authentication failed: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: false)
                }
            }
        }
    }

    func authenticateWithFallback(reason: String = "Authenticate to access your account") async -> Bool {
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                if success {
                    continuation.resume(returning: true)
                } else {
                    if let error = error as? LAError {
                        print("Authentication failed: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: false)
                }
            }
        }
    }
}