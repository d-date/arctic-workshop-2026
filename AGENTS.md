# AGENTS.md - AI Assistant Guidelines for PseudoIDVerifier Workshop

## Language Policy

- **All source code comments, documentation (Documentation.docc), and README must be written in English.**
- AGENTS.md itself must also be in English.
- Commit messages should be in English.

## Project Overview

Hands-on workshop material for ARCTIC Conference 2026.
Build a pseudo ID verification system based on ISO 18013-5 (mDL) using two iPhones.

### Key Flow: NFC Tap → BLE → Selective Disclosure → Biometric → CBOR Response → Decode

```
[1] Reader Phone: "Tap to Verify" UI → Start BLE scanning
[2] Presentment Phone: Start BLE advertising → Establish BLE connection with Reader
[3] Reader → Presentment: Send DeviceRequest (CBOR)
[4] Presentment: Show selective disclosure UI → Authenticate with Face ID / Touch ID
[5] Presentment → Reader: Send DeviceResponse (CBOR + filtered mdoc)
[6] Reader: Decode CBOR → Display Key-Value pairs
```

### iOS Technical Constraints (Important)

- **NFC tag emulation (HCE) is not available for third-party apps**
  - Only Apple Wallet can make an iPhone act as an NDEF tag
  - This workshop uses direct BLE connection as a substitute
  - Apple's ID Verifier API (ProximityReader) implements NFC-to-BLE handover internally, but it is a proprietary API requiring a Reader-side entitlement
- **CoreNFC Reader mode is available** (`NFCNDEFReaderSession`)
  - Reading external NFC tags is possible
  - However, it cannot recognize another iPhone as an NFC tag
- HCE-based contactless (`CardSession`, iOS 17.4+) is available in the EEA only and does not cover NDEF emulation for ID purposes

## Architecture

- **Two-project structure**: `initial/` (skeleton with TODOs) and `completed/` (reference implementation)
- **Documentation.docc/**: DocC tutorials (9 chapters)
- **Frameworks**: SwiftUI, CoreBluetooth, CoreNFC, LocalAuthentication, CryptoKit, SwiftCBOR
- **Target**: iOS 17+, two physical devices required (Simulator does not support BLE/NFC)

## Code Conventions

- Swift style: `// MARK: -` section dividers, explicit access control
- Services: singleton pattern (`.shared`)
- ViewModels: `@MainActor` `ObservableObject` classes
- State machines: enums (`ReaderState`, `PresentmentState`, `BLEConnectionState`)
- Error types: conform to `LocalizedError`
- CBOR: SwiftCBOR library (`CBOR.map`, `CBOR.array` patterns)
- ISO 18013-5 naming conventions: mdoc, IssuerSigned, DeviceSigned, DeviceEngagement

## Workshop Conventions

- `initial/` files use `fatalError("Not implemented - Complete this in Chapter N")` for TODOs
- `completed/` is the full reference implementation
- Documentation.docc chapters are ordered to follow the flow sequence
- Dummy credentials are used (no real issuance flow)
- Cryptographic verification is simplified for educational purposes

## File Organization

```
Models/      MDoc.swift, DeviceRequest.swift, DummyCredentials.swift
Services/    NFCService.swift, BLEService.swift, CBORService.swift,
             AuthenticationService.swift, CryptoService.swift
Views/       ContentView.swift, ReaderView.swift, PresentmentView.swift,
             DisclosureRequestView.swift
```

## When Modifying Code

- Always keep `initial/` and `completed/` structurally in sync
- Update Documentation.docc when changing code flow
- Reference chapter numbers in `initial/` TODO patterns
- Test on two physical devices (Simulator does not support BLE/NFC)
- When modifying NFC-related code, ensure it does not contradict the technical constraints section
