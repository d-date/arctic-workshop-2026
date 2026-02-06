import Foundation
import CoreNFC

// MARK: - NFC Service for Handshake

/// Service for NFC-based handshake to initiate BLE connection.
/// This implements the NFC handover mechanism as defined in ISO 18013-5.
///
/// ## iOS Technical Constraints
///
/// ### What CoreNFC CAN do
/// - `NFCNDEFReaderSession`: Read NDEF from external NFC tags (Reader side)
/// - `NFCTagReaderSession`: Read ISO 7816/14443/15693 tags
/// - Create NDEF messages (as data structures only)
///
/// ### What CoreNFC CANNOT do
/// - **NFC tag emulation (HCE)**: Making an iPhone act as an NDEF tag
///   - iOS 18.2 introduced HCE support via the NFC & SE Platform,
///     but it requires an entitlement request to Apple
///   - It is unclear whether general developers can obtain approval
///   - Third-party apps can only use the Reader side without the entitlement
///
/// ### How Apple's ID Verifier API (ProximityReader) works
/// Apple's ProximityReader framework internally:
/// 1. Uses Enhanced Contactless Polling (ECP) for ISO 18013 NFC polling
/// 2. Apple Wallet returns DeviceEngagement as an NDEF tag at the system level
/// 3. Hands over from NFC to BLE for encrypted data transfer
/// → Cannot be reproduced via third-party APIs.
///
/// ### Approach in this workshop
/// - Reader-side NFC code in this file is an ISO 18013-5 compliant reference implementation
/// - Actual connection uses direct BLE (`BLEService`)
class NFCService: NSObject, ObservableObject {
    static let shared = NFCService()

    // MARK: - Published State

    @Published var isScanning = false
    @Published var error: NFCError?
    @Published var receivedEngagement: DeviceEngagement?

    // MARK: - NFC Session

    private var readerSession: NFCNDEFReaderSession?

    // MARK: - Callbacks

    var onEngagementReceived: ((DeviceEngagement, Data) -> Void)?
    var onError: ((NFCError) -> Void)?

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
    func startReaderSession() {
        // TODO: Implement NFC reader session
        //
        // Steps:
        // 1. Check if NFC is available using NFCNDEFReaderSession.readingAvailable
        // 2. Create an NFCNDEFReaderSession with this object as delegate
        // 3. Set alertMessage for the NFC sheet
        // 4. Call begin() to start scanning
        //
        // Hint:
        // readerSession = NFCNDEFReaderSession(
        //     delegate: self,
        //     queue: nil,
        //     invalidateAfterFirstRead: true
        // )

        fatalError("Not implemented - Complete this in Chapter 4")
    }

    /// Stop the current reader session
    func stopReaderSession() {
        // TODO: Invalidate the reader session

        fatalError("Not implemented - Complete this in Chapter 4")
    }

    // MARK: - Tag Writing (Holder/Presentment)

    /// Create NDEF message containing device engagement for BLE handover
    /// - Parameters:
    ///   - bleUUID: The BLE service UUID to connect to
    ///   - engagement: The device engagement data
    /// - Returns: NDEF message ready to be written/emulated
    func createHandoverMessage(bleUUID: String, engagement: DeviceEngagement) -> NFCNDEFMessage? {
        // TODO: Implement NDEF message creation
        //
        // The message should contain:
        // 1. Handover Select record (type "Hs")
        // 2. BLE Carrier Configuration record
        // 3. Device Engagement record
        //
        // For BLE OOB data format, see Bluetooth Core Specification Supplement

        fatalError("Not implemented - Complete this in Chapter 4")
    }

    /// Create BLE OOB (Out of Band) data for NFC handover
    /// - Parameter uuid: The BLE service UUID
    /// - Returns: Formatted OOB data
    private func createBLEOOBData(uuid: String) -> Data {
        // TODO: Implement BLE OOB data creation
        //
        // BLE OOB data format:
        // - Length (2 bytes)
        // - BLE Device Address (optional, 7 bytes)
        // - LE Role (1 byte): 0x00 = Peripheral only
        // - Service UUIDs (variable)
        //
        // For this workshop, we'll use a simplified format

        fatalError("Not implemented - Complete this in Chapter 4")
    }

    // MARK: - Parsing

    /// Parse device engagement from NDEF message
    /// - Parameter message: The NDEF message received
    /// - Returns: Tuple of DeviceEngagement and BLE UUID data
    private func parseHandoverMessage(_ message: NFCNDEFMessage) -> (DeviceEngagement, Data)? {
        // TODO: Implement NDEF message parsing
        //
        // Steps:
        // 1. Find the handover select record
        // 2. Extract the BLE carrier data
        // 3. Extract the device engagement record
        // 4. Decode the device engagement from CBOR

        fatalError("Not implemented - Complete this in Chapter 4")
    }
}

// MARK: - NFCNDEFReaderSessionDelegate

extension NFCService: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // TODO: Handle detected NDEF messages
        //
        // Steps:
        // 1. Take the first message
        // 2. Parse it using parseHandoverMessage
        // 3. Call onEngagementReceived callback
        // 4. Update published state

        fatalError("Not implemented - Complete this in Chapter 4")
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // TODO: Handle session invalidation
        //
        // Check if the error is user cancellation or an actual error
        // Update the published error state accordingly

        DispatchQueue.main.async {
            self.isScanning = false

            if let nfcError = error as? NFCReaderError {
                switch nfcError.code {
                case .readerSessionInvalidationErrorUserCanceled:
                    // User cancelled - not an error
                    break
                default:
                    self.error = .sessionInvalidated(nfcError.localizedDescription)
                    self.onError?(.sessionInvalidated(nfcError.localizedDescription))
                }
            }
        }
    }

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        // TODO: Handle session becoming active
        DispatchQueue.main.async {
            self.isScanning = true
        }
    }
}

// MARK: - Error Types

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

// MARK: - NFC Availability Check

extension NFCService {
    /// Check if NFC reading is available on this device
    var isNFCAvailable: Bool {
        NFCNDEFReaderSession.readingAvailable
    }
}
