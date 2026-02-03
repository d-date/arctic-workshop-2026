# Getting Started

Learn the basics of ISO 18013-5 and the workshop objectives.

## Overview

This workshop introduces you to mobile identity verification using the ISO 18013-5 standard. By the end, you'll have built an app that demonstrates:

1. **Reader Mode**: Request and verify specific attributes from an ID holder
2. **Presentment Mode**: Present your credentials with user consent

### What is ISO 18013-5?

ISO 18013-5 defines the mobile driving license (mDL) standard. It specifies how digital credentials are:

- Structured using **CBOR** (Concise Binary Object Representation)
- Signed using **COSE** (CBOR Object Signing and Encryption)
- Transferred using **NFC** and **BLE**
- Protected with **selective disclosure**

### Key Concepts

#### mdoc (Mobile Document)

An mdoc contains signed attributes organized by namespace:

```
mdoc
├── docType: "org.iso.18013.5.1.mDL"
├── issuerSigned
│   ├── nameSpaces
│   │   └── "org.iso.18013.5.1"
│   │       ├── family_name: "SMITH"
│   │       ├── given_name: "JOHN"
│   │       ├── age_over_21: true
│   │       └── ...
│   └── issuerAuth (COSE_Sign1)
└── deviceSigned (optional)
```

#### Selective Disclosure

The holder chooses which attributes to share. For example, when buying alcohol, only `age_over_21: true` needs to be revealed—not your name, address, or birth date.

#### Device Engagement

ISO 18013-5 では、データ転送前に NFC 経由でデバイス間の接続情報を交換します:

1. Reader が NFC タグ/メッセージを Holder から読み取る
2. BLE サービス UUID を抽出
3. BLE 経由でデータ転送

> Important: iOS ではサードパーティアプリで NFC タグエミュレーション (HCE) ができないため、
> Holder 側を NDEF タグとして振る舞わせることは不可能です。
> 本ワークショップでは BLE 直接接続を使用します。
> 詳細は <doc:NFCHandshake> を参照してください。

### Workshop Structure

| Chapter | Topic | What You'll Build |
|---------|-------|-------------------|
| 1 | Introduction | Understanding the architecture |
| 2 | Project Setup | Xcode project with dependencies |
| 3 | Data Layer | mdoc structures and CBOR encoding |
| 4 | NFC Handshake | ISO 18013-5 NFC 仕様 + iOS 制約の理解 |
| 5 | BLE Transport | CoreBluetooth central/peripheral |
| 6 | Selective Disclosure | Request/response with LocalAuth |
| 7 | Integration | End-to-end testing |

### Requirements

- Two iPhones with iOS 17+
- Xcode 15+
- NFC-capable devices (iPhone 7 or later)
- Bluetooth enabled

### Project Structure

```
PseudoIDVerifier/
├── PseudoIDVerifierApp.swift
├── ContentView.swift
├── Models/
│   ├── MDoc.swift
│   ├── DeviceRequest.swift
│   └── DummyCredentials.swift
├── Services/
│   ├── CBORService.swift
│   ├── NFCService.swift
│   ├── BLEService.swift
│   ├── CryptoService.swift
│   └── AuthenticationService.swift
└── Views/
    ├── ReaderView.swift
    ├── PresentmentView.swift
    └── DisclosureRequestView.swift
```

## Next Steps

Continue to <doc:ProjectSetup> to create the Xcode project.
