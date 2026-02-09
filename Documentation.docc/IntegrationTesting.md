# Integration Testing

Test the complete verification flow between two devices.

## Overview

Now that all components are implemented, let's test the end-to-end flow between two iPhones.

### Step 0: Implement ViewModels

Before testing, you need to wire up the ViewModels that connect the transport layer (MPC or BLE), CBOR, and Authentication together.

> **Initial project**: Open `Views/ReaderView.swift` and `Views/PresentmentView.swift`. Find the `📋 PASTE: ViewModel Step` markers in the ViewModel classes at the bottom of each file.

#### ReaderViewModel (in ReaderView.swift)

```swift
// ViewModel Step 1: init + setupCallbacks
init() {
    setupCallbacks()
}

private func setupCallbacks() {
    // Handle transport connection (works with both MPC and BLE)
    transportService.onConnected = { [weak self] in
        Task { @MainActor in
            guard let self = self else { return }
            let request = self.selectedScenario.createRequest()
            self.transportService.sendRequest(request)
            self.state = .waitingForResponse
        }
    }

    // Handle response from holder
    transportService.onResponseReceived = { [weak self] response in
        Task { @MainActor in
            self?.handleResponse(response)
        }
    }

    // Handle NFC engagement (optional — only if NFC implemented)
    nfcService.onEngagementReceived = { [weak self] engagement, bleData in
        Task { @MainActor in
            self?.handleEngagementReceived(engagement, bleData: bleData)
        }
    }

    nfcService.onError = { [weak self] error in
        Task { @MainActor in
            self?.state = .error(error.localizedDescription)
        }
    }
}
```

```swift
// ViewModel Step 2: startReading + cancelReading
func startReading() {
    state = .scanning

    // For workshop: skip NFC, go directly to transport layer (MPC or BLE)
    state = .connecting
    transportService.startCentralMode(nil)
}

func cancelReading() {
    nfcService.stopReaderSession()
    transportService.stopCentralMode()
    state = .idle
}
```

```swift
// ViewModel Step 3: handleResponse
private func handleResponse(_ response: DeviceResponse) {
    guard response.status == 0,
          let document = response.documents?.first else {
        state = .error("Invalid response from holder")
        transportService.stopCentralMode()
        return
    }

    // Extract attributes from the response
    var attributes: [String: Any] = [:]
    for (_, items) in document.issuerSigned.nameSpaces {
        for item in items {
            attributes[item.elementIdentifier] = item.elementValue
        }
    }

    state = .success(attributes)
    transportService.stopCentralMode()
}
```

#### PresentmentViewModel (in PresentmentView.swift)

```swift
// ViewModel Step 4: init + setupCallbacks
init() {
    self.credential = DummyCredentials.createSampleMDL()
    setupCallbacks()
}

private func setupCallbacks() {
    transportService.onRequestReceived = { [weak self] request in
        Task { @MainActor in
            self?.pendingRequest = request
            self?.state = .requestReceived(request)
        }
    }

    transportService.onDisconnected = { [weak self] in
        Task { @MainActor in
            if case .advertising = self?.state {
                self?.state = .idle
            }
        }
    }
}
```

```swift
// ViewModel Step 5: startPresenting + cancelPresenting
func startPresenting() {
    state = .advertising
    transportService.startPeripheralMode()
}

func cancelPresenting() {
    transportService.stopPeripheralMode()
    state = .idle
    pendingRequest = nil
}
```

```swift
// ViewModel Step 6: approveDisclosure + sendResponse + denyDisclosure
func approveDisclosure() {
    guard let request = pendingRequest else {
        state = .error("No pending request")
        return
    }

    state = .authenticating

    authService.authenticateForDisclosure(
        reason: "Approve sharing your ID information"
    ) { [weak self] result in
        Task { @MainActor in
            switch result {
            case .success:
                self?.sendResponse(for: request)
            case .failure(let error):
                if case .userCancelled = error {
                    self?.state = .requestReceived(request)
                } else {
                    self?.state = .error(error.localizedDescription)
                }
            }
        }
    }
}

private func sendResponse(for request: DeviceRequest) {
    state = .sending

    let selectiveMDoc = cborService.createSelectiveResponse(
        from: credential, for: request
    )

    let deviceAuth = DeviceAuth(
        deviceMac: nil,
        deviceSignature: CryptoService.shared.devicePublicKeyData
    )
    let deviceSigned = DeviceSigned(
        nameSpaces: Data(), deviceAuth: deviceAuth
    )

    let document = Document(
        docType: selectiveMDoc.docType,
        issuerSigned: selectiveMDoc.issuerSigned,
        deviceSigned: deviceSigned,
        errors: nil
    )

    let response = DeviceResponse(
        version: "1.0",
        documents: [document],
        documentErrors: nil,
        status: 0
    )

    transportService.sendResponse(response)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.state = .success
        self?.transportService.stopPeripheralMode()
    }
}

func denyDisclosure() {
    let response = DeviceResponse(
        version: "1.0",
        documents: nil,
        documentErrors: nil,
        status: 10  // General error - user denied
    )
    transportService.sendResponse(response)
    transportService.stopPeripheralMode()
    state = .idle
    pendingRequest = nil
}
```

---

### Prerequisites

- Two iPhones running iOS 17+
- Both with Bluetooth enabled
- Face ID/Touch ID enrolled on the Holder device
- The app installed on both devices

### Test Scenario: Age Verification

We'll test the most common scenario: verifying someone is over 21.

### Step 1: Setup

**Device A (Reader/Verifier)**
1. Launch the app
2. Tap "Reader"
3. Select "Age 21+ Verification"

**Device B (Holder/Presentment)**
1. Launch the app
2. Tap "Presentment"
3. You should see the sample credential card
4. (Optional) Tap "Randomize" to switch to a different identity — this helps confirm that different data is actually being sent each time

### Step 2: Initiate Connection

> Note: In the intended ISO 18013-5 flow, an NFC tap (Device Engagement) would occur here.
> Since NFC tag emulation (HCE) is exclusive to Apple Wallet on iOS,
> direct BLE connection is used. See <doc:NFCHandshake> for details.

**On Device A (Reader)**
1. Tap "Start Reading"
2. The app shows "Ready to Read" with animated rings (BLE scanning)
3. Wait for BLE connection

**On Device B (Holder)**
1. Tap "Present ID"
2. The app shows "Ready to Present" and starts BLE advertising
3. Wait for the Reader to connect via BLE

### Step 3: Handle Request

**On Device B (Holder)**
1. Once connected, you'll see the disclosure request:
   - "Age Over 21"
   - "Portrait" (if requested)
2. Review what's being requested
3. Tap "Approve with Face ID"
4. Complete Face ID authentication
5. See "Shared Successfully"

### Step 4: View Results

**On Device A (Reader)**
1. After the Holder approves, results appear
2. You should see:
   - "Age Over 21: Yes" with green checkmark
3. Tap "Done" to reset

### Expected Flow

```
Time    Reader Device                Holder Device
────────────────────────────────────────────────────
0:00    Select scenario              Show credential
0:05    Tap "Start Reading"
0:06    "Ready to Read"
0:10                                 Tap "Present ID"
0:11                                 "Ready to Present"
0:15    "Connecting..."
0:17    "Waiting for approval..."    Show request UI
0:20                                 Tap "Approve"
0:21                                 Face ID prompt
0:23                                 "Sending..."
0:25    Show results                 "Shared Successfully"
```

### Debugging Tips

#### Connection Issues

If devices don't connect:
1. Ensure Bluetooth is enabled on both
2. Try toggling Bluetooth off/on
3. Force quit and restart the app
4. Check for Bluetooth permission prompts

#### Data Not Received

If Reader doesn't show results:
1. Check console logs for CBOR encoding errors
2. Verify BLE characteristics are discovered
3. Ensure data chunking is working for large payloads

#### Authentication Fails

If Face ID doesn't work:
1. Verify Face ID is enrolled in Settings
2. Check for proper error handling
3. Test the passcode fallback

### Adding Console Logging

For debugging, add print statements:

```swift
// In BLEService
func centralManager(_ central: CBCentralManager,
                   didConnect peripheral: CBPeripheral) {
    print("BLE: Connected to \(peripheral.name ?? "unknown")")
    // ...
}

// In CBORService
func encode(mdoc: MDoc) -> Data {
    let data = // ... encoding
    print("CBOR: Encoded mdoc: \(data.count) bytes")
    return data
}
```

### Test Matrix

| Scenario | Expected Result |
|----------|----------------|
| Age 21+ | age_over_21: true, portrait image |
| Age 18+ | age_over_18: true, portrait image |
| Full Identity | name, DOB, doc#, portrait image |
| Randomize + Full Identity | Different name/DOB on Reader |
| User Denies | No data sent, Reader shows error |
| Cancel Face ID | Returns to request screen |
| BLE Disconnect | Both apps reset to idle |

### Performance Metrics

Typical timing for the complete flow:
- BLE connection: 2-5 seconds
- Request/Response: 1-2 seconds
- Total: 5-10 seconds

### Common Issues

1. **"Bluetooth Unavailable"**
   - Check iOS Settings → Bluetooth
   - Ensure Bluetooth permission is granted

2. **"Connection Timed Out"**
   - Move devices closer together
   - Restart Bluetooth on both devices

3. **"Invalid Response"**
   - Check CBOR encoding/decoding
   - Verify data structures match

4. **Face ID Not Appearing**
   - Check `NSFaceIDUsageDescription` in Info.plist
   - Ensure device has Face ID enrolled

### Next Steps

Congratulations! You've built a working pseudo ID verification system.

To extend this workshop:
- Implement proper COSE signing with certificate chain verification
- Add issuer certificate verification (X.509)
- Create a real credential issuance flow
- Explore Apple's `ProximityReader` framework (requires entitlement)
- Investigate NFC & SE Platform (iOS 18.2+) for HCE support (requires entitlement request)
- Explore **Remote Retrieval** — verify credentials via a Wallet API instead of device-to-device BLE

> Note: iOS 18.2 introduced HCE support via the NFC & SE Platform, but it requires
> an entitlement request to Apple and it is unclear whether general developers can obtain approval.
> Using the Apple ID Verifier API (`ProximityReader`)
> requires an individual agreement with Apple and a dedicated entitlement.

#### Beyond This Workshop: Remote Retrieval

ISO 18013-5 also defines a *server retrieval* flow where the Verifier obtains mdoc data from a remote server rather than directly from the Holder's device. The high-level flow looks like:

```
Holder          Wallet Server          Verifier
  │                   │                   │
  │ 1. Consent + Token│                   │
  │──────────────────►│                   │
  │                   │                   │
  │                   │ 2. Token + Request │
  │                   │◄──────────────────│
  │                   │                   │
  │                   │ 3. CBOR Response   │
  │                   │──────────────────►│
  │                   │   (HPKE encrypted) │
  │                   │                   │
  │                   │ 4. Decrypt + Parse │
  │                   │                   │
```

Key concepts:
- **HPKE (Hybrid Public Key Encryption)**: Protects the response in transit between Wallet Server and Verifier
- The Verifier runs a local HTTPS server to receive the encrypted CBOR response
- Decoding uses the same `CBORService` you built in this workshop

This approach enables cross-device verification (e.g., web-based Verifiers) and is the foundation of the Verify with Wallet API pattern.

## Summary

You've learned:
1. ISO 18013-5 mdoc structure
2. CBOR encoding/decoding
3. Multipeer Connectivity as a quick-start transport
4. BLE communication patterns and why ISO 18013-5 chose BLE over MPC
5. NFC-to-BLE handover mechanics and iOS technical constraints
6. Selective disclosure
7. Biometric authentication

These concepts apply directly to real mobile identity implementations.
