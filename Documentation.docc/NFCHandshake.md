# NFC Handshake

Implement NFC-based device engagement for initiating connections.

## Overview

In ISO 18013-5, the NFC handshake establishes the initial connection between devices. The Reader reads an NDEF message from the Holder containing BLE connection information.

> Note: For this workshop, we simplify the flow by going directly to BLE. This chapter explains how the full NFC handshake would work.

### Device Engagement Flow

```
Reader                              Holder
   │                                   │
   │ 1. Start NFC Session              │
   │───────────────────────────────────│
   │                                   │
   │ 2. Read NDEF Message              │
   │◄──────────────────────────────────│
   │   Contains:                       │
   │   - Handover Select record        │
   │   - BLE OOB data (Service UUID)   │
   │   - Device Engagement (CBOR)      │
   │                                   │
   │ 3. Parse Device Engagement        │
   │                                   │
   │ 4. Connect via BLE using UUID     │
   │───────────────────────────────────►
```

### Step 1: Create NFCService

Create `Services/NFCService.swift`:

```swift
import Foundation
import CoreNFC

class NFCService: NSObject, ObservableObject {
    static let shared = NFCService()

    @Published var isScanning = false
    @Published var error: NFCError?
    @Published var receivedEngagement: DeviceEngagement?

    private var readerSession: NFCNDEFReaderSession?

    // Callbacks
    var onEngagementReceived: ((DeviceEngagement, Data) -> Void)?
    var onError: ((NFCError) -> Void)?

    // Constants
    private let bleMimeType = "application/vnd.bluetooth.le.oob"
    private let deviceEngagementType = "iso.org:18013:deviceengagement"

    private override init() {
        super.init()
    }
}
```

### Step 2: Implement Reader Mode

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

### Step 3: Implement Delegate Methods

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

### Step 4: Parse Handover Message

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

### Step 5: Create Handover Message (Holder Side)

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

### Workshop Simplification

For this workshop, we skip NFC and connect directly via BLE:

```swift
// In ReaderViewModel
func startReading() {
    state = .scanning

    // Full implementation would do:
    // nfcService.startReaderSession()

    // Workshop simplification - go directly to BLE:
    state = .connecting
    bleService.startCentralMode()
}
```

This is because:
1. NFC tag emulation requires entitlements not available to all developers
2. Testing NFC requires specific hardware setup
3. BLE demonstrates the same data transfer concepts

### Real-World Implementation

In production:
1. Holder emulates an NFC tag with Device Engagement
2. Reader reads the tag to get BLE connection info
3. Reader connects via BLE using the received UUID
4. Data transfer proceeds over BLE

## Next Steps

Continue to <doc:BLETransport> to implement the BLE communication layer.
