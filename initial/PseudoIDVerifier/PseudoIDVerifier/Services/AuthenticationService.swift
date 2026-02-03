import Foundation
import LocalAuthentication

// MARK: - Authentication Service

/// Service for handling biometric authentication for disclosure approval
class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()

    // MARK: - Published State

    @Published var isAuthenticated = false
    @Published var authenticationError: AuthError?

    // MARK: - LAContext

    private var context = LAContext()

    private init() {}

    // MARK: - Biometric Authentication

    /// Check if biometric authentication is available
    var isBiometricAvailable: Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Get the type of biometric available
    var biometricType: LABiometryType {
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    /// Authenticate user for disclosure approval
    /// - Parameters:
    ///   - reason: The reason shown to the user
    ///   - completion: Called with result (success or error)
    func authenticateForDisclosure(
        reason: String = "Approve sharing your information",
        completion: @escaping (Result<Void, AuthError>) -> Void
    ) {
        // TODO: Implement biometric authentication
        //
        // Steps:
        // 1. Create a new LAContext
        // 2. Check if biometrics are available
        // 3. If not, fall back to device passcode
        // 4. Call evaluatePolicy with localizedReason
        // 5. Handle the result on main thread
        //
        // Hint:
        // context.evaluatePolicy(
        //     .deviceOwnerAuthenticationWithBiometrics,
        //     localizedReason: reason
        // ) { success, error in
        //     ...
        // }

        fatalError("Not implemented - Complete this in Chapter 6")
    }

    /// Authenticate using async/await
    /// - Parameter reason: The reason shown to the user
    /// - Returns: true if authentication succeeded
    @MainActor
    func authenticate(reason: String = "Approve sharing your information") async throws -> Bool {
        // TODO: Implement async authentication
        //
        // Wrap the completion-based method in withCheckedThrowingContinuation

        fatalError("Not implemented - Complete this in Chapter 6")
    }

    /// Reset authentication state
    func resetAuthentication() {
        context = LAContext()
        isAuthenticated = false
        authenticationError = nil
    }

    // MARK: - Policy Selection

    /// Get the appropriate authentication policy based on device capabilities
    private var authenticationPolicy: LAPolicy {
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

enum AuthError: LocalizedError {
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
