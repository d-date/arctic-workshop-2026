# AGENTS.md - AI Assistant Guidelines for PseudoIDVerifier Workshop

## Project Overview

ARCTIC Conference 2026 のハンズオンワークショップ教材。
ISO 18013-5 (mDL) に基づく擬似 ID 検証システムを、2台の iPhone を使って構築する。

### Key Flow: NFC Tap → BLE → Selective Disclosure → Biometric → CBOR Response → Decode

```
[1] Reader Phone: "Tap to Verify" UI → BLE scanning 開始
[2] Presentment Phone: BLE advertising 開始 → Reader と BLE 接続確立
[3] Reader → Presentment: DeviceRequest 送信 (CBOR)
[4] Presentment: 選択的開示 UI 表示 → Face ID / Touch ID で認証
[5] Presentment → Reader: DeviceResponse 送信 (CBOR + filtered mdoc)
[6] Reader: CBOR デコード → Key-Value 表示
```

### iOS の技術的制約（重要）

- **NFC タグエミュレーション (HCE) はサードパーティアプリでは不可能**
  - Apple Wallet のみが iPhone を NDEF タグとして振る舞わせることができる
  - 本ワークショップでは BLE による直接接続で代替
  - Apple の ID Verifier API (ProximityReader) は NFC-to-BLE ハンドオーバーを内部的に実装するが、プロプライエタリ API であり、Reader 側の entitlement が必要
- **CoreNFC の Reader モードは利用可能** (`NFCNDEFReaderSession`)
  - 外部 NFC タグの読み取りは可能
  - ただし、もう一方の iPhone を NFC タグとして認識することはできない
- EEA 限定で HCE-based contactless (`CardSession`, iOS 17.4+) は開放されたが、ID 用途の NDEF エミュレーションは対象外

## Architecture

- **Two-project structure**: `initial/` (TODO付きスケルトン) と `completed/` (リファレンス実装)
- **Documentation.docc/**: DocC チュートリアル (9チャプター)
- **Frameworks**: SwiftUI, CoreBluetooth, CoreNFC, LocalAuthentication, CryptoKit, SwiftCBOR
- **Target**: iOS 17+, 実機2台必須 (Simulator は BLE/NFC 非対応)

## Code Conventions

- Swift style: `// MARK: -` でセクション分割、明示的アクセス制御
- Services: singleton パターン (`.shared`)
- ViewModels: `@MainActor` `ObservableObject` class
- State machines: enum (`ReaderState`, `PresentmentState`, `BLEConnectionState`)
- Error types: `LocalizedError` に準拠
- CBOR: SwiftCBOR ライブラリ (`CBOR.map`, `CBOR.array` パターン)
- ISO 18013-5 命名規約: mdoc, IssuerSigned, DeviceSigned, DeviceEngagement

## Workshop Conventions

- `initial/` ファイルでは `fatalError("Not implemented - Complete this in Chapter N")` で TODO を表現
- `completed/` は完全なリファレンス実装
- Documentation.docc のチャプターはフロー順に構成
- ダミークレデンシャルを使用（実際の発行フローなし）
- 暗号検証は教育目的で簡略化

## File Organization

```
Models/      MDoc.swift, DeviceRequest.swift, DummyCredentials.swift
Services/    NFCService.swift, BLEService.swift, CBORService.swift,
             AuthenticationService.swift, CryptoService.swift
Views/       ContentView.swift, ReaderView.swift, PresentmentView.swift,
             DisclosureRequestView.swift
```

## When Modifying Code

- `initial/` と `completed/` の構造を常に同期すること
- コードフローを変更したら Documentation.docc も更新
- `initial/` の TODO パターンにはチャプター番号を参照させる
- 2台の実機でテスト（Simulator は BLE/NFC 非対応）
- NFC 関連のコードを変更する場合、技術的制約セクションの内容と矛盾しないこと
