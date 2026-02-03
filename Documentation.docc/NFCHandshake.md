# NFC Handshake

ISO 18013-5 の NFC-to-BLE ハンドオーバーの仕組みと、iOS の技術的制約を理解する。

## Overview

ISO 18013-5 では、NFC ハンドシェイクによって Reader と Holder の間でセキュアな接続を確立します。Apple の ID Verifier API (Tap to Pay 風の体験) もこのプロトコルに基づいています。

本チャプターでは以下を学びます:

1. **ISO 18013-5 の NFC ハンドオーバー仕様** — どのように動作するのか
2. **iOS の技術的制約** — なぜサードパーティアプリでは実現できないのか
3. **Apple ID Verifier API の仕組み** — Apple がどのように制約を回避しているか
4. **Reader 側 NFC コードの実装** — CoreNFC で実現可能な部分

### ISO 18013-5: NFC Device Engagement フロー

```
Reader                              Holder
   │                                   │
   │ 1. Start NFC Session              │
   │   (NFCNDEFReaderSession)          │
   │───────────────────────────────────│
   │                                   │
   │ 2. Read NDEF Message              │
   │◄──────────────────────────────────│
   │   Contains:                       │  ← Holder が NDEF タグとして応答
   │   - Handover Select record ("Hs") │     (NFC タグエミュレーション / HCE)
   │   - BLE OOB data (Service UUID)   │
   │   - Device Engagement (CBOR)      │
   │                                   │
   │ 3. Parse Device Engagement        │
   │   → Extract BLE UUID              │
   │                                   │
   │ 4. Connect via BLE using UUID     │
   │───────────────────────────────────►
```

### NDEF メッセージの構造

NFC ハンドオーバーメッセージは3つの NDEF レコードで構成されます:

| # | レコード | フォーマット | 説明 |
|---|---------|------------|------|
| 1 | Handover Select | NFC Well-Known ("Hs") | ハンドオーバーの種別と参照 |
| 2 | BLE Carrier Config | MIME type | BLE OOB データ (Service UUID, LE Role) |
| 3 | Device Engagement | NFC External | CBOR エンコードされた DeviceEngagement |

---

## iOS の技術的制約

> Important: このセクションは本ワークショップの重要な学習ポイントです。
> iOS で ID 検証アプリを構築する際、何が可能で何が不可能かを正確に理解することが不可欠です。

### CoreNFC で実現可能なこと

| API | 機能 | 利用可能 |
|-----|------|---------|
| `NFCNDEFReaderSession` | NDEF タグの読み取り | iOS 11+ |
| `NFCTagReaderSession` | ISO 7816/14443/15693 タグの読み取り | iOS 13+ |
| `NFCNDEFPayload` | NDEF メッセージの作成 (データ構造として) | iOS 11+ |
| NDEF タグへの書き込み | 外部 NFC タグへのデータ書き込み | iOS 13+ |

### CoreNFC で実現不可能なこと

| 機能 | 理由 | 代替手段 |
|------|------|---------|
| **NFC タグエミュレーション (HCE)** | Apple Wallet / Secure Element 専用 | BLE 直接接続 |
| **iPhone を NDEF タグとして応答させる** | 公開 API なし | BLE advertising |
| **`NFCTagReaderSession` で他の iPhone を検出** | iPhone は NFC タグではない | BLE |

### Apple の ID Verifier API はなぜ動作するのか

Apple の `ProximityReader` framework (ID Verifier API) は以下を内部的に実装しています:

```
ProximityReader (Reader 側)
├── Enhanced Contactless Polling (ECP)
│   → ISO 18013 用の専用 NFC ポーリングを実施
│   → GymKit や他の NFC 用途と区別するための独自プロトコル
│
├── NFCNDEFReaderSession (内部使用)
│   → Holder の DeviceEngagement を NDEF 経由で取得
│
└── BLE Data Transfer (内部使用)
    → NFC から得た BLE UUID で自動接続
    → 暗号化されたセッション確立

Apple Wallet (Holder 側)
├── Secure Element
│   → iPhone を NFC タグとして振る舞わせる (HCE)
│   → DeviceEngagement を NDEF レスポンスとして返す
│
└── iOS System UI
    → ユーザーに開示リクエストを表示
    → Face ID / Touch ID で認証
```

**この全体が Apple のプロプライエタリ実装** であり:
- Reader 側: `ProximityReader` framework + 専用 entitlement (`com.apple.developer.proximity-reader.identity.read`) が必要
- Holder 側: Apple Wallet 限定 — サードパーティアプリでは NDEF タグとしての応答不可
- ECP は非公開プロトコル

### `CardSession` (iOS 17.4+) について

iOS 17.4 で導入された `CardSession` API は HCE-based contactless transactions を可能にしますが:

- **EEA (欧州経済領域) 限定**
- **決済用途向け** (EMV contactless payments)
- ISO 18013-5 の NDEF DeviceEngagement には対応していない
- 日本を含む EEA 外では利用不可

### NFC & SE Platform (iOS 18.1+) について

iOS 18.1 で導入された NFC & SE Platform は NFC アクセスを拡大しますが:

- 限定地域のみ
- Apple との個別契約・審査が必要
- 主にトランジット・ID カード等の特定用途

---

## Step 1: Reader 側 NFC コードの実装 (リファレンス)

以下のコードは CoreNFC で実現可能な Reader 側の実装です。
外部 NFC タグから DeviceEngagement を読み取る場合に使用できます。

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

    // ISO 18013-5 defined constants
    private let bleMimeType = "application/vnd.bluetooth.le.oob"
    private let deviceEngagementType = "iso.org:18013:deviceengagement"

    private override init() {
        super.init()
    }
}
```

### Step 2: NFC Reader Session の開始

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

> Note: このコードは外部 NFC タグを読み取る場合に動作します。
> 他の iPhone を NFC タグとして検出することはできません。

### Step 3: Delegate メソッドの実装

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

### Step 4: Handover メッセージのパース

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

### Step 5: Handover メッセージの作成 (学習用)

以下のコードは NDEF ハンドオーバーメッセージの構造を学ぶためのリファレンス実装です。
実際のアプリでは iPhone を NFC タグにできないため、このメッセージを NFC 経由で提供することはできません。

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

### 本ワークショップでの接続方法

NFC タグエミュレーションの代わりに、BLE 直接接続を使用します:

```swift
// ReaderViewModel.swift
func startReading() {
    // ISO 18013-5 の本来のフロー:
    //   nfcService.startReaderSession()
    //   → NFC で DeviceEngagement を取得
    //   → BLE UUID を抽出して接続
    //
    // iOS の技術的制約により BLE 直接接続を使用:
    state = .scanning
    bleService.startCentralMode()
}
```

> Note: NFC タグエミュレーション以外の全ステップ (BLE 接続、CBOR エンコード/デコード、
> 選択的属性開示、生体認証) は ISO 18013-5 に準拠した実装です。

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
