# Build Your Own (Pseudo) ID Verifier

Build an iOS app that simulates ISO 18013-5 compliant ID verification using BLE and selective disclosure.

## Overview

In this hands-on workshop, you'll build an app that can act as both a **Holder** (presenting credentials) and a **Verifier** (reading credentials). The app demonstrates key concepts from mobile driving license (mDL) standards:

- **Device Engagement**: Establishing a secure session between devices
- **Transport Layer**: Transferring data over Bluetooth Low Energy (BLE)
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
> This workshop uses direct device-to-device connection, while NFC concepts are covered as learning material.
> See <doc:NFCHandshake> for details.

### Actual Flow in This Workshop

This workshop uses **CoreBluetooth (BLE)** for device-to-device communication, which closely mirrors the ISO 18013-5 transport layer. The Reader operates as a BLE **Central** and the Holder as a BLE **Peripheral**.

```
┌─────────────────┐                    ┌──────────────────┐
│  Reader Phone   │                    │ Presentment Phone│
│   (Verifier)    │                    │    (Holder)      │
└────────┬────────┘                    └────────┬─────────┘
         │                                      │
         │ 1. BLE Scan (Central)                │
         │──────────────────────────────────────►│ BLE Advertise (Peripheral)
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
         │ 7. Verify MSO + Display Results      │
         ▼                                      ▼
```

### Pair Work

This workshop is designed for **pair work**. Two participants share one project, each with their own iPhone:

| Role | Device | Responsibility |
|------|--------|---------------|
| **Reader** (Verifier) | Device A | Browse/scan, send requests, verify MSO, display results |
| **Holder** (Presentment) | Device B | Advertise, receive requests, authenticate, send responses |

In the first half, both participants implement the same shared foundation (models, CBOR).
After the break, each person focuses on their role-specific code, then pairs up for integration testing.

## Workshop Timeline (3 hours)

| Time | Section | Reader | Holder |
|------|---------|--------|--------|
| 0:00–0:15 | Getting Started + Setup | (together) | (together) |
| 0:15–0:45 | MDoc + CBOR Step 1–2 | (together) | (together) |
| 0:45–1:15 | CBOR Step 3–4 | (together) | (together) |
| 1:15–1:30 | **Break** | | |
| 1:30–2:00 | BLE Transport | Central (Step 2, 4) | Peripheral (Step 3, 4, 5) |
| 2:00–2:10 | BLE Pair Test | (pair test) | (pair test) |
| 2:10–2:40 | Security & Privacy | MSO Verification (Step 2) | Selective Disclosure + Biometric Auth |
|  | | | MSO Verification (Step 1) |
| 2:40–3:00 | Integration Testing | ReaderViewModel | PresentmentViewModel |
|  | | (pair test) | (pair test) |

> **Tip**: The initial project has `📋 PASTE` markers showing exactly where to paste code from each chapter.
> Each marker indicates which role should implement that section.

## Topics

### Essentials (Together)

- <doc:GettingStarted>
- <doc:ProjectSetup>

### Building the Data Layer (Together)

- <doc:UnderstandingMDoc>
- <doc:CBOREncodingDecoding>

### Transport (Pair Work)

- <doc:BLETransport>

### Holder Path (Pair Work)

- <doc:SelectiveDisclosure>
- <doc:BiometricAuthentication>

### Reader Path (Pair Work)

- <doc:MSOVerification>

### Putting It Together (Pair Test)

- <doc:IntegrationTesting>

### Bonus (Optional)

- <doc:MPCTransport>
- <doc:NFCHandshake>
- <doc:SimulatorTesting>
