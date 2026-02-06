# Simulator Testing with Dependency Injection

Run the full verification flow on the iOS Simulator by mocking hardware-dependent services with swift-dependencies.

## Overview

The PseudoIDVerifier app relies on three hardware features that are unavailable on the iOS Simulator:

| Service | Hardware | Framework |
|---------|----------|-----------|
| `BLEService` | Bluetooth Low Energy | CoreBluetooth |
| `NFCService` | NFC reader | CoreNFC |
| `AuthenticationService` | Face ID / Touch ID | LocalAuthentication |

To run the app on the Simulator (or in SwiftUI Previews and unit tests), we use **[swift-dependencies](https://github.com/pointfreeco/swift-dependencies)** from Point-Free to inject mock implementations that simulate the entire flow.

## Step 1: Add swift-dependencies to the Project

In Xcode, go to **File > Add Package Dependencies** and enter:

```
https://github.com/pointfreeco/swift-dependencies.git
```

Select **Up to Next Major Version** starting from `1.6.0`, then add the `Dependencies` product to the `PseudoIDVerifier` target.

## Step 2: Define Service Protocols

Create `Services/ServiceProtocols.swift` with a protocol for each hardware-dependent service:

```swift
import Foundation
import LocalAuthentication

protocol BLEServiceProtocol: AnyObject {
    var connectionState: BLEConnectionState { get }
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

protocol NFCServiceProtocol: AnyObject {
    var isNFCAvailable: Bool { get }
    var onEngagementReceived: ((DeviceEngagement, Data) -> Void)? { get set }
    func startReaderSession()
    func stopReaderSession()
}

protocol AuthenticationServiceProtocol: AnyObject {
    var isBiometricAvailable: Bool { get }
    var biometricType: LABiometryType { get }
    func authenticateForDisclosure(
        reason: String,
        completion: @escaping (Result<Void, AuthError>) -> Void
    )
    func resetAuthentication()
}
```

Then make each existing service conform:

```swift
class BLEService: NSObject, ObservableObject, BLEServiceProtocol { ... }
class NFCService: NSObject, ObservableObject, NFCServiceProtocol { ... }
class AuthenticationService: ObservableObject, AuthenticationServiceProtocol { ... }
```

> Note: `CBORService` and `CryptoService` do not depend on hardware and do not need protocols or mocks.

## Step 3: Create Mock Implementations

Each mock simulates the real service's behavior with short delays.

### MockBLEService

The Reader-side mock auto-generates a `DeviceResponse` from `DummyCredentials` when `sendRequest(_:)` is called. The Presentment-side mock auto-generates an age verification `DeviceRequest` when `startPeripheralMode()` is called.

```swift
class MockBLEService: BLEServiceProtocol {
    func startCentralMode(targetUUID: UUID? = nil) {
        connectionState = .scanning
        // Simulate connection after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.connectionState = .connected
            self.onConnected?()
        }
    }

    func sendRequest(_ request: DeviceRequest) {
        // Auto-generate response from DummyCredentials
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let credential = DummyCredentials.createSampleMDL()
            let selective = CBORService.shared.createSelectiveResponse(
                from: credential, for: request
            )
            // ... build DeviceResponse and call onResponseReceived
        }
    }
}
```

### MockAuthenticationService

Always succeeds with simulated Face ID:

```swift
class MockAuthenticationService: AuthenticationServiceProtocol {
    var biometricType: LABiometryType { .faceID }

    func authenticateForDisclosure(reason: String,
                                   completion: @escaping (Result<Void, AuthError>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(.success(()))
        }
    }
}
```

## Step 4: Register Dependencies with DependencyKey

Create `Services/ServiceDependencies.swift`:

```swift
import Dependencies

private enum BLEServiceKey: DependencyKey {
    static var liveValue: any BLEServiceProtocol {
        #if targetEnvironment(simulator)
        MockBLEService()
        #else
        BLEService.shared
        #endif
    }
    static var previewValue: any BLEServiceProtocol { MockBLEService() }
    static var testValue: any BLEServiceProtocol { MockBLEService() }
}

extension DependencyValues {
    var bleService: any BLEServiceProtocol {
        get { self[BLEServiceKey.self] }
        set { self[BLEServiceKey.self] = newValue }
    }
}
```

The `#if targetEnvironment(simulator)` check in `liveValue` automatically switches to mocks on the Simulator while using real implementations on a physical device.

Apply the same pattern for `nfcService` and `authenticationService`.

## Step 5: Use @Dependency in ViewModels and Views

Replace `SomeService.shared` with `@Dependency`:

```swift
// Before
private let bleService = BLEService.shared

// After
@Dependency(\.bleService) private var bleService
```

The protocol type ensures the ViewModel code works identically whether it receives a live or mock service.

## Architecture Summary

```
┌──────────────────────────────────────────────────┐
│                  DependencyValues                │
│  ┌────────────┐ ┌────────────┐ ┌──────────────┐ │
│  │ bleService │ │ nfcService │ │ authService  │ │
│  └─────┬──────┘ └─────┬──────┘ └──────┬───────┘ │
│        │              │               │          │
│    ┌───▼───┐      ┌───▼───┐      ┌────▼────┐    │
│    │ Live  │      │ Live  │      │  Live   │    │  ← Real device
│    │ Mock  │      │ Mock  │      │  Mock   │    │  ← Simulator
│    └───────┘      └───────┘      └─────────┘    │
└──────────────────────────────────────────────────┘
```

## Running on the Simulator

1. Select the **iPhone 17 Pro** simulator in Xcode
2. Build and run (**Cmd+R**)
3. Choose **Reader** mode → tap **Start Reading** → the mock simulates connection and returns verified attributes
4. Choose **Presentment** mode → tap **Present ID** → the mock simulates a reader connecting, sending a request, and displaying the disclosure approval screen

Both flows complete end-to-end without any real BLE, NFC, or biometric hardware.

## Next Steps

With dependency injection in place, you can also write unit tests for the ViewModels by injecting custom mock configurations:

```swift
@Test func readerReceivesVerifiedAttributes() async {
    await withDependencies {
        $0.bleService = MockBLEService()
    } operation: {
        let viewModel = ReaderViewModel()
        viewModel.startReading()
        // Assert state transitions...
    }
}
```

See the [swift-dependencies documentation](https://pointfreeco.github.io/swift-dependencies/main/documentation/dependencies/) for advanced testing patterns.
