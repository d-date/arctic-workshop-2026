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
[4] │                  │                        │  Face ID Auth     │
    │                  │                        │  Touch ID Auth    │
    │                  │                        │                  │
[5] │  Receive         │◄══ DeviceResponse ════│  Send Response   │
    │  (CBOR + mdoc)   │                        │  (filtered mdoc) │
    │                  │                        │                  │
[6] │  CBOR Decode     │                        │                  │
    │  Display Key-Values   │                        │                  │
    └──────────────────┘                        └──────────────────┘
```

### iOS Technical Constraints: Why NFC Tap Cannot Be Reproduced

**Step [1] NFC TAP** in the flow above cannot be implemented in third-party apps:

| Feature | Status on iOS | This Workshop |
|---------|---------------|---------------|
| NFC Tag **Reading** (Reader) | Possible with `NFCNDEFReaderSession` | Reference implementation provided |
| NFC Tag **Emulation** (Holder) | HCE available since iOS 18.2 via NFC & SE Platform, but requires entitlement request to Apple; unclear if general developers can obtain approval | **Substituted with direct BLE connection** |
| `CardSession` (iOS 17.4+) | EEA only / payment use only | Out of scope |
| Apple ID Verifier API | `ProximityReader` framework / dedicated entitlement required | Concepts explained |

**Why Apple's ID Verifier API works:**
1. Reader side: `ProximityReader` performs NFC polling via Enhanced Contactless Polling (ECP)
2. Holder side: Apple Wallet returns `DeviceEngagement` as an NDEF tag at the system level
3. Both are Apple's proprietary implementation -- cannot be reproduced by third parties

### Actual Flow in This Workshop

Instead of NFC tag emulation, we use direct BLE connection:

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
[4] │                  │                        │  Face ID Auth     │
    │                  │                        │                  │
[5] │  Receive         │◄══ DeviceResponse ════│  Send Response   │
    │  (CBOR + mdoc)   │                        │  (filtered mdoc) │
    │                  │                        │                  │
[6] │  CBOR Decode     │                        │                  │
    │  Display Key-Values   │                        │                  │
    └──────────────────┘                        └──────────────────┘
```

> All steps other than NFC tag emulation (BLE connection, CBOR encoding/decoding,
> selective attribute disclosure, biometric authentication) are implemented in compliance with ISO 18013-5.

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
3. **NFC Handshake** - Understand device engagement (includes learning iOS constraints)
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
| `NFCService` | NFC handover (Reader-side reference implementation / iOS HCE constraint) |
| `AuthenticationService` | Biometric approval (Face ID / Touch ID) |
| `CryptoService` | ECDSA signing, ECDH key agreement |

### Communication Flow

1. Reader starts BLE scanning (Tap to Pay style UI)
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

- **NFC Tag Emulation (HCE)** — Available since iOS 18.2 but requires entitlement request; general developer availability uncertain
- **`ProximityReader` without entitlement** — requires Apple contract
- **Cross-app NFC tag emulation** — no public API exists

### Related Apple Technologies (Explained in Documentation)

- **Apple ID Verifier API** (`ProximityReader` framework)
- **Enhanced Contactless Polling** (ECP)
- **NFC & SE Platform** (iOS 18.2+ for HCE, requires entitlement request)
- **`CardSession`** (iOS 17.4+, EEA only)

## Files to Complete

In the `initial/` project, look for `fatalError("TODO:")` comments:

- `Services/CBORService.swift` - CBOR encoding/decoding
- `Services/BLEService.swift` - BLE communication
- `Services/NFCService.swift` - NFC handover (Reader-side reference implementation)
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
