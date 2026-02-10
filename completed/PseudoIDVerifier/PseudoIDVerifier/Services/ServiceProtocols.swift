@preconcurrency import Dependencies
@preconcurrency import DependenciesMacros
import Foundation
import LocalAuthentication

// MARK: - Transport Service Client

/// Dependency client abstracting transport operations (BLE / MPC) for dependency injection.
/// Uses closure-based endpoints following the Point-Free DependencyClient pattern.
@DependencyClient
nonisolated struct TransportServiceClient: Sendable {
    // MARK: - State Access
    var connectionState: @Sendable () -> ConnectionState = { .disconnected }
    var error: @Sendable () -> TransportError? = { nil }

    // MARK: - Callback Registration
    var setOnRequestReceived: @Sendable (@escaping (DeviceRequest) -> Void) -> Void
    var setOnResponseReceived: @Sendable (@escaping (DeviceResponse) -> Void) -> Void
    var setOnConnected: @Sendable (@escaping () -> Void) -> Void
    var setOnDisconnected: @Sendable (@escaping () -> Void) -> Void

    // MARK: - Central Mode (Reader)
    var startCentralMode: @Sendable (_ targetUUID: UUID?) -> Void
    var stopCentralMode: @Sendable () -> Void
    var sendRequest: @Sendable (DeviceRequest) -> Void

    // MARK: - Peripheral Mode (Holder)
    var startPeripheralMode: @Sendable () -> Void
    var stopPeripheralMode: @Sendable () -> Void
    var sendResponse: @Sendable (DeviceResponse) -> Void
}

// MARK: - NFC Service Client

/// Dependency client abstracting NFC operations for dependency injection.
@DependencyClient
nonisolated struct NFCServiceClient: Sendable {
    var isScanning: @Sendable () -> Bool = { false }
    var isNFCAvailable: @Sendable () -> Bool = { false }

    var setOnEngagementReceived: @Sendable (@escaping (DeviceEngagement, Data) -> Void) -> Void
    var setOnError: @Sendable (@escaping (NFCError) -> Void) -> Void

    var startReaderSession: @Sendable () -> Void
    var stopReaderSession: @Sendable () -> Void
}

// MARK: - Authentication Service Client

/// Dependency client abstracting biometric authentication for dependency injection.
@DependencyClient
nonisolated struct AuthenticationServiceClient: Sendable {
    var isAuthenticated: @Sendable () -> Bool = { false }
    var isBiometricAvailable: @Sendable () -> Bool = { false }
    var biometricType: @Sendable () -> LABiometryType = { .none }

    var authenticate: @Sendable (_ reason: String) async throws -> Bool

    var resetAuthentication: @Sendable () -> Void
}
