# ARCTIC Conference 2026 Workshop: Pseudo ID Verifier

A hands-on iOS workshop for building a simulated ISO 18013-5 compliant mobile ID verification system.

## Overview

In this workshop, participants will build **PseudoIDVerifier**, an iOS app that demonstrates the core concepts of mobile identity verification using two iPhones:

- **Reader Phone** (Verifier): Initiates verification sessions and receives identity data
- **Presentment Phone** (Holder): Presents credentials with selective disclosure and biometric approval

### The Ideal Flow: NFC Tap → BLE Data Transfer

ISO 18013-5 and Apple's ID Verifier API define the following flow:

```
         Reader Phone                              Presentment Phone
          (Verifier)                                   (Holder)
    ┌──────────────────┐                        ┌──────────────────┐
    │                  │                        │                  │
[1] │  "Tap to Verify" │       NFC TAP          │  NFC Tag Ready   │
    │  NFC Session     │◄══════════════════════►│  (HCE)           │
    │                  │    DeviceEngagement     │                  │
    │                  │    (CBOR + BLE UUID)    │                  │
    ├──────────────────┤                        ├──────────────────┤
    │                  │                        │                  │
[2] │  BLE Connect     │◄═══ BLE Connection ═══►│  BLE Peripheral  │
    │  (Central)       │    using UUID from NFC  │                  │
    │                  │                        │                  │
[3] │  Send Request    │═══ DeviceRequest ═════►│  Show Request    │
    │  (CBOR)          │                        │  (Disclosure UI) │
    │                  │                        │                  │
[4] │                  │                        │  Face ID 認証     │
    │                  │                        │  Touch ID 認証    │
    │                  │                        │                  │
[5] │  Receive         │◄══ DeviceResponse ════│  Send Response   │
    │  (CBOR + mdoc)   │                        │  (filtered mdoc) │
    │                  │                        │                  │
[6] │  CBOR Decode     │                        │                  │
    │  Key-Value 表示   │                        │                  │
    └──────────────────┘                        └──────────────────┘
```

### iOS の技術的制約: なぜ NFC タップを再現できないのか

上記フローの **Step [1] NFC TAP** は、サードパーティアプリでは実現できません:

| 機能 | iOS での状況 | 本ワークショップ |
|------|-------------|----------------|
| NFC タグ **読み取り** (Reader) | `NFCNDEFReaderSession` で可能 | リファレンス実装を提供 |
| NFC タグ **エミュレーション** (Holder) | **Apple Wallet 専用** — HCE 不可 | **BLE 直接接続で代替** |
| `CardSession` (iOS 17.4+) | EEA 限定 / 決済用途のみ | 対象外 |
| Apple ID Verifier API | `ProximityReader` framework / 専用 entitlement 必要 | 概念を解説 |

**Apple の ID Verifier API が動作する理由:**
1. Reader 側: `ProximityReader` が Enhanced Contactless Polling (ECP) で NFC ポーリング
2. Holder 側: Apple Wallet がシステムレベルで NDEF タグとして `DeviceEngagement` を返す
3. 両者とも Apple のプロプライエタリ実装 — サードパーティでは再現不可

### 本ワークショップの実際のフロー

NFC タグエミュレーションの代わりに、BLE 直接接続を使用します:

```
         Reader Phone                              Presentment Phone
          (Verifier)                                   (Holder)
    ┌──────────────────┐                        ┌──────────────────┐
    │                  │                        │                  │
[1] │  "Tap to Verify" │                        │ "Present ID"     │
    │  BLE Scanning    │                        │  BLE Advertising │
    │                  │                        │                  │
[2] │  BLE Connect     │◄═══ BLE Connection ═══►│  BLE Peripheral  │
    │  (Central)       │                        │                  │
    │                  │                        │                  │
[3] │  Send Request    │═══ DeviceRequest ═════►│  Show Request    │
    │  (CBOR)          │                        │  (Disclosure UI) │
    │                  │                        │                  │
[4] │                  │                        │  Face ID 認証     │
    │                  │                        │                  │
[5] │  Receive         │◄══ DeviceResponse ════│  Send Response   │
    │  (CBOR + mdoc)   │                        │  (filtered mdoc) │
    │                  │                        │                  │
[6] │  CBOR Decode     │                        │                  │
    │  Key-Value 表示   │                        │                  │
    └──────────────────┘                        └──────────────────┘
```

> NFC タグエミュレーション以外の全ステップ (BLE 接続、CBOR エンコード/デコード、
> 選択的属性開示、生体認証) は ISO 18013-5 に準拠した実装です。

## Project Structure

```
arctic-workshop-2026/
├── initial/                    # Starter project with TODOs
│   └── PseudoIDVerifier/
│       └── PseudoIDVerifier/
│           ├── Models/         # Data structures
│           ├── Services/       # Core functionality (TODOs here)
│           └── Views/          # SwiftUI views
├── completed/                  # Reference implementation
│   └── PseudoIDVerifier/
│       └── PseudoIDVerifier/
│           ├── Models/
│           ├── Services/       # Fully implemented
│           └── Views/
└── Documentation.docc/         # Step-by-step tutorials
```

## Getting Started

### Prerequisites

- Xcode 15.0 or later
- Two iPhones running iOS 17.0+
- Apple Developer account (for device testing)

### Setup

1. Clone this repository
2. Open `initial/PseudoIDVerifier/PseudoIDVerifier.xcodeproj` in Xcode
3. Update the bundle identifier and signing team
4. Build and run on two devices

### Workshop Flow

1. **Understanding mDL** - Learn ISO 18013-5 data structures
2. **CBOR Encoding** - Implement binary serialization
3. **NFC Handshake** - Understand device engagement (iOS 制約の学習を含む)
4. **BLE Transport** - Build the communication layer
5. **Selective Disclosure** - Implement privacy-preserving data sharing
6. **Biometric Authentication** - Add Face ID/Touch ID approval
7. **Integration Testing** - Test the complete flow

## Documentation

Open the DocC documentation in Xcode:

```bash
cd Documentation.docc
open ../initial/PseudoIDVerifier/PseudoIDVerifier.xcodeproj
# Product > Build Documentation
```

Or read the markdown files directly in `Documentation.docc/`.

## Key Concepts

### ISO 18013-5

This workshop simulates the ISO 18013-5 standard for mobile driving licenses (mDL):

- **mdoc**: Mobile document containing identity attributes
- **IssuerSigned**: Attributes signed by the credential issuer
- **DeviceSigned**: Proof that the device holds the credential
- **Selective Disclosure**: Share only requested attributes
- **DeviceEngagement**: Connection establishment data (CBOR-encoded)

### Architecture

| Component | Description |
|-----------|-------------|
| `MDoc` | Mobile document data structure |
| `CBORService` | CBOR encoding/decoding |
| `BLEService` | Bluetooth communication (Central & Peripheral) |
| `NFCService` | NFC handover (Reader 側リファレンス実装 / iOS HCE 制約あり) |
| `AuthenticationService` | Biometric approval (Face ID / Touch ID) |
| `CryptoService` | ECDSA signing, ECDH key agreement |

### Communication Flow

1. Reader starts BLE scanning (Tap to Pay 風 UI)
2. Holder starts BLE advertising
3. Devices connect over BLE
4. Reader sends `DeviceRequest` (CBOR)
5. Holder shows selective disclosure request to user
6. User approves with Face ID / Touch ID
7. Holder sends `DeviceResponse` with filtered mdoc (CBOR)
8. Reader decodes CBOR and displays verified key-value attributes

## iOS Technical Constraints

This workshop teaches **what is and isn't possible** on iOS for NFC-BLE identity verification:

### What This Workshop Implements (Fully Functional)

- BLE Central/Peripheral communication
- CBOR encoding/decoding per ISO 18013-5
- mdoc data structures (IssuerSigned, DeviceSigned)
- Selective disclosure filtering
- Face ID / Touch ID biometric approval
- DeviceRequest / DeviceResponse protocol

### What iOS Cannot Do (Explained in Documentation)

- **NFC Tag Emulation (HCE)** — Apple Wallet exclusive
- **`ProximityReader` without entitlement** — requires Apple contract
- **Cross-app NFC tag emulation** — no public API exists

### Related Apple Technologies (Explained in Documentation)

- **Apple ID Verifier API** (`ProximityReader` framework)
- **Enhanced Contactless Polling** (ECP)
- **NFC & SE Platform** (iOS 18.1+)
- **`CardSession`** (iOS 17.4+, EEA only)

## Files to Complete

In the `initial/` project, look for `fatalError("TODO:")` comments:

- `Services/CBORService.swift` - CBOR encoding/decoding
- `Services/BLEService.swift` - BLE communication
- `Services/NFCService.swift` - NFC handover (Reader 側リファレンス実装)
- `Services/AuthenticationService.swift` - Biometric auth

## Resources

- [ISO 18013-5 Standard](https://www.iso.org/standard/69084.html)
- [Apple CoreBluetooth](https://developer.apple.com/documentation/corebluetooth)
- [Apple CoreNFC](https://developer.apple.com/documentation/corenfc)
- [Apple ProximityReader (ID Verifier)](https://developer.apple.com/documentation/proximityreader)
- [Apple LocalAuthentication](https://developer.apple.com/documentation/localauthentication)
- [SwiftCBOR Library](https://github.com/valpackett/SwiftCBOR)

## License

MIT License - See LICENSE file for details.

---

**ARCTIC Conference 2026** - Building the Future of Digital Identity
