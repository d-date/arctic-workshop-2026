# Brush Up Materials - 実装プラン

## 分析結果サマリー

### completedプロジェクトの完成度評価

**結論: 完成度200%を満たしている。ワークショップのボリュームは2.5時間を超えている（推定3.5-4時間）。**

- 全13ファイルが完全に動作する実装を持つ
- CBORService: 709行 (encode/decode for mdoc, request, response, engagement + selective disclosure + diagnostics)
- BLEService: 512行 (Central/Peripheral両モード + チャンキング + 全デリゲート)
- AuthenticationService: 222行 (Face ID/Touch ID + async/await + エラーマッピング)
- ViewModel: ReaderViewModel (110行) + PresentmentViewModel (148行) が完全実装
- UI: 3つのView全てが動作するUI

**充足感**: 2.5時間で人々はID Verifier単体で十分な充足感を得られる。むしろ、コンテンツが多すぎて時間内に終わらないリスクがある。

### Remote Retrieval の要否

**結論: 不要。** 現在のID Verifierコンテンツだけで2.5時間を超えるボリュームがある。むしろ、コアパスを2.5時間に収まるようトリミングする方が重要。NFC章は既にスキップ扱い。Remote RetrievalはBonusセクションとしてドキュメントに言及する程度に留める。

---

## 実装タスク

### Phase 1: initialプロジェクトにスニペットペースト場所を設置

各initialファイルのfatalError箇所に、教材のどのステップに対応するか明確なマーカーと「ここにペースト」コメントを追加する。

#### 1-1. `initial/.../Services/CBORService.swift`
- `import SwiftCBOR` を追加（現在は `import Foundation` のみ）
- 各fatalErrorの前に `// MARK: - 📋 PASTE: <doc:CBOREncodingDecoding> Step X` マーカーを追加
- privateヘルパーメソッドのシグネチャ（`encodeIssuerSignedItem`, `encodeToCBOR`, `decodeIssuerSignedItem`, `decodeFromCBOR`）をスタブとして追加（教材にコードがあるので、参加者はメソッド本体だけ埋める）
- 対応するステップ:
  - `encode(mdoc:)` → Step 1
  - `encodeIssuerSignedItem` + `encodeToCBOR` → Step 1 (private helpers)
  - `decodeMDoc(from:)` → Step 2
  - `decodeIssuerSignedItem` + `decodeFromCBOR` → Step 2 (private helpers)
  - `encode(request:)` → Step 3
  - `encode(response:)` → Step 3 (追加 - 教材にスニペット追加必要)
  - `encode(engagement:)` → NFC用なのでOptional扱い
  - `decodeRequest(from:)` → Step 3 (追加 - 教材にスニペット追加必要)
  - `decodeResponse(from:)` → Step 3 (追加 - 教材にスニペット追加必要)
  - `decodeEngagement(from:)` → NFC用なのでOptional扱い
  - `extractAttributes(from:attributes:)` → Step 4 (Selective Disclosure章)
  - `createSelectiveResponse(from:for:)` → Step 4 (Selective Disclosure章)
  - `diagnosticString(from:)` → Bonus

#### 1-2. `initial/.../Services/BLEService.swift`
- 各fatalErrorの前にマーカーを追加
- `headerMoreData`/`headerLastChunk` 定数を追加（completed版にはあるがinitialには無い）
- 対応するステップ:
  - Central Mode (`startCentralMode`, `stopCentralMode`, `sendRequest`) → Step 1
  - Peripheral Mode (`startPeripheralMode`, `stopPeripheralMode`, `sendResponse`) → Step 2
  - `setupService()` → Step 2
  - Central delegates → Step 3
  - Peripheral delegates (`didDiscoverServices`, `didDiscoverCharacteristics`, `didUpdateValue`, `didWriteValue`) → Step 3
  - PeripheralManager delegates → Step 4
  - Data chunking (`sendDataInChunks`, `reassembleChunkedData`) → Step 5

#### 1-3. `initial/.../Services/AuthenticationService.swift`
- 2つのfatalError箇所にマーカー
  - `authenticateForDisclosure` → Step 1
  - `authenticate(reason:)` → Step 2

#### 1-4. `initial/.../Views/ReaderView.swift` (ViewModel部分)
- `startReading()` → 📋 PASTE: <doc:IntegrationTesting> ViewModel Step 1
- `cancelReading()` → 📋 PASTE: <doc:IntegrationTesting> ViewModel Step 1
- `init()` に `setupCallbacks()` 呼び出しとそのメソッドのスタブを追加

#### 1-5. `initial/.../Views/PresentmentView.swift` (ViewModel部分)
- `startPresenting()` → 📋 PASTE
- `cancelPresenting()` → 📋 PASTE
- `approveDisclosure()` → 📋 PASTE
- `denyDisclosure()` → 📋 PASTE
- `init()` に `setupCallbacks()` 呼び出しとメソッドスタブを追加
- `sendResponse(for:)` privateメソッドのスタブを追加

#### 1-6. `initial/.../Services/NFCService.swift`
- 全fatalError箇所に「Optional - NFC章」マーカーを追加
- ワークショップのコアパスではスキップ可能であることを明記

#### 1-7. `initial/.../Services/CryptoService.swift`
- `createCOSESign1`と`verifyCOSESign1`と`establishSessionKey`のfatalError箇所に「Bonus」マーカーを追加

#### 1-8. `initial/.../Models/MDoc.swift`
- `toCBOR()`と`fromCBOR(_:)`のfatalError箇所に「これらはCBORService経由で実装されるので、Chapter 3完了後に削除可能」コメントを追加

#### 1-9. `initial/.../Models/DeviceRequest.swift`
- 同上: `toCBOR()`と`fromCBOR(_:)`にコメント更新

### Phase 2: 教材（Documentation.docc）の更新

#### 2-1. `CBOREncodingDecoding.md` - 欠落スニペットの追加
現在カバーされていない以下のメソッドのスニペットを追加:
- `encode(response:)` - Step 3に追加
- `decodeRequest(from:)` - Step 2末尾に追加
- `decodeResponse(from:)` - Step 2末尾に追加

※ `encode(engagement:)` と `decodeEngagement(from:)` はNFC関連なので追加不要

#### 2-2. `IntegrationTesting.md` - ViewModel実装セクションの追加
現在、ViewModelの実装が一切ドキュメント化されていない。以下を追加:
- **"Step 0: Implement ViewModels"** セクションを追加
- ReaderViewModelの`setupCallbacks()` + `startReading()` + `handleResponse()` + `cancelReading()`
- PresentmentViewModelの`setupCallbacks()` + `startPresenting()` + `approveDisclosure()` + `sendResponse(for:)` + `denyDisclosure()` + `cancelPresenting()`
- これにより参加者は最後の統合ステップで全てを繋げられる

#### 2-3. `SelectiveDisclosure.md` - extractAttributes スニペット追加
- `extractAttributes(from:attributes:)` メソッドのコードスニペットを追加

#### 2-4. 各教材にinitialプロジェクトへのリンクを追加
- 各Stepの冒頭に「対応ファイル: `Services/CBORService.swift` のSTEP X マーカーを探してください」といった誘導文を追加

### Phase 3: コアパスの時間最適化

#### 3-1. `Documentation.md` にワークショップタイムラインを追加
```
| 時間 | セクション | 内容 |
|------|-----------|------|
| 0:00-0:15 | Getting Started + Setup | 概念説明、プロジェクト確認 |
| 0:15-0:45 | Understanding MDoc | モデル確認（既に実装済み） |
|           | CBOR Encoding/Decoding | encode(mdoc), decodeMDoc |
| 0:45-1:15 | CBOR continued | encode(request), decodeRequest, encode(response), decodeResponse |
| 1:15-1:30 | -- 休憩 -- | |
| 1:30-2:00 | BLE Transport | BLEService全メソッド実装 |
| 2:00-2:15 | Selective Disclosure + Auth | createSelectiveResponse + authenticateForDisclosure |
| 2:15-2:30 | Integration | ViewModel実装 + 2台でテスト |
```

#### 3-2. NFC章をOptional/Bonusとして明確化
- `NFCHandshake.md` の冒頭に「このセクションはOptionalです」注記を追加
- `Documentation.md` のTopicsセクションで `NFCHandshake` をBonusグループに移動

### Phase 4: Bonus - Remote Retrieval の言及

#### 4-1. IntegrationTesting.md の "Next Steps" に言及を追加
- "Verify with Wallet API を使った Remote Retrieval" の概念を簡潔に説明
- mDL/mdocをWallet経由で検証するフロー（HPKE → ローカルサーバー → CBORデコード）の概要図
- 実装は将来のワークショップ拡張として位置づけ

---

## ファイル変更サマリー

### initialプロジェクト (9ファイル変更)
1. `initial/.../Services/CBORService.swift` - importとスタブ追加、マーカー追加
2. `initial/.../Services/BLEService.swift` - 定数追加、マーカー追加
3. `initial/.../Services/AuthenticationService.swift` - マーカー追加
4. `initial/.../Services/NFCService.swift` - Optionalマーカー追加
5. `initial/.../Services/CryptoService.swift` - Bonusマーカー追加
6. `initial/.../Views/ReaderView.swift` - ViewModelスタブ拡充
7. `initial/.../Views/PresentmentView.swift` - ViewModelスタブ拡充
8. `initial/.../Models/MDoc.swift` - コメント更新
9. `initial/.../Models/DeviceRequest.swift` - コメント更新

### ドキュメント (5ファイル変更)
1. `Documentation.docc/Documentation.md` - タイムライン追加、NFC→Bonus移動
2. `Documentation.docc/CBOREncodingDecoding.md` - 欠落スニペット3つ追加
3. `Documentation.docc/SelectiveDisclosure.md` - extractAttributes追加
4. `Documentation.docc/IntegrationTesting.md` - ViewModel実装セクション追加
5. `Documentation.docc/NFCHandshake.md` - Optionalバナー追加
