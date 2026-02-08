# NFC Handshake

Understand the ISO 18013-5 NFC-to-BLE handover mechanism and iOS technical constraints.

## Overview

> Warning: **This chapter is optional (Bonus).** The core workshop uses BLE-only and does not require NFC. Complete this only if you have extra time.

In ISO 18013-5, an NFC handshake establishes a secure connection between the Reader and the Holder. Apple's ID Verifier API (a Tap-to-Pay-like experience) is also based on this protocol.

In this chapter, you will learn:

1. **ISO 18013-5 NFC Handover Specification** — How it works
2. **iOS Technical Constraints** — Why third-party apps cannot implement this
3. **How the Apple ID Verifier API Works** — How Apple works around the constraints
4. **Reader-Side NFC Code Implementation** — What CAN be done with CoreNFC

### ISO 18013-5: NFC Device Engagement Flow

```
Reader                              Holder
   │                                   │
   │ 1. Start NFC Session              │
   │   (NFCNDEFReaderSession)          │
   │───────────────────────────────────│
   │                                   │
   │ 2. Read NDEF Message              │
   │◄──────────────────────────────────│
   │   Contains:                       │
   │   - Handover Select record ("Hs") │
   │   - BLE OOB data (Service UUID)   │
   │   - Device Engagement (CBOR)      │
   │                                   │  ← Holder responds as an NDEF tag
   │ 3. Parse Device Engagement        │     (NFC tag emulation / HCE)
   │   → Extract BLE UUID              │
   │                                   │
   │ 4. Connect via BLE using UUID     │
   │───────────────────────────────────►
```

### NDEF Message Structure

The NFC handover message consists of three NDEF records:

| # | Record | Format | Description |
|---|--------|--------|-------------|
| 1 | Handover Select | NFC Well-Known ("Hs") | Handover type and reference |
| 2 | BLE Carrier Config | MIME type | BLE OOB data (Service UUID, LE Role) |
| 3 | Device Engagement | NFC External | CBOR-encoded DeviceEngagement |

---

## iOS Technical Constraints

> Important: This section is a key learning point of this workshop.
> When building an ID verification app on iOS, it is essential to understand precisely what CAN and what CANNOT be done.

### What CAN be done with CoreNFC

| API | Capability | Available |
|-----|-----------|-----------|
| `NFCNDEFReaderSession` | Reading NDEF tags | iOS 11+ |
| `NFCTagReaderSession` | Reading ISO 7816/14443/15693 tags | iOS 13+ |
| `NFCNDEFPayload` | Creating NDEF messages (as a data structure) | iOS 11+ |
| Writing to NDEF tags | Writing data to external NFC tags | iOS 13+ |

### What CANNOT be done with CoreNFC

| Capability | Reason | Alternative |
|-----------|--------|-------------|
| **NFC Tag Emulation (HCE)** | Available since iOS 18.2 via NFC & SE Platform, but requires entitlement request to Apple; unclear if general developers can obtain approval | Direct BLE connection |
| **Making an iPhone respond as an NDEF tag** | No public API available | BLE advertising |
| **Detecting another iPhone with `NFCTagReaderSession`** | An iPhone is not an NFC tag | BLE |

### Why does Apple's ID Verifier API work?

Apple's `ProximityReader` framework (ID Verifier API) internally implements the following:

```
ProximityReader (Reader side)
├── Enhanced Contactless Polling (ECP)
│   → Performs dedicated NFC polling for ISO 18013
│   → Proprietary protocol to distinguish from GymKit and other NFC uses
│
├── NFCNDEFReaderSession (used internally)
│   → Retrieves the Holder's DeviceEngagement via NDEF
│
└── BLE Data Transfer (used internally)
    → Automatically connects using the BLE UUID obtained from NFC
    → Establishes an encrypted session

Apple Wallet (Holder side)
├── Secure Element
│   → Makes the iPhone behave as an NFC tag (HCE)
│   → Returns DeviceEngagement as an NDEF response
│
└── iOS System UI
    → Displays the disclosure request to the user
    → Authenticates with Face ID / Touch ID
```

**This entire system is Apple's proprietary implementation**:
- Reader side: Requires `ProximityReader` framework + dedicated entitlement (`com.apple.developer.proximity-reader.identity.read`)
- Holder side: Limited to Apple Wallet -- third-party apps cannot respond as NDEF tags
- ECP is a non-public protocol

### About `CardSession` (iOS 17.4+)

The `CardSession` API introduced in iOS 17.4 enables HCE-based contactless transactions, but:

- **Limited to the EEA (European Economic Area)**
- **Designed for payment use cases** (EMV contactless payments)
- Does not support ISO 18013-5 NDEF DeviceEngagement
- Not available outside the EEA, including Japan

### About NFC & SE Platform and HCE (iOS 18.2+)

iOS 18.2 introduced HCE (Host Card Emulation) support via the NFC & SE Platform, which could theoretically enable an iPhone to act as an NDEF tag. However:

- **Requires an entitlement request to Apple** — it is unclear whether general developers can obtain approval
- Available in limited regions only
- Requires an individual agreement and review with Apple
- Primarily intended for specific use cases such as transit and ID cards
- Even if approved, implementing ISO 18013-5 NFC Device Engagement via HCE would require significant additional work beyond what CoreNFC provides

---

## Step 1: Reader-Side NFC Code Implementation (Reference)

The following code is a reader-side implementation of what CAN be done with CoreNFC.
It can be used to read DeviceEngagement from an external NFC tag.

```swift
import Foundation
import Observation
import CoreNFC

@Observable
class NFCService: NSObject {
    static let shared = NFCService()

    var isScanning = false
    var error: NFCError?
    var receivedEngagement: DeviceEngagement?

    @ObservationIgnored private var readerSession: NFCNDEFReaderSession?

    // Callbacks
    @ObservationIgnored var onEngagementReceived: ((DeviceEngagement, Data) -> Void)?
    var onError: ((NFCError) -> Void)?

    // ISO 18013-5 defined constants
    private let bleMimeType = "application/vnd.bluetooth.le.oob"
    private let deviceEngagementType = "iso.org:18013:deviceengagement"

    private override init() {
        super.init()
    }
}
```

### Step 2: Starting an NFC Reader Session

```swift
extension NFCService {
    func startReaderSession() {
        guard NFCNDEFReaderSession.readingAvailable else {
            DispatchQueue.main.async {
                self.error = .notAvailable
                self.onError?(.notAvailable)
            }
            return
        }

        readerSession = NFCNDEFReaderSession(
            delegate: self,
            queue: nil,
            invalidateAfterFirstRead: true
        )

        readerSession?.alertMessage = "Hold your iPhone near the other device"
        readerSession?.begin()
    }

    func stopReaderSession() {
        readerSession?.invalidate()
        readerSession = nil
        DispatchQueue.main.async {
            self.isScanning = false
        }
    }
}
```

> Note: This code works when reading external NFC tags.
> It cannot detect another iPhone as an NFC tag.

### Step 3: Implementing Delegate Methods

```swift
extension NFCService: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession,
                      didDetectNDEFs messages: [NFCNDEFMessage]) {
        guard let message = messages.first else {
            session.invalidate(errorMessage: "No NDEF message found")
            return
        }

        guard let (engagement, bleData) = parseHandoverMessage(message) else {
            session.invalidate(errorMessage: "Invalid message format")
            return
        }

        session.alertMessage = "Device engagement received!"
        session.invalidate()

        DispatchQueue.main.async {
            self.receivedEngagement = engagement
            self.isScanning = false
            self.onEngagementReceived?(engagement, bleData)
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession,
                      didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isScanning = false

            if let nfcError = error as? NFCReaderError {
                switch nfcError.code {
                case .readerSessionInvalidationErrorUserCanceled:
                    break  // User cancelled - not an error
                default:
                    self.error = .sessionInvalidated(nfcError.localizedDescription)
                }
            }
        }
    }

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        DispatchQueue.main.async {
            self.isScanning = true
        }
    }
}
```

### Step 4: Parsing the Handover Message

```swift
extension NFCService {
    private func parseHandoverMessage(_ message: NFCNDEFMessage) -> (DeviceEngagement, Data)? {
        var bleUUIDData: Data?
        var engagementData: Data?

        for record in message.records {
            let typeString = String(data: record.type, encoding: .utf8) ?? ""

            switch record.typeNameFormat {
            case .media:
                if typeString == bleMimeType {
                    bleUUIDData = parseBLEOOBData(record.payload)
                }

            case .nfcExternal:
                if typeString == deviceEngagementType {
                    engagementData = record.payload
                }

            default:
                break
            }
        }

        guard let engData = engagementData,
              let engagement = CBORService.shared.decodeEngagement(from: engData) else {
            return nil
        }

        return (engagement, bleUUIDData ?? Data())
    }

    private func parseBLEOOBData(_ data: Data) -> Data? {
        // Parse BLE Out-of-Band data to extract Service UUID
        var index = 0
        while index < data.count {
            let length = Int(data[index])
            guard index + length < data.count else { break }

            let type = data[index + 1]
            if type == 0x07 && length == 17 {
                // 128-bit UUID
                let uuidStart = index + 2
                let uuidEnd = uuidStart + 16
                guard uuidEnd <= data.count else { break }
                return Data(data[uuidStart..<uuidEnd].reversed())
            }

            index += length + 1
        }
        return nil
    }
}
```

### Step 5: Creating a Handover Message (For learning purposes)

The following code is a reference implementation for learning the structure of NDEF handover messages.
In a real app, since an iPhone cannot act as an NFC tag, this message cannot be delivered via NFC.

```swift
extension NFCService {
    func createHandoverMessage(bleUUID: String,
                               engagement: DeviceEngagement) -> NFCNDEFMessage? {
        let engagementData = CBORService.shared.encode(engagement: engagement)
        let bleOOBData = createBLEOOBData(uuid: bleUUID)

        var records: [NFCNDEFPayload] = []

        // Handover Select record
        let hsPayload = Data([0x15, 0xD1, 0x02, 0x04, 0x61, 0x63, 0x00, 0x01, 0x30])
        if let hsRecord = NFCNDEFPayload(
            format: .nfcWellKnown,
            type: Data("Hs".utf8),
            identifier: Data(),
            payload: hsPayload
        ) {
            records.append(hsRecord)
        }

        // BLE Carrier Configuration record
        if let bleRecord = NFCNDEFPayload(
            format: .media,
            type: Data(bleMimeType.utf8),
            identifier: Data("0".utf8),
            payload: bleOOBData
        ) {
            records.append(bleRecord)
        }

        // Device Engagement record
        if let deRecord = NFCNDEFPayload(
            format: .nfcExternal,
            type: Data(deviceEngagementType.utf8),
            identifier: Data(),
            payload: engagementData
        ) {
            records.append(deRecord)
        }

        guard !records.isEmpty else { return nil }
        return NFCNDEFMessage(records: records)
    }

    private func createBLEOOBData(uuid: String) -> Data {
        var data = Data()

        // LE Role: Peripheral only
        data.append(contentsOf: [0x02, 0x1C, 0x00])

        // 128-bit Service UUID
        if let uuidObj = UUID(uuidString: uuid) {
            let uuidBytes = withUnsafeBytes(of: uuidObj.uuid) { Array($0) }
            data.append(0x11)  // Length
            data.append(0x07)  // Type: Complete 128-bit UUIDs
            data.append(contentsOf: uuidBytes.reversed())
        }

        return data
    }
}
```

### Connection Method Used in This Workshop

Instead of NFC tag emulation, we use a direct BLE connection:

```swift
// ReaderViewModel.swift
func startReading() {
    // Original ISO 18013-5 flow:
    //   nfcService.startReaderSession()
    //   -> Obtain DeviceEngagement via NFC
    //   -> Extract BLE UUID and connect
    //
    // Using direct BLE connection due to iOS technical constraints:
    state = .scanning
    transportService.startCentralMode(nil)
}
```

> Note: All steps other than NFC tag emulation (BLE connection, CBOR encoding/decoding,
> selective attribute disclosure, biometric authentication) are implemented in compliance with ISO 18013-5.

### Error Types

```swift
enum NFCError: LocalizedError {
    case notAvailable
    case sessionInvalidated(String)
    case invalidMessage
    case parsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "NFC is not available on this device"
        case .sessionInvalidated(let reason):
            return "NFC session ended: \(reason)"
        case .invalidMessage:
            return "Invalid NFC message format"
        case .parsingFailed(let reason):
            return "Failed to parse NFC data: \(reason)"
        }
    }
}
```

## Next Steps

Continue to <doc:BLETransport> to implement the BLE communication layer that handles the actual data transfer.
