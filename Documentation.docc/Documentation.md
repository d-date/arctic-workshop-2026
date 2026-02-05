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

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:ProjectSetup>

### Building the Data Layer

- <doc:UnderstandingMDoc>
- <doc:CBOREncodingDecoding>

### Connection: NFC-to-BLE Handover (Ideal vs Reality)

- <doc:NFCHandshake>
- <doc:BLETransport>

### Security & Privacy

- <doc:SelectiveDisclosure>
- <doc:BiometricAuthentication>

### Putting It Together

- <doc:IntegrationTesting>
