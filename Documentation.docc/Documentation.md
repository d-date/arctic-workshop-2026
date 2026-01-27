# Build Your Own (Pseudo) ID Verifier

Build an iOS app that simulates ISO 18013-5 compliant ID verification using BLE and selective disclosure.

## Overview

In this hands-on workshop, you'll build an app that can act as both a **Holder** (presenting credentials) and a **Verifier** (reading credentials). The app demonstrates key concepts from mobile driving license (mDL) standards:

- **Device Engagement**: Establishing a secure session between devices
- **BLE Transport**: Transferring data over Bluetooth Low Energy
- **Selective Disclosure**: Sharing only the requested attributes
- **CBOR Encoding**: Using the binary format specified by ISO 18013-5

```
┌─────────────────┐                    ┌─────────────────┐
│  Reader Phone   │                    │ Presentment Phone│
│   (Verifier)    │                    │    (Holder)      │
└────────┬────────┘                    └────────┬─────────┘
         │                                      │
         │ 1. Start Reading                     │
         │──────────────────────────────────────│
         │                                      │
         │ 2. BLE Connection                    │
         │◄────────────────────────────────────►│
         │                                      │
         │ 3. Send DeviceRequest                │
         │─────────────────────────────────────►│
         │                                      │
         │                        4. Show Request│
         │                        5. Face ID Auth│
         │                                      │
         │ 6. Receive DeviceResponse (CBOR)     │
         │◄─────────────────────────────────────│
         │                                      │
         │ 7. Display Verified Attributes       │
         ▼                                      ▼
```

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:ProjectSetup>

### Building the Data Layer

- <doc:UnderstandingMDoc>
- <doc:CBOREncodingDecoding>

### Communication

- <doc:NFCHandshake>
- <doc:BLETransport>

### Security & Privacy

- <doc:SelectiveDisclosure>
- <doc:BiometricAuthentication>

### Putting It Together

- <doc:IntegrationTesting>
