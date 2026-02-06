import Foundation
import LocalAuthentication

// MARK: - BLE Service Protocol

/// Protocol abstracting BLE operations for dependency injection
protocol BLEServiceProtocol: AnyObject {
    var connectionState: BLEConnectionState { get }
    var error: BLEError? { get }

    var onRequestReceived: ((DeviceRequest) -> Void)? { get set }
    var onResponseReceived: ((DeviceResponse) -> Void)? { get set }
    var onConnected: (() -> Void)? { get set }
    var onDisconnected: (() -> Void)? { get set }

    func startCentralMode(targetUUID: UUID?)
    func stopCentralMode()
    func sendRequest(_ request: DeviceRequest)

    func startPeripheralMode()
    func stopPeripheralMode()
    func sendResponse(_ response: DeviceResponse)
}

extension BLEServiceProtocol {
    func startCentralMode() { startCentralMode(targetUUID: nil) }
}

// MARK: - NFC Service Protocol

/// Protocol abstracting NFC operations for dependency injection
protocol NFCServiceProtocol: AnyObject {
    var isScanning: Bool { get }
    var isNFCAvailable: Bool { get }

    var onEngagementReceived: ((DeviceEngagement, Data) -> Void)? { get set }
    var onError: ((NFCError) -> Void)? { get set }

    func startReaderSession()
    func stopReaderSession()
}

// MARK: - Authentication Service Protocol

/// Protocol abstracting biometric authentication for dependency injection
protocol AuthenticationServiceProtocol: AnyObject {
    var isAuthenticated: Bool { get }
    var isBiometricAvailable: Bool { get }
    var biometricType: LABiometryType { get }

    func authenticateForDisclosure(
        reason: String,
        completion: @escaping (Result<Void, AuthError>) -> Void
    )
    func resetAuthentication()
}
