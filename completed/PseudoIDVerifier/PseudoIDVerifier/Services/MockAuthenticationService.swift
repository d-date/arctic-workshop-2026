import Foundation
import LocalAuthentication

// MARK: - Mock Authentication Service for Simulator

/// Simulates biometric authentication for use on the iOS Simulator
class MockAuthenticationService: AuthenticationServiceProtocol {
    private(set) var isAuthenticated = false
    var authenticationError: AuthError?

    var shouldSucceed = true
    var simulatedDelay: TimeInterval = 0.5

    var isBiometricAvailable: Bool { true }
    var biometricType: LABiometryType { .faceID }

    func authenticateForDisclosure(
        reason: String,
        completion: @escaping (Result<Void, AuthError>) -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + simulatedDelay) { [weak self] in
            guard let self = self else { return }

            if self.shouldSucceed {
                self.isAuthenticated = true
                self.authenticationError = nil
                completion(.success(()))
            } else {
                self.isAuthenticated = false
                let error = AuthError.authenticationFailed
                self.authenticationError = error
                completion(.failure(error))
            }
        }
    }

    func resetAuthentication() {
        isAuthenticated = false
        authenticationError = nil
    }
}
