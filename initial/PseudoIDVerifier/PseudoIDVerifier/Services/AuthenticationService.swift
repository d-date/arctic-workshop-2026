import Foundation
import Observation
import LocalAuthentication

// MARK: - Authentication Service

/// Service for handling biometric authentication for disclosure approval
@Observable
class AuthenticationService: @unchecked Sendable {
    static let shared = AuthenticationService()

    // MARK: - Observable State

    @ObservationIgnored nonisolated(unsafe) var isAuthenticated = false
    @ObservationIgnored nonisolated(unsafe) var authenticationError: AuthError?

    // MARK: - LAContext

    @ObservationIgnored nonisolated(unsafe) private var context = LAContext()

    private init() {}

    // ┌──────────────────────────────────────────────────────┐
    // │  Biometric Authentication                            │
    // │  📖 See: BiometricAuthentication > Step 1            │
    // └──────────────────────────────────────────────────────┘

    // MARK: - Biometric Authentication

    /// Check if biometric authentication is available
    nonisolated var isBiometricAvailable: Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Get the type of biometric available
    nonisolated var biometricType: LABiometryType {
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    // MARK: - 📋 PASTE: <doc:BiometricAuthentication> Step 1 — authenticateForDisclosure

    /// Authenticate user for disclosure approval
    /// - Parameters:
    ///   - reason: The reason shown to the user
    ///   - completion: Called with result (success or error)
    nonisolated func authenticateForDisclosure(
        reason: String = "Approve sharing your information",
        completion: @escaping @Sendable (Result<Void, AuthError>) -> Void
    ) {
        // ✏️ Paste your implementation here
        //
        // Steps:
        // 1. Create a fresh LAContext
        // 2. Set localizedFallbackTitle
        // 3. Check if policy can be evaluated
        // 4. Call evaluatePolicy with localizedReason
        // 5. Handle the result on main thread

        fatalError("Not implemented — Paste code from <doc:BiometricAuthentication> Step 1")
    }

    // MARK: - 📋 PASTE: <doc:BiometricAuthentication> Step 1 — authenticate (async)

    /// Authenticate using async/await
    /// - Parameter reason: The reason shown to the user
    /// - Returns: true if authentication succeeded
    nonisolated func authenticate(reason: String = "Approve sharing your information") async throws -> Bool {
        // ✏️ Paste your implementation here
        //
        // Wrap authenticateForDisclosure in withCheckedThrowingContinuation

        fatalError("Not implemented — Paste code from <doc:BiometricAuthentication> Step 1")
    }

    /// Reset authentication state
    nonisolated func resetAuthentication() {
        context = LAContext()
        isAuthenticated = false
        authenticationError = nil
    }

    // MARK: - Policy Selection

    /// Get the appropriate authentication policy based on device capabilities
    nonisolated private var authenticationPolicy: LAPolicy {
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return .deviceOwnerAuthenticationWithBiometrics
        } else {
            // Fall back to passcode if biometrics unavailable
            return .deviceOwnerAuthentication
        }
    }
}

// MARK: - Error Types

nonisolated enum AuthError: LocalizedError {
    case biometricNotAvailable
    case biometricNotEnrolled
    case authenticationFailed
    case userCancelled
    case passcodeNotSet
    case systemCancel
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .biometricNotAvailable:
            return "Biometric authentication is not available on this device"
        case .biometricNotEnrolled:
            return "No biometric data is enrolled. Please set up Face ID or Touch ID in Settings."
        case .authenticationFailed:
            return "Authentication failed. Please try again."
        case .userCancelled:
            return "Authentication was cancelled"
        case .passcodeNotSet:
            return "Please set up a device passcode in Settings"
        case .systemCancel:
            return "Authentication was cancelled by the system"
        case .unknown(let message):
            return message
        }
    }

    /// Create AuthError from LAError
    static func from(_ laError: LAError) -> AuthError {
        switch laError.code {
        case .biometryNotAvailable:
            return .biometricNotAvailable
        case .biometryNotEnrolled:
            return .biometricNotEnrolled
        case .authenticationFailed:
            return .authenticationFailed
        case .userCancel:
            return .userCancelled
        case .passcodeNotSet:
            return .passcodeNotSet
        case .systemCancel:
            return .systemCancel
        default:
            return .unknown(laError.localizedDescription)
        }
    }
}

// MARK: - Biometry Type Extension

extension LABiometryType {
    var displayName: String {
        switch self {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "Passcode"
        @unknown default:
            return "Biometric"
        }
    }

    var systemImageName: String {
        switch self {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        case .none:
            return "lock"
        @unknown default:
            return "lock"
        }
    }
}
