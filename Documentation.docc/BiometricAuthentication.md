# Biometric Authentication

Implement Face ID/Touch ID for disclosure approval.

## Overview

Before sharing any data, the holder must explicitly approve the request. We use LocalAuthentication framework to require biometric confirmation.

### Why Biometrics?

1. **User consent**: Proves the holder intentionally approved sharing
2. **Presence verification**: Confirms the holder is physically present
3. **Fraud prevention**: Prevents unauthorized sharing if device is stolen

### Step 1: Create AuthenticationService

> **Initial project**: Open `Services/AuthenticationService.swift`. The scaffolding (properties, error types, biometry extension) is already provided. Find the `📋 PASTE: Step 1` markers for the two methods you need to implement.

Paste the following into `Services/AuthenticationService.swift`:

```swift
import Foundation
import LocalAuthentication

class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()

    @Published var isAuthenticated = false
    @Published var authenticationError: AuthError?

    private var context = LAContext()

    private init() {}

    /// Check if biometrics are available
    var isBiometricAvailable: Bool {
        var error: NSError?
        return context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
    }

    /// Get the biometric type
    var biometricType: LABiometryType {
        _ = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: nil
        )
        return context.biometryType
    }

    /// Authenticate for disclosure approval
    func authenticateForDisclosure(
        reason: String = "Approve sharing your information",
        completion: @escaping (Result<Void, AuthError>) -> Void
    ) {
        // Create fresh context
        context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"

        let policy = authenticationPolicy

        var error: NSError?
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

    /// Async/await version
    @MainActor
    func authenticate(reason: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
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

    private var authenticationPolicy: LAPolicy {
        var error: NSError?
        if context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        ) {
            return .deviceOwnerAuthenticationWithBiometrics
        }
        // Fall back to passcode
        return .deviceOwnerAuthentication
    }

    private func mapError(_ error: NSError?) -> AuthError {
        guard let error = error else {
            return .unknown("Unknown error")
        }

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
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
```

### Step 2: Define Error Types

```swift
enum AuthError: LocalizedError {
    case biometricNotAvailable
    case biometricNotEnrolled
    case authenticationFailed
    case userCancelled
    case passcodeNotSet
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .biometricNotAvailable:
            return "Biometric authentication is not available"
        case .biometricNotEnrolled:
            return "Please set up Face ID or Touch ID in Settings"
        case .authenticationFailed:
            return "Authentication failed. Please try again."
        case .userCancelled:
            return "Authentication was cancelled"
        case .passcodeNotSet:
            return "Please set up a device passcode"
        case .unknown(let message):
            return message
        }
    }
}
```

### Step 3: Add Biometry Type Extension

```swift
extension LABiometryType {
    var displayName: String {
        switch self {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        case .none: return "Passcode"
        @unknown default: return "Biometric"
        }
    }

    var systemImageName: String {
        switch self {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        case .none: return "lock"
        @unknown default: return "lock"
        }
    }
}
```

### Step 4: Integrate with Disclosure Flow

In `PresentmentViewModel`:

```swift
func approveDisclosure() {
    guard let request = pendingRequest else {
        state = .error("No pending request")
        return
    }

    state = .authenticating

    authService.authenticateForDisclosure(
        reason: "Approve sharing your ID information"
    ) { [weak self] result in
        switch result {
        case .success:
            self?.sendResponse(for: request)

        case .failure(let error):
            if case .userCancelled = error {
                // Go back to request view
                self?.state = .requestReceived(request)
            } else {
                self?.state = .error(error.localizedDescription)
            }
        }
    }
}
```

### Step 5: Show Authenticating UI

```swift
struct AuthenticatingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: AuthenticationService.shared.biometricType.systemImageName)
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Authenticating...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}
```

### Testing

1. Run the app on a real device (simulator doesn't support biometrics properly)
2. Ensure Face ID/Touch ID is enrolled
3. Trigger a disclosure request
4. Verify the biometric prompt appears
5. Test approval and cancellation flows

### Security Considerations

1. **Always use a fresh LAContext**: Don't reuse contexts between authentications
2. **Handle all error cases**: Users may have disabled biometrics
3. **Provide fallback**: Use `.deviceOwnerAuthentication` as backup
4. **Clear sensitive data**: Reset state after denial or timeout

## Next Steps

Continue to <doc:IntegrationTesting> to test the complete flow.
