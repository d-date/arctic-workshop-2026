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

Create `Services/CBORService.swift`:

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

## Next Steps

Continue to <doc:NFCHandshake> to implement the NFC connection handshake.
