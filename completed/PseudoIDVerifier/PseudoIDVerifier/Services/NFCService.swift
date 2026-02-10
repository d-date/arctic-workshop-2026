import Foundation
import Observation
import CoreNFC

// MARK: - NFC Service for Handshake

/// Service for NFC-based handshake to initiate BLE connection.
/// This implements the NFC handover mechanism as defined in ISO 18013-5.
///
/// ## iOS Technical Constraints
///
/// ISO 18013-5 specifies NFC-to-BLE handover:
///   - Reader starts an NFC session
///   - Holder's device provides DeviceEngagement (CBOR) as an NDEF tag
///   - Reader extracts the BLE UUID from DeviceEngagement and connects via BLE
///
/// However, iOS has the following constraints:
///
/// ### What CoreNFC CAN do
/// - `NFCNDEFReaderSession`: Read NDEF from external NFC tags
/// - `NFCTagReaderSession`: Read ISO 7816/14443/15693 tags
/// - Create NDEF messages (as data structures only)
///
/// ### What CoreNFC CANNOT do
/// - **NFC tag emulation (HCE)**: Making an iPhone act as an NDEF tag
///   - iOS 18.2 introduced HCE support via the NFC & SE Platform,
///     but it requires an entitlement request to Apple
///   - It is unclear whether general developers can obtain approval
///   - `CardSession` (iOS 17.4+) is EEA-only and limited to payment use cases
///   - Third-party apps can only use the Reader side without the entitlement
///
/// ### How Apple's ID Verifier API (ProximityReader) works
/// Apple's ProximityReader framework internally:
/// 1. Uses Enhanced Contactless Polling (ECP) for ISO 18013 NFC polling
/// 2. Apple Wallet returns DeviceEngagement as an NDEF tag at the system level
/// 3. Hands over from NFC to BLE for encrypted data transfer
/// → This is entirely Apple's proprietary implementation and cannot be reproduced via third-party APIs.
///
/// ### Approach in this workshop
/// - Reader-side NFC code (`startReaderSession`, `parseHandoverMessage`, etc.)
///   is kept as an ISO 18013-5 compliant reference implementation
/// - Holder-side `createHandoverMessage` is kept for learning NDEF message structure
/// - Actual connection uses direct BLE (`BLEService`)
@Observable
class NFCService: NSObject, @unchecked Sendable {
    static let shared = NFCService()

    // MARK: - Observable State

    @ObservationIgnored nonisolated(unsafe) var isScanning = false
    @ObservationIgnored nonisolated(unsafe) var error: NFCError?
    @ObservationIgnored nonisolated(unsafe) var receivedEngagement: DeviceEngagement?

    // MARK: - NFC Session

    @ObservationIgnored nonisolated(unsafe) private var readerSession: NFCNDEFReaderSession?

    // MARK: - Callbacks

    @ObservationIgnored nonisolated(unsafe) var onEngagementReceived: ((DeviceEngagement, Data) -> Void)?
    @ObservationIgnored nonisolated(unsafe) var onError: ((NFCError) -> Void)?

    // MARK: - Constants

    /// NDEF record type for handover select
    private let handoverSelectType = "Hs"

    /// MIME type for BLE carrier data
    private let bleMimeType = "application/vnd.bluetooth.le.oob"

    /// Custom type for device engagement
    private let deviceEngagementType = "iso.org:18013:deviceengagement"

    private override init() {
        super.init()
    }

    // MARK: - Reader Mode (Verifier)

    /// Start scanning for NFC tags containing device engagement
    nonisolated func startReaderSession() {
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

        readerSession?.alertMessage = "Hold your iPhone near the other device to verify identity."
        readerSession?.begin()
    }

    /// Stop the current reader session
    nonisolated func stopReaderSession() {
        readerSession?.invalidate()
        readerSession = nil
        DispatchQueue.main.async {
            self.isScanning = false
        }
    }

    // MARK: - Tag Writing (Holder/Presentment)

    /// Create NDEF message containing device engagement for BLE handover
    nonisolated func createHandoverMessage(bleUUID: String, engagement: DeviceEngagement) -> NFCNDEFMessage? {
        // Encode device engagement to CBOR
        let engagementData = CBORService.shared.encode(engagement: engagement)

        // Create BLE OOB data
        let bleOOBData = createBLEOOBData(uuid: bleUUID)

        // Create NDEF records
        var records: [NFCNDEFPayload] = []

        // 1. Handover Select record
        // Simplified handover select record for workshop
        let hsPayload = Data([0x15, 0xD1, 0x02, 0x04, 0x61, 0x63, 0x00, 0x01, 0x30]) // ac record referencing '0'
        let hsRecord = NFCNDEFPayload(
            format: .nfcWellKnown,
            type: Data(handoverSelectType.utf8),
            identifier: Data(),
            payload: hsPayload
        )
        records.append(hsRecord)

        // 2. BLE Carrier Configuration record
        let bleRecord = NFCNDEFPayload(
            format: .media,
            type: Data(bleMimeType.utf8),
            identifier: Data("0".utf8),
            payload: bleOOBData
        )
        records.append(bleRecord)

        // 3. Device Engagement record (external type)
        let deRecord = NFCNDEFPayload(
            format: .nfcExternal,
            type: Data(deviceEngagementType.utf8),
            identifier: Data(),
            payload: engagementData
        )
        records.append(deRecord)

        guard !records.isEmpty else { return nil }
        return NFCNDEFMessage(records: records)
    }

    /// Create BLE OOB (Out of Band) data for NFC handover
    nonisolated private func createBLEOOBData(uuid: String) -> Data {
        var data = Data()

        // LE Role: 0x00 = Peripheral only
        data.append(contentsOf: [0x02, 0x1C, 0x00]) // Length 2, Type 0x1C (LE Role), Value 0x00

        // Complete list of 128-bit service UUIDs
        // Convert UUID string to bytes (reverse order for BLE)
        if let uuidObj = UUID(uuidString: uuid) {
            let uuidBytes = withUnsafeBytes(of: uuidObj.uuid) { Array($0) }
            data.append(0x11) // Length: 16 + 1
            data.append(0x07) // Type: Complete list of 128-bit UUIDs
            data.append(contentsOf: uuidBytes.reversed())
        }

        return data
    }

    // MARK: - Parsing

    /// Parse device engagement from NDEF message
    nonisolated private func parseHandoverMessage(_ message: NFCNDEFMessage) -> (DeviceEngagement, Data)? {
        var bleUUIDData: Data?
        var engagementData: Data?

        for record in message.records {
            let typeString = String(data: record.type, encoding: .utf8) ?? ""

            switch record.typeNameFormat {
            case .media:
                // BLE OOB data
                if typeString == bleMimeType {
                    bleUUIDData = parseBLEOOBData(record.payload)
                }

            case .nfcExternal:
                // Device engagement
                if typeString == deviceEngagementType {
                    engagementData = record.payload
                }

            default:
                break
            }
        }

        // Decode device engagement from CBOR
        guard let engData = engagementData,
              let engagement = CBORService.shared.decodeEngagement(from: engData) else {
            return nil
        }

        // Return engagement and BLE UUID data
        let uuid = bleUUIDData ?? Data()
        return (engagement, uuid)
    }

    /// Parse BLE UUID from OOB data
    nonisolated private func parseBLEOOBData(_ data: Data) -> Data? {
        // Simple parsing: look for 128-bit UUID (type 0x07)
        var index = 0
        while index < data.count {
            let length = Int(data[index])
            guard index + length < data.count else { break }

            let type = data[index + 1]
            if type == 0x07 && length == 17 {
                // Found 128-bit UUID
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

// MARK: - NFCNDEFReaderSessionDelegate

nonisolated extension NFCService: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        guard let message = messages.first else {
            session.invalidate(errorMessage: "No NDEF message found")
            return
        }

        guard let (engagement, bleData) = parseHandoverMessage(message) else {
            session.invalidate(errorMessage: "Invalid handover message format")
            Task { @MainActor [weak self] in
                self?.error = .invalidMessage
                self?.onError?(.invalidMessage)
            }
            return
        }

        session.alertMessage = "Device engagement received!"
        session.invalidate()

        Task { @MainActor [weak self] in
            self?.receivedEngagement = engagement
            self?.isScanning = false
            self?.onEngagementReceived?(engagement, bleData)
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.isScanning = false

            if let nfcError = error as? NFCReaderError {
                switch nfcError.code {
                case .readerSessionInvalidationErrorUserCanceled:
                    // User cancelled - not an error
                    break
                case .readerSessionInvalidationErrorFirstNDEFTagRead:
                    // Successfully read - not an error
                    break
                default:
                    self?.error = .sessionInvalidated(nfcError.localizedDescription)
                    self?.onError?(.sessionInvalidated(nfcError.localizedDescription))
                }
            }
        }
    }

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        Task { @MainActor [weak self] in
            self?.isScanning = true
        }
    }
}

// MARK: - Error Types

nonisolated enum NFCError: LocalizedError {
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

// MARK: - NFC Availability Check

extension NFCService {
    /// Check if NFC reading is available on this device
    nonisolated var isNFCAvailable: Bool {
        NFCNDEFReaderSession.readingAvailable
    }
}
