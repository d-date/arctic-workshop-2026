import Foundation
import LocalAuthentication

// MARK: - Authentication Service

/// Service for handling biometric authentication for disclosure approval
class AuthenticationService: ObservableObject, AuthenticationServiceProtocol {
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
    func authenticateForDisclosure(
        reason: String = "Approve sharing your information",
        completion: @escaping (Result<Void, AuthError>) -> Void
    ) {
        // Create a fresh context for each authentication
        context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"

        var error: NSError?
        let policy = authenticationPolicy

        guard context.canEvaluatePolicy(policy, error: &error) else {
            let authError = mapError(error)
            DispatchQueue.main.async {
                self.authenticationError = authError
                completion(.failure(authError))
            }
            return
        }

        context.evaluatePolicy(policy, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.isAuthenticated = true
                    self.authenticationError = nil
                    completion(.success(()))
                } else {
                    let authError = self.mapError(error as NSError?)
                    self.isAuthenticated = false
                    self.authenticationError = authError
                    completion(.failure(authError))
                }
            }
        }
    }

    /// Authenticate using async/await
    @MainActor
    func authenticate(reason: String = "Approve sharing your information") async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            authenticateForDisclosure(reason: reason) { result in
                switch result {
                case .success:
                    continuation.resume(returning: true)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
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

    // MARK: - Error Mapping

    private func mapError(_ error: NSError?) -> AuthError {
        guard let error = error else {
            return .unknown("Unknown authentication error")
        }

        if let laError = error as? LAError {
            return AuthError.from(laError)
        }

        // Handle NSError codes that map to LAError
        switch error.code {
        case LAError.biometryNotAvailable.rawValue:
            return .biometricNotAvailable
        case LAError.biometryNotEnrolled.rawValue:
            return .biometricNotEnrolled
        case LAError.authenticationFailed.rawValue:
            return .authenticationFailed
        case LAError.userCancel.rawValue:
            return .userCancelled
        case LAError.passcodeNotSet.rawValue:
            return .passcodeNotSet
        case LAError.systemCancel.rawValue:
            return .systemCancel
        default:
            return .unknown(error.localizedDescription)
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
