# Simulator Testing with Dependency Injection

Run the full verification flow on the iOS Simulator by mocking hardware-dependent services with swift-dependencies.

## Overview

The PseudoIDVerifier app relies on three hardware features that are unavailable on the iOS Simulator:

| Service | Hardware | Framework |
|---------|----------|-----------|
| `BLEService` / `MPCService` | Bluetooth Low Energy / Multipeer Connectivity | CoreBluetooth / MultipeerConnectivity |
| `NFCService` | NFC reader | CoreNFC |
| `AuthenticationService` | Face ID / Touch ID | LocalAuthentication |

To run the app on the Simulator (or in SwiftUI Previews and unit tests), we use **[swift-dependencies](https://github.com/pointfreeco/swift-dependencies)** from Point-Free to inject mock implementations that simulate the entire flow.

## Step 1: Add swift-dependencies to the Project

In Xcode, go to **File > Add Package Dependencies** and enter:

```
https://github.com/pointfreeco/swift-dependencies.git
```

Select **Up to Next Major Version** starting from `1.6.0`, then add both the `Dependencies` and `DependenciesMacros` products to the `PseudoIDVerifier` target.

## Step 2: Define Dependency Clients with @DependencyClient

Create `Services/ServiceProtocols.swift` with a `@DependencyClient` struct for each hardware-dependent service. Instead of protocols, we use **structs with closure properties** — this is Point-Free's recommended pattern:

```swift
import Dependencies
import DependenciesMacros
import Foundation
import LocalAuthentication

@DependencyClient
struct TransportServiceClient: Sendable {
    var connectionState: @Sendable () -> ConnectionState = { .disconnected }
    var error: @Sendable () -> TransportError? = { nil }
    var setOnRequestReceived: @Sendable (@escaping (DeviceRequest) -> Void) -> Void
    var setOnResponseReceived: @Sendable (@escaping (DeviceResponse) -> Void) -> Void
    var setOnConnected: @Sendable (@escaping () -> Void) -> Void
    var setOnDisconnected: @Sendable (@escaping () -> Void) -> Void
    var startCentralMode: @Sendable (_ targetUUID: UUID?) -> Void
    var stopCentralMode: @Sendable () -> Void
    var sendRequest: @Sendable (DeviceRequest) -> Void
    var startPeripheralMode: @Sendable () -> Void
    var stopPeripheralMode: @Sendable () -> Void
    var sendResponse: @Sendable (DeviceResponse) -> Void
}

@DependencyClient
struct AuthenticationServiceClient: Sendable {
    var isBiometricAvailable: @Sendable () -> Bool = { false }
    var biometricType: @Sendable () -> LABiometryType = { .none }
    var authenticateForDisclosure: @Sendable (
        _ reason: String,
        _ completion: @escaping (Result<Void, AuthError>) -> Void
    ) -> Void
    var resetAuthentication: @Sendable () -> Void
}
```

The `@DependencyClient` macro automatically generates `testValue` with _unimplemented_ closures that fail in tests if called unexpectedly — no need to write separate mock classes.

> Note: `CBORService` and `CryptoService` do not depend on hardware and do not need dependency clients.

## Step 3: Register liveValue and Simulator Mocks

Create `Services/ServiceDependencies.swift`. Each client struct conforms to `DependencyKey` and provides a `liveValue`:

```swift
import Dependencies

extension TransportServiceClient: DependencyKey {
    static var liveValue: TransportServiceClient {
        #if targetEnvironment(simulator)
        .simulator
        #elseif USE_MPC
        .mpc(MPCService.shared)
        #else
        .ble(BLEService.shared)
        #endif
    }

    static var previewValue: TransportServiceClient { .simulator }

    /// BLE backing implementation using CoreBluetooth
    static func ble(_ service: BLEService) -> TransportServiceClient {
        TransportServiceClient(
            connectionState: { service.connectionState },
            setOnConnected: { service.onConnected = $0 },
            startCentralMode: { service.startCentralMode(targetUUID: $0) },
            // ...
        )
    }

    /// MPC backing implementation using MultipeerConnectivity
    static func mpc(_ service: MPCService) -> TransportServiceClient {
        TransportServiceClient(
            connectionState: { service.connectionState },
            setOnConnected: { service.onConnected = $0 },
            startCentralMode: { _ in service.startBrowsing() },
            // ...
        )
    }

    static var simulator: TransportServiceClient {
        // Closure-based mock with delays, no separate class needed
        // ...
    }
}

extension DependencyValues {
    var transportService: TransportServiceClient {
        get { self[TransportServiceClient.self] }
        set { self[TransportServiceClient.self] = newValue }
    }
}
```

The `#if targetEnvironment(simulator)` check in `liveValue` automatically switches to simulator mocks on the Simulator while using real implementations on a physical device.

Apply the same pattern for `nfcService` and `authenticationService`.

## Step 4: Use @Dependency in ViewModels and Views

Replace `SomeService.shared` with `@Dependency`:

```swift
// Before (direct singleton reference)
private let transportService = BLEService.shared

// After (dependency injection — backs BLE, MPC, or simulator automatically)
@Dependency(\.transportService) var transportService
```

Since the dependency is a struct with closures, call sites use the closure properties directly. The same code works regardless of whether BLE, MPC, or the simulator mock is backing the transport:

```swift
// Register callbacks
transportService.setOnConnected { [weak self] in
    // Handle connection
}

// Call methods
transportService.startCentralMode(nil)    // targetUUID is a positional arg
transportService.sendRequest(request)

// Access state via closure call
let type = authService.biometricType()  // Note: () required
```

## Architecture Summary

```
┌─────────────────────────────────────────────────────────┐
│                     DependencyValues                    │
│  ┌──────────────────────┐ ┌──────────────┐ ┌──────────────────┐
│  │TransportServiceClient│ │NFCServiceClient│ │AuthServiceClient│
│  └──────────┬───────────┘ └──────┬───────┘ └────────┬─────────┘
│             │                    │                   │
│     ┌───────┼────────┐      ┌───▼───┐         ┌────▼────┐
│     │       │        │      │ Live  │         │  Live   │
│  ┌──▼──┐ ┌──▼──┐ ┌───▼──┐  │.simul │         │ .simul  │
│  │.ble │ │.mpc │ │.simul│  │ test  │         │  test   │
│  └─────┘ └─────┘ └──────┘  └───────┘         └─────────┘
│   BLE     MPC    Simulator
└─────────────────────────────────────────────────────────┘
```

## Running on the Simulator

1. Select the **iPhone 17 Pro** simulator in Xcode
2. Build and run (**Cmd+R**)
3. Choose **Reader** mode → tap **Start Reading** → the mock simulates connection and returns verified attributes
4. Choose **Presentment** mode → tap **Present ID** → the mock simulates a reader connecting, sending a request, and displaying the disclosure approval screen

Both flows complete end-to-end without any real BLE, NFC, or biometric hardware.

## Next Steps

With `@DependencyClient`, unit testing is straightforward. The macro generates `testValue` with unimplemented closures, so you only override what you need:

```swift
@Test func readerReceivesVerifiedAttributes() async {
    await withDependencies {
        $0.transportService.startCentralMode = { _ in /* mock */ }
        $0.transportService.sendRequest = { _ in /* mock */ }
    } operation: {
        let viewModel = ReaderViewModel()
        viewModel.startReading()
        // Assert state transitions...
    }
}
```

See the [swift-dependencies documentation](https://pointfreeco.github.io/swift-dependencies/main/documentation/dependencies/) for advanced testing patterns.
