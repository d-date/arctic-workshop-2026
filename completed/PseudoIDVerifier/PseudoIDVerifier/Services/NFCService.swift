import Foundation
import CoreNFC

// MARK: - NFC Service for Handshake

/// Service for NFC-based handshake to initiate BLE connection.
/// This implements the NFC handover mechanism as defined in ISO 18013-5.
///
/// ## iOS の技術的制約
///
/// ISO 18013-5 では NFC-to-BLE ハンドオーバーが規定されている:
///   - Reader が NFC session を開始
///   - Holder の端末が NDEF タグとして DeviceEngagement (CBOR) を提供
///   - Reader が DeviceEngagement から BLE UUID を抽出し BLE 接続
///
/// しかし、iOS では以下の制約がある:
///
/// ### 実現可能なこと (CoreNFC)
/// - `NFCNDEFReaderSession`: 外部 NFC タグの NDEF 読み取り
/// - `NFCTagReaderSession`: ISO 7816/14443/15693 タグの読み取り
/// - NDEF メッセージの作成 (データ構造としてのみ)
///
/// ### 実現不可能なこと
/// - **NFC タグエミュレーション (HCE)**: iPhone を NDEF タグとして振る舞わせること
///   - Apple Wallet のみが Secure Element 経由で HCE を使用可能
///   - `CardSession` (iOS 17.4+) は EEA 限定の決済用途のみ
///   - サードパーティアプリでは Reader 側のみ利用可能
///
/// ### Apple ID Verifier API (ProximityReader) の仕組み
/// Apple の ProximityReader framework は内部的に:
/// 1. Enhanced Contactless Polling (ECP) で ISO 18013 用 NFC ポーリングを実施
/// 2. Apple Wallet がシステムレベルで NDEF タグとして DeviceEngagement を返す
/// 3. NFC から BLE にハンドオーバーし、暗号化されたデータ転送を実行
/// → これは全て Apple のプロプライエタリ実装であり、サードパーティ API では再現不可。
///
/// ### 本ワークショップでの対応
/// - Reader 側の NFC コード (`startReaderSession`, `parseHandoverMessage` 等) は
///   ISO 18013-5 準拠のリファレンス実装として残す
/// - Holder 側の `createHandoverMessage` も NDEF メッセージ構造の学習用として残す
/// - 実際の接続は BLE 直接接続 (`BLEService`) を使用
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
    func stopReaderSession() {
        readerSession?.invalidate()
        readerSession = nil
        DispatchQueue.main.async {
            self.isScanning = false
        }
    }

    // MARK: - Tag Writing (Holder/Presentment)

    /// Create NDEF message containing device engagement for BLE handover
    func createHandoverMessage(bleUUID: String, engagement: DeviceEngagement) -> NFCNDEFMessage? {
        // Encode device engagement to CBOR
        let engagementData = CBORService.shared.encode(engagement: engagement)

        // Create BLE OOB data
        let bleOOBData = createBLEOOBData(uuid: bleUUID)

        // Create NDEF records
        var records: [NFCNDEFPayload] = []

        // 1. Handover Select record
        // Simplified handover select record for workshop
        let hsPayload = Data([0x15, 0xD1, 0x02, 0x04, 0x61, 0x63, 0x00, 0x01, 0x30]) // ac record referencing '0'
        if let hsRecord = NFCNDEFPayload(
            format: .nfcWellKnown,
            type: Data(handoverSelectType.utf8),
            identifier: Data(),
            payload: hsPayload
        ) {
            records.append(hsRecord)
        }

        // 2. BLE Carrier Configuration record
        if let bleRecord = NFCNDEFPayload(
            format: .media,
            type: Data(bleMimeType.utf8),
            identifier: Data("0".utf8),
            payload: bleOOBData
        ) {
            records.append(bleRecord)
        }

        // 3. Device Engagement record (external type)
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

    /// Create BLE OOB (Out of Band) data for NFC handover
    private func createBLEOOBData(uuid: String) -> Data {
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
    private func parseHandoverMessage(_ message: NFCNDEFMessage) -> (DeviceEngagement, Data)? {
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
    private func parseBLEOOBData(_ data: Data) -> Data? {
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

extension NFCService: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        guard let message = messages.first else {
            session.invalidate(errorMessage: "No NDEF message found")
            return
        }

        guard let (engagement, bleData) = parseHandoverMessage(message) else {
            session.invalidate(errorMessage: "Invalid handover message format")
            DispatchQueue.main.async {
                self.error = .invalidMessage
                self.onError?(.invalidMessage)
            }
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

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isScanning = false

            if let nfcError = error as? NFCReaderError {
                switch nfcError.code {
                case .readerSessionInvalidationErrorUserCanceled:
                    // User cancelled - not an error
                    break
                case .readerSessionInvalidationErrorFirstNDEFTagRead:
                    // Successfully read - not an error
                    break
                default:
                    self.error = .sessionInvalidated(nfcError.localizedDescription)
                    self.onError?(.sessionInvalidated(nfcError.localizedDescription))
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
