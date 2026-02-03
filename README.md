# ARCTIC Conference 2026 Workshop: Pseudo ID Verifier

A hands-on iOS workshop for building a simulated ISO 18013-5 compliant mobile ID verification system.

## Overview

In this workshop, participants will build **PseudoIDVerifier**, an iOS app that demonstrates the core concepts of mobile identity verification using two iPhones:

- **Reader Phone**: Initiates verification sessions and receives identity data
- **Holder Phone**: Presents credentials with selective disclosure

```
┌─────────────────┐                    ┌─────────────────┐
│  Reader Phone   │                    │  Holder Phone   │
│  (Verifier)     │                    │  (Presenter)    │
├─────────────────┤                    ├─────────────────┤
│                 │  1. BLE Connect    │                 │
│  Start Session  │───────────────────►│  Waiting...     │
│                 │                    │                 │
│                 │  2. DeviceRequest  │                 │
│  Request attrs  │───────────────────►│  Show Request   │
│                 │    (CBOR)          │                 │
│                 │                    │  ┌───────────┐  │
│                 │                    │  │ Face ID   │  │
│                 │                    │  │ Approve?  │  │
│                 │                    │  └───────────┘  │
│                 │  3. DeviceResponse │                 │
│  Show Result    │◄───────────────────│  Send Response  │
│                 │    (CBOR + mdoc)   │                 │
└─────────────────┘                    └─────────────────┘
```

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
3. **NFC Handshake** - Understand device engagement
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

### Architecture

| Component | Description |
|-----------|-------------|
| `MDoc` | Mobile document data structure |
| `CBORService` | CBOR encoding/decoding |
| `BLEService` | Bluetooth communication |
| `NFCService` | NFC handshake (educational) |
| `AuthenticationService` | Biometric approval |

### Communication Flow

1. Reader starts BLE scanning
2. Holder advertises BLE service
3. Devices connect over BLE
4. Reader sends `DeviceRequest` (CBOR)
5. Holder shows request to user
6. User approves with Face ID
7. Holder sends `DeviceResponse` with filtered mdoc
8. Reader displays verified attributes

## Workshop Simplifications

For educational purposes, this workshop:

- Skips NFC tag emulation (requires special entitlements)
- Uses dummy credentials instead of real issuance
- Simplifies cryptographic verification
- Focuses on the data flow rather than full security

## Files to Complete

In the `initial/` project, look for `fatalError("TODO:")` comments:

- `Services/CBORService.swift` - CBOR encoding/decoding
- `Services/BLEService.swift` - BLE communication
- `Services/AuthenticationService.swift` - Biometric auth

## Resources

- [ISO 18013-5 Standard](https://www.iso.org/standard/69084.html)
- [Apple CoreBluetooth](https://developer.apple.com/documentation/corebluetooth)
- [Apple LocalAuthentication](https://developer.apple.com/documentation/localauthentication)
- [SwiftCBOR Library](https://github.com/valpackett/SwiftCBOR)

## License

MIT License - See LICENSE file for details.

---

**ARCTIC Conference 2026** - Building the Future of Digital Identity
