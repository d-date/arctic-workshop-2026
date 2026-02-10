# CBOR Encoding and Decoding

Implement CBOR serialization for mdoc structures.

## Overview

CBOR (Concise Binary Object Representation) is a binary data format used by ISO 18013-5. It's similar to JSON but more compact and supports binary data natively.

### Why CBOR?

- **Compact**: Smaller than JSON for the same data
- **Binary-safe**: Can embed binary data without encoding
- **Self-describing**: Types are encoded in the data
- **Deterministic**: Same data produces same bytes

### Step 1: Create CBORService

> **Initial project**: Open `Services/CBORService.swift` and find the `📋 PASTE: Step 1` markers.

Paste the following into `Services/CBORService.swift`:

```swift
import Foundation
import SwiftCBOR

class CBORService {
    static let shared = CBORService()

    private init() {}

    // MARK: - Encoding

    func encode(mdoc: MDoc) -> Data {
        var map: [CBOR: CBOR] = [:]

        // docType
        map[.utf8String("docType")] = .utf8String(mdoc.docType)

        // issuerSigned
        var issuerSignedMap: [CBOR: CBOR] = [:]

        // nameSpaces
        var nameSpacesMap: [CBOR: CBOR] = [:]
        for (namespace, items) in mdoc.issuerSigned.nameSpaces {
            var itemsArray: [CBOR] = []
            for item in items {
                let itemCBOR = encodeIssuerSignedItem(item)
                // Tag 24 indicates embedded CBOR
                itemsArray.append(.tagged(
                    CBOR.Tag(rawValue: 24),
                    .byteString(itemCBOR)
                ))
            }
            nameSpacesMap[.utf8String(namespace)] = .array(itemsArray)
        }
        issuerSignedMap[.utf8String("nameSpaces")] = .map(nameSpacesMap)
        issuerSignedMap[.utf8String("issuerAuth")] = .byteString(
            Array(mdoc.issuerSigned.issuerAuth)
        )

        map[.utf8String("issuerSigned")] = .map(issuerSignedMap)

        return Data(CBOR.map(map).encode())
    }

    private func encodeIssuerSignedItem(_ item: IssuerSignedItem) -> [UInt8] {
        var map: [CBOR: CBOR] = [:]

        map[.utf8String("digestID")] = .unsignedInt(UInt64(item.digestID))
        map[.utf8String("random")] = .byteString(Array(item.random))
        map[.utf8String("elementIdentifier")] = .utf8String(item.elementIdentifier)
        map[.utf8String("elementValue")] = encodeToCBOR(item.elementValue)

        return CBOR.map(map).encode()
    }

    private func encodeToCBOR(_ value: Any) -> CBOR {
        switch value {
        case let boolVal as Bool:
            return .boolean(boolVal)
        case let intVal as Int:
            return intVal >= 0
                ? .unsignedInt(UInt64(intVal))
                : .negativeInt(UInt64(-intVal - 1))
        case let stringVal as String:
            return .utf8String(stringVal)
        case let dataVal as Data:
            return .byteString(Array(dataVal))
        default:
            return .utf8String(String(describing: value))
        }
    }
}
```

### Step 2: Implement Decoding

> **Initial project**: Find the `📋 PASTE: Step 2` markers in `Services/CBORService.swift`.

Add decoding methods to `CBORService`:

```swift
extension CBORService {
    func decodeMDoc(from data: Data) -> MDoc? {
        guard let cbor = try? CBOR.decode(Array(data)),
              case .map(let map) = cbor else {
            return nil
        }

        // Extract docType
        guard case .utf8String(let docType) = map[.utf8String("docType")] else {
            return nil
        }

        // Extract issuerSigned
        guard case .map(let issuerSignedMap) = map[.utf8String("issuerSigned")] else {
            return nil
        }

        // Parse nameSpaces
        var nameSpaces: [String: [IssuerSignedItem]] = [:]
        if case .map(let nsMap) = issuerSignedMap[.utf8String("nameSpaces")] {
            for (nsKey, nsValue) in nsMap {
                guard case .utf8String(let namespace) = nsKey,
                      case .array(let itemsArray) = nsValue else {
                    continue
                }

                var items: [IssuerSignedItem] = []
                for itemCBOR in itemsArray {
                    if case .tagged(_, let inner) = itemCBOR,
                       case .byteString(let itemBytes) = inner,
                       let item = decodeIssuerSignedItem(Data(itemBytes)) {
                        items.append(item)
                    }
                }
                nameSpaces[namespace] = items
            }
        }

        // Parse issuerAuth
        var issuerAuth = Data()
        if case .byteString(let authBytes) = issuerSignedMap[.utf8String("issuerAuth")] {
            issuerAuth = Data(authBytes)
        }

        let issuerSigned = IssuerSigned(
            nameSpaces: nameSpaces,
            issuerAuth: issuerAuth
        )

        return MDoc(
            docType: docType,
            issuerSigned: issuerSigned,
            deviceSigned: nil
        )
    }

    private func decodeIssuerSignedItem(_ data: Data) -> IssuerSignedItem? {
        guard let cbor = try? CBOR.decode(Array(data)),
              case .map(let map) = cbor,
              case .unsignedInt(let digestID) = map[.utf8String("digestID")],
              case .byteString(let random) = map[.utf8String("random")],
              case .utf8String(let elementId) = map[.utf8String("elementIdentifier")] else {
            return nil
        }

        let elementValue = decodeFromCBOR(map[.utf8String("elementValue")])

        return IssuerSignedItem(
            digestID: Int(digestID),
            random: Data(random),
            elementIdentifier: elementId,
            elementValue: elementValue ?? "null"
        )
    }

    private func decodeFromCBOR(_ cbor: CBOR?) -> Any? {
        guard let cbor = cbor else { return nil }

        switch cbor {
        case .boolean(let val): return val
        case .unsignedInt(let val): return Int(val)
        case .utf8String(let val): return val
        case .byteString(let val): return Data(val)
        default: return nil
        }
    }
}
```

### Step 3: Encode DeviceRequest

> **Initial project**: Find the `📋 PASTE: Step 3` marker in `Services/CBORService.swift`.

Add request encoding:

```swift
extension CBORService {
    func encode(request: DeviceRequest) -> Data {
        var map: [CBOR: CBOR] = [:]

        map[.utf8String("version")] = .utf8String(request.version)

        var docRequestsArray: [CBOR] = []
        for docRequest in request.docRequests {
            var drMap: [CBOR: CBOR] = [:]

            var irMap: [CBOR: CBOR] = [:]
            irMap[.utf8String("docType")] = .utf8String(
                docRequest.itemsRequest.docType
            )

            var nsMap: [CBOR: CBOR] = [:]
            for (namespace, elements) in docRequest.itemsRequest.nameSpaces {
                var elemMap: [CBOR: CBOR] = [:]
                for (elemId, retain) in elements {
                    elemMap[.utf8String(elemId)] = .boolean(retain)
                }
                nsMap[.utf8String(namespace)] = .map(elemMap)
            }
            irMap[.utf8String("nameSpaces")] = .map(nsMap)

            drMap[.utf8String("itemsRequest")] = .map(irMap)
            docRequestsArray.append(.map(drMap))
        }

        map[.utf8String("docRequests")] = .array(docRequestsArray)

        return Data(CBOR.map(map).encode())
    }
}
```

### Step 4: Encode/Decode DeviceResponse and DecodeRequest

These methods complete the round-trip: the Holder encodes a `DeviceResponse`, and the Reader decodes it.

> **Initial project**: Find the `📋 PASTE: Step 4` markers in `Services/CBORService.swift`.

```swift
extension CBORService {
    /// Encode a DeviceResponse to CBOR format
    func encode(response: DeviceResponse) -> Data {
        var map: [CBOR: CBOR] = [:]

        map[.utf8String("version")] = .utf8String(response.version)
        map[.utf8String("status")] = .unsignedInt(UInt64(response.status))

        if let documents = response.documents {
            var docsArray: [CBOR] = []
            for doc in documents {
                var docMap: [CBOR: CBOR] = [:]
                docMap[.utf8String("docType")] = .utf8String(doc.docType)

                // Encode issuerSigned
                var issuerSignedMap: [CBOR: CBOR] = [:]
                var nameSpacesMap: [CBOR: CBOR] = [:]
                for (namespace, items) in doc.issuerSigned.nameSpaces {
                    var itemsArray: [CBOR] = []
                    for item in items {
                        let itemCBOR = encodeIssuerSignedItem(item)
                        itemsArray.append(.tagged(
                            CBOR.Tag(rawValue: 24),
                            .byteString(itemCBOR)
                        ))
                    }
                    nameSpacesMap[.utf8String(namespace)] = .array(itemsArray)
                }
                issuerSignedMap[.utf8String("nameSpaces")] = .map(nameSpacesMap)
                issuerSignedMap[.utf8String("issuerAuth")] = .byteString(
                    Array(doc.issuerSigned.issuerAuth)
                )
                docMap[.utf8String("issuerSigned")] = .map(issuerSignedMap)

                // Encode deviceSigned
                var deviceSignedMap: [CBOR: CBOR] = [:]
                deviceSignedMap[.utf8String("nameSpaces")] = .byteString(
                    Array(doc.deviceSigned.nameSpaces)
                )
                var deviceAuthMap: [CBOR: CBOR] = [:]
                if let mac = doc.deviceSigned.deviceAuth.deviceMac {
                    deviceAuthMap[.utf8String("deviceMac")] = .byteString(Array(mac))
                }
                if let sig = doc.deviceSigned.deviceAuth.deviceSignature {
                    deviceAuthMap[.utf8String("deviceSignature")] = .byteString(Array(sig))
                }
                deviceSignedMap[.utf8String("deviceAuth")] = .map(deviceAuthMap)
                docMap[.utf8String("deviceSigned")] = .map(deviceSignedMap)

                docsArray.append(.map(docMap))
            }
            map[.utf8String("documents")] = .array(docsArray)
        }

        return Data(CBOR.map(map).encode())
    }

    /// Decode CBOR data to a DeviceRequest
    func decodeRequest(from data: Data) -> DeviceRequest? {
        guard let cbor = try? CBOR.decode(Array(data)),
              case .map(let map) = cbor,
              case .utf8String(let version) = map[.utf8String("version")],
              case .array(let docRequestsArray) = map[.utf8String("docRequests")] else {
            return nil
        }

        var docRequests: [DocRequest] = []
        for drCBOR in docRequestsArray {
            guard case .map(let drMap) = drCBOR,
                  case .map(let irMap) = drMap[.utf8String("itemsRequest")],
                  case .utf8String(let docType) = irMap[.utf8String("docType")],
                  case .map(let nsMap) = irMap[.utf8String("nameSpaces")] else {
                continue
            }

            var nameSpaces: [String: [String: Bool]] = [:]
            for (nsKey, nsValue) in nsMap {
                guard case .utf8String(let namespace) = nsKey,
                      case .map(let elementsMap) = nsValue else {
                    continue
                }
                var elements: [String: Bool] = [:]
                for (elemKey, elemValue) in elementsMap {
                    if case .utf8String(let elemId) = elemKey,
                       case .boolean(let retain) = elemValue {
                        elements[elemId] = retain
                    }
                }
                nameSpaces[namespace] = elements
            }

            var readerAuth: Data? = nil
            if case .byteString(let authBytes) = drMap[.utf8String("readerAuth")] {
                readerAuth = Data(authBytes)
            }

            let itemsRequest = ItemsRequest(docType: docType, nameSpaces: nameSpaces)
            docRequests.append(DocRequest(itemsRequest: itemsRequest, readerAuth: readerAuth))
        }

        return DeviceRequest(version: version, docRequests: docRequests)
    }

    /// Decode CBOR data to a DeviceResponse
    func decodeResponse(from data: Data) -> DeviceResponse? {
        guard let cbor = try? CBOR.decode(Array(data)),
              case .map(let map) = cbor,
              case .utf8String(let version) = map[.utf8String("version")],
              case .unsignedInt(let status) = map[.utf8String("status")] else {
            return nil
        }

        var documents: [Document]? = nil
        if case .array(let docsArray) = map[.utf8String("documents")] {
            var docs: [Document] = []
            for docCBOR in docsArray {
                guard case .map(let docMap) = docCBOR,
                      case .utf8String(let docType) = docMap[.utf8String("docType")],
                      case .map(let issuerSignedMap) = docMap[.utf8String("issuerSigned")],
                      case .map(let deviceSignedMap) = docMap[.utf8String("deviceSigned")] else {
                    continue
                }

                // Parse issuerSigned
                var nameSpaces: [String: [IssuerSignedItem]] = [:]
                if case .map(let nsMap) = issuerSignedMap[.utf8String("nameSpaces")] {
                    for (nsKey, nsValue) in nsMap {
                        guard case .utf8String(let namespace) = nsKey,
                              case .array(let itemsArray) = nsValue else { continue }
                        var items: [IssuerSignedItem] = []
                        for itemCBOR in itemsArray {
                            if case .tagged(_, let inner) = itemCBOR,
                               case .byteString(let itemBytes) = inner,
                               let item = decodeIssuerSignedItem(Data(itemBytes)) {
                                items.append(item)
                            }
                        }
                        nameSpaces[namespace] = items
                    }
                }
                var issuerAuth = Data()
                if case .byteString(let authBytes) = issuerSignedMap[.utf8String("issuerAuth")] {
                    issuerAuth = Data(authBytes)
                }
                let issuerSigned = IssuerSigned(nameSpaces: nameSpaces, issuerAuth: issuerAuth)

                // Parse deviceSigned
                var dsNameSpaces = Data()
                if case .byteString(let nsBytes) = deviceSignedMap[.utf8String("nameSpaces")] {
                    dsNameSpaces = Data(nsBytes)
                }
                var deviceMac: Data? = nil
                var deviceSignature: Data? = nil
                if case .map(let authMap) = deviceSignedMap[.utf8String("deviceAuth")] {
                    if case .byteString(let macBytes) = authMap[.utf8String("deviceMac")] {
                        deviceMac = Data(macBytes)
                    }
                    if case .byteString(let sigBytes) = authMap[.utf8String("deviceSignature")] {
                        deviceSignature = Data(sigBytes)
                    }
                }
                let deviceSigned = DeviceSigned(
                    nameSpaces: dsNameSpaces,
                    deviceAuth: DeviceAuth(deviceMac: deviceMac, deviceSignature: deviceSignature)
                )

                docs.append(Document(
                    docType: docType,
                    issuerSigned: issuerSigned,
                    deviceSigned: deviceSigned,
                    errors: nil
                ))
            }
            documents = docs
        }

        return DeviceResponse(
            version: version,
            documents: documents,
            documentErrors: nil,
            status: Int(status)
        )
    }
}
```

### Testing Your Implementation

```swift
// Test encoding and decoding
let mdoc = DummyCredentials.createSampleMDL()
let encoded = CBORService.shared.encode(mdoc: mdoc)
print("Encoded size: \(encoded.count) bytes")

if let decoded = CBORService.shared.decodeMDoc(from: encoded) {
    print("Decoded docType: \(decoded.docType)")
    // Verify attributes match
}
```

### CBOR Diagnostic Output

Add a helper for debugging:

```swift
extension CBORService {
    func diagnosticString(from data: Data) -> String {
        guard let cbor = try? CBOR.decode(Array(data)) else {
            return "Invalid CBOR"
        }
        return describeCBOR(cbor, indent: 0)
    }

    private func describeCBOR(_ cbor: CBOR, indent: Int) -> String {
        let prefix = String(repeating: "  ", count: indent)

        switch cbor {
        case .utf8String(let str): return "\"\(str)\""
        case .unsignedInt(let val): return "\(val)"
        case .boolean(let val): return val ? "true" : "false"
        case .byteString(let bytes):
            return "h'\(bytes.prefix(8).map { String(format: "%02x", $0) }.joined())...'"
        case .map(let map):
            var result = "{\n"
            for (key, value) in map {
                result += "\(prefix)  \(describeCBOR(key, indent: indent+1)): "
                result += "\(describeCBOR(value, indent: indent+1)),\n"
            }
            result += "\(prefix)}"
            return result
        case .array(let arr):
            var result = "[\n"
            for item in arr {
                result += "\(prefix)  \(describeCBOR(item, indent: indent+1)),\n"
            }
            result += "\(prefix)]"
            return result
        default:
            return String(describing: cbor)
        }
    }
}
```

## Next Steps: Pair Work Begins

From here, the workshop splits into **pair work**. Decide who takes which role:

| Role | What you'll build | Next chapter |
|------|------------------|-------------|
| **Reader** (Verifier) | Browse/scan, send requests, MSO verification | <doc:MPCTransport> (Reader steps) |
| **Holder** (Presentment) | Advertise, selective disclosure, biometric auth | <doc:MPCTransport> (Holder steps) |

Both of you will work through the same transport chapters (<doc:MPCTransport> and <doc:BLETransport>), but each person implements only their role-specific methods. After BLE, the paths diverge further:

- **Reader** proceeds to <doc:MSOVerification> (verify issuerAuth and digests)
- **Holder** proceeds to <doc:SelectiveDisclosure> and <doc:BiometricAuthentication>

You'll rejoin for <doc:IntegrationTesting> to test the complete flow together.

> Tip: Optionally, read <doc:NFCHandshake> for background on the ISO 18013-5 NFC-to-BLE handover mechanism. This is educational material and not required for the workshop.

## See Also

- <doc:UnderstandingMDoc>
- <doc:MPCTransport>
- <doc:BLETransport>
