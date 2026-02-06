# Build Your Own (Pseudo) ID Verifier

Build an iOS app that simulates ISO 18013-5 compliant ID verification using BLE and selective disclosure.

## Overview

In this hands-on workshop, you'll build an app that can act as both a **Holder** (presenting credentials) and a **Verifier** (reading credentials). The app demonstrates key concepts from mobile driving license (mDL) standards:

- **Device Engagement**: Establishing a secure session between devices
- **BLE Transport**: Transferring data over Bluetooth Low Energy
- **Selective Disclosure**: Sharing only the requested attributes
- **CBOR Encoding**: Using the binary format specified by ISO 18013-5

### The Ideal Flow (ISO 18013-5 / Apple ID Verifier API)

```
┌─────────────────┐                    ┌──────────────────┐
│  Reader Phone   │                    │ Presentment Phone│
│   (Verifier)    │                    │    (Holder)      │
└────────┬────────┘                    └────────┬─────────┘
         │                                      │
         │ 1. NFC Session (Tap to Verify)       │
         │◄────────── NFC TAP ─────────────────►│
         │    DeviceEngagement (CBOR+BLE UUID)   │
         │                                      │
         │ 2. BLE Connection (using NFC UUID)    │
         │◄────────────────────────────────────►│
         │                                      │
         │ 3. Send DeviceRequest (CBOR)         │
         │─────────────────────────────────────►│
         │                                      │
         │                        4. Show Request│
         │                        5. Face ID Auth│
         │                                      │
         │ 6. Receive DeviceResponse (CBOR)     │
         │◄─────────────────────────────────────│
         │                                      │
         │ 7. Decode CBOR → Display Key-Values   │
         ▼                                      ▼
```

> Important: Step 1 (NFC tap) cannot be implemented in third-party apps on iOS.
> NFC tag emulation (HCE) is exclusive to Apple Wallet.
> This workshop uses direct BLE connection, while NFC concepts are covered as learning material.
> See <doc:NFCHandshake> for details.

### Actual Flow in This Workshop

```
┌─────────────────┐                    ┌──────────────────┐
│  Reader Phone   │                    │ Presentment Phone│
│   (Verifier)    │                    │    (Holder)      │
└────────┬────────┘                    └────────┬─────────┘
         │                                      │
         │ 1. BLE Scanning                      │
         │────────────────── BLE ──────────────►│ BLE Advertising
         │                                      │
         │ 2. BLE Connection                    │
         │◄────────────────────────────────────►│
         │                                      │
         │ 3. Send DeviceRequest (CBOR)         │
         │─────────────────────────────────────►│
         │                        4. Show Request│
         │                        5. Face ID Auth│
         │ 6. Receive DeviceResponse (CBOR)     │
         │◄─────────────────────────────────────│
         │ 7. Decode CBOR → Display Key-Values   │
         ▼                                      ▼
```

## Workshop Timeline (2.5 hours)

| Time | Section | What You'll Do |
|------|---------|---------------|
| 0:00–0:15 | Getting Started + Setup | ISO 18013-5 concepts, open the initial project |
| 0:15–0:45 | Understanding MDoc + CBOR Step 1–2 | Review models, implement encode(mdoc) and decodeMDoc |
| 0:45–1:15 | CBOR Step 3–4 | encode(request), decodeRequest, encode(response), decodeResponse |
| 1:15–1:30 | **Break** | |
| 1:30–2:00 | BLE Transport | Implement BLEService (central, peripheral, chunking) |
| 2:00–2:15 | Selective Disclosure + Biometric Auth | createSelectiveResponse + authenticateForDisclosure |
| 2:15–2:30 | Integration Testing | Wire up ViewModels + test on two devices |

> **Tip**: The initial project has `📋 PASTE` markers showing exactly where to paste code from each chapter.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:ProjectSetup>

### Building the Data Layer

- <doc:UnderstandingMDoc>
- <doc:CBOREncodingDecoding>

### Connection: NFC-to-BLE Handover (Ideal vs Reality)

- <doc:BLETransport>

### Security & Privacy

- <doc:SelectiveDisclosure>
- <doc:BiometricAuthentication>

### Putting It Together

- <doc:IntegrationTesting>


### Bonus (Optional)

- <doc:NFCHandshake>
- <doc:SimulatorTesting>
