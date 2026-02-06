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

Select **Up to Next Major Version** starting from `1.6.0`, then add both the `Dependencies` and `DependenciesMacros` products to the `PseudoIDVerifier` target.

## Step 2: Define Dependency Clients with @DependencyClient

Create `Services/ServiceProtocols.swift` with a `@DependencyClient` struct for each hardware-dependent service. Instead of protocols, we use **structs with closure properties** — this is Point-Free's recommended pattern:

```swift
import Dependencies
import DependenciesMacros
import Foundation
import LocalAuthentication

@DependencyClient
struct BLEServiceClient: Sendable {
    var connectionState: @Sendable () -> BLEConnectionState = { .disconnected }
    var setOnConnected: @Sendable (@escaping () -> Void) -> Void
    var startCentralMode: @Sendable (_ targetUUID: UUID?) -> Void
    var stopCentralMode: @Sendable () -> Void
    var sendRequest: @Sendable (DeviceRequest) -> Void
    var startPeripheralMode: @Sendable () -> Void
    var stopPeripheralMode: @Sendable () -> Void
    var sendResponse: @Sendable (DeviceResponse) -> Void
    // ... additional callbacks omitted for brevity
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

extension BLEServiceClient: DependencyKey {
    static var liveValue: BLEServiceClient {
        #if targetEnvironment(simulator)
        .simulator
        #else
        let service = BLEService.shared
        return BLEServiceClient(
            connectionState: { service.connectionState },
            setOnConnected: { service.onConnected = $0 },
            startCentralMode: { service.startCentralMode(targetUUID: $0) },
            stopCentralMode: { service.stopCentralMode() },
            sendRequest: { service.sendRequest($0) },
            // ...
        )
        #endif
    }

    static var previewValue: BLEServiceClient { .simulator }

    static var simulator: BLEServiceClient {
        // Closure-based mock with delays, no separate class needed
        // ...
    }
}

extension DependencyValues {
    var bleService: BLEServiceClient {
        get { self[BLEServiceClient.self] }
        set { self[BLEServiceClient.self] = newValue }
    }
}
```

The `#if targetEnvironment(simulator)` check in `liveValue` automatically switches to simulator mocks on the Simulator while using real implementations on a physical device.

Apply the same pattern for `nfcService` and `authenticationService`.

## Step 4: Use @Dependency in ViewModels and Views

Replace `SomeService.shared` with `@Dependency`:

```swift
// Before
private let bleService = BLEService.shared

// After
@Dependency(\.bleService) var bleService
```

Since the dependency is a struct with closures, call sites use the closure properties directly:

```swift
// Register callbacks
bleService.setOnConnected { [weak self] in
    // Handle connection
}

// Call methods
bleService.startCentralMode(nil)    // targetUUID is a positional arg
bleService.sendRequest(request)

// Access state via closure call
let type = authService.biometricType()  // Note: () required
```

## Architecture Summary

```
┌──────────────────────────────────────────────────┐
│                  DependencyValues                │
│  ┌────────────────┐ ┌──────────────┐ ┌────────────────────┐
│  │ BLEServiceClient│ │NFCServiceClient│ │AuthServiceClient│
│  └───────┬────────┘ └──────┬───────┘ └────────┬───────────┘
│          │                 │                   │
│      ┌───▼───┐         ┌───▼───┐         ┌────▼────┐
│      │ Live  │         │ Live  │         │  Live   │  ← Real device
│      │.simul │         │.simul │         │ .simul  │  ← Simulator
│      │ test  │         │ test  │         │  test   │  ← Tests (auto)
│      └───────┘         └───────┘         └─────────┘
└──────────────────────────────────────────────────┘
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
        $0.bleService.startCentralMode = { _ in /* mock */ }
        $0.bleService.sendRequest = { _ in /* mock */ }
    } operation: {
        let viewModel = ReaderViewModel()
        viewModel.startReading()
        // Assert state transitions...
    }
}
```

See the [swift-dependencies documentation](https://pointfreeco.github.io/swift-dependencies/main/documentation/dependencies/) for advanced testing patterns.
