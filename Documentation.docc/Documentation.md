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
         │ 7. Decode CBOR → Key-Value 表示      │
         ▼                                      ▼
```

> Important: Step 1 (NFC タップ) は iOS ではサードパーティアプリで実現できません。
> NFC タグエミュレーション (HCE) は Apple Wallet 専用です。
> 本ワークショップでは BLE 直接接続を使用し、NFC の概念は学習教材として解説します。
> 詳細は <doc:NFCHandshake> を参照してください。

### 本ワークショップの実際のフロー

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
         │ 7. Decode CBOR → Key-Value 表示      │
         ▼                                      ▼
```

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:ProjectSetup>

### Building the Data Layer

- <doc:UnderstandingMDoc>
- <doc:CBOREncodingDecoding>

### Connection: NFC-to-BLE Handover (理想と現実)

- <doc:NFCHandshake>
- <doc:BLETransport>

### Security & Privacy

- <doc:SelectiveDisclosure>
- <doc:BiometricAuthentication>

### Putting It Together

- <doc:IntegrationTesting>
