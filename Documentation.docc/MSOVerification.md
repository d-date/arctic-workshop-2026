# MSO Verification

Verify the integrity of issuer-signed attributes using the Mobile Security Object (MSO).

## Overview

In ISO 18013-5, the **Mobile Security Object (MSO)** is a critical component that ensures the integrity of attributes in a mobile document (mdoc). The MSO contains SHA-256 digests of every `IssuerSignedItem`, allowing the Reader to verify that no attribute has been tampered with since the issuing authority signed the document.

The MSO is embedded inside the `issuerAuth` field as a **COSE_Sign1** structure (RFC 9052). The full chain of trust is:

```
issuerAuth = COSE_Sign1 {
    payload: MSO (CBOR-encoded) {
        version: "1.0",
        digestAlgorithm: "SHA-256",
        docType: "org.iso.18013.5.1.mDL",
        valueDigests: {
            "org.iso.18013.5.1": {
                0: SHA-256(Tag24(IssuerSignedItem[0])),
                1: SHA-256(Tag24(IssuerSignedItem[1])),
                ...
            }
        },
        validityInfo: {
            signed: "2023-06-01T00:00:00Z",
            validFrom: "2023-06-01T00:00:00Z",
            validUntil: "2028-06-01T00:00:00Z"
        }
    }
}
```

### Why Tag 24?

ISO 18013-5 requires each `IssuerSignedItem` to be wrapped in **CBOR Tag 24** (Encoded CBOR Data Item) before hashing. Tag 24 wraps the CBOR byte string of the item, which creates a canonical byte representation that both the issuer and verifier can independently reproduce:

```
digest = SHA-256( Tag24( IssuerSignedItem.toCBOR() ) )
       = SHA-256( 0xD818 || byteString(itemCBOR) )
```

This ensures that the digest computation is deterministic regardless of how the item is transmitted.

### Workshop Simplification

In production, the MSO is signed by the **issuing authority** (e.g., a DMV) using its own private key, and Readers verify the signature using the authority's public key obtained from a trusted certificate chain.

For this workshop, we simplify by reusing the device key from `CryptoService` as the issuer key. This lets us demonstrate the full verification flow without requiring a separate PKI infrastructure.

## Step 1: Encode and Decode the MSO

> **Initial project**: Open `Services/CBORService.swift`. Find the `📋 PASTE: MSOVerification Step 1` markers.

### encodeMSO

Implement `encodeMSO(docType:nameSpaces:validityInfo:)` to build the MSO CBOR structure. For each `IssuerSignedItem`, compute `SHA-256(Tag24(item CBOR bytes))` and store it in `valueDigests`:

```swift
func encodeMSO(
    docType: String,
    nameSpaces: [String: [IssuerSignedItem]],
    validityInfo: ValidityInfo
) -> Data {
    var msoMap: [CBOR: CBOR] = [:]

    msoMap[.utf8String("version")] = .utf8String("1.0")
    msoMap[.utf8String("digestAlgorithm")] = .utf8String("SHA-256")
    msoMap[.utf8String("docType")] = .utf8String(docType)

    // Build valueDigests: namespace → (digestID → SHA-256 hash)
    var valueDigestsMap: [CBOR: CBOR] = [:]
    for (namespace, items) in nameSpaces {
        var digestsMap: [CBOR: CBOR] = [:]
        for item in items {
            // ISO 18013-5: hash the Tag 24-wrapped CBOR encoding of each IssuerSignedItem
            let itemBytes = encodeIssuerSignedItem(item)
            let tagged = CBOR.tagged(CBOR.Tag(rawValue: 24), .byteString(itemBytes))
            let taggedBytes = Data(tagged.encode())
            let hash = CryptoService.shared.sha256(taggedBytes)
            digestsMap[.unsignedInt(UInt64(item.digestID))] = .byteString(Array(hash))
        }
        valueDigestsMap[.utf8String(namespace)] = .map(digestsMap)
    }
    msoMap[.utf8String("valueDigests")] = .map(valueDigestsMap)

    // validityInfo
    var validityMap: [CBOR: CBOR] = [:]
    validityMap[.utf8String("signed")] = .utf8String(validityInfo.signed)
    validityMap[.utf8String("validFrom")] = .utf8String(validityInfo.validFrom)
    validityMap[.utf8String("validUntil")] = .utf8String(validityInfo.validUntil)
    msoMap[.utf8String("validityInfo")] = .map(validityMap)

    return Data(CBOR.map(msoMap).encode())
}
```

### decodeMSO

Implement `decodeMSO(from:)` to parse the MSO CBOR back into a `MobileSecurityObject`:

```swift
func decodeMSO(from data: Data) -> MobileSecurityObject? {
    guard let cbor = try? CBOR.decode(Array(data)),
          case .map(let map) = cbor else {
        return nil
    }

    guard case .utf8String(let version) = map[.utf8String("version")],
          case .utf8String(let digestAlgorithm) = map[.utf8String("digestAlgorithm")],
          case .utf8String(let docType) = map[.utf8String("docType")],
          case .map(let valueDigestsMap) = map[.utf8String("valueDigests")],
          case .map(let validityMap) = map[.utf8String("validityInfo")] else {
        return nil
    }

    // Parse valueDigests
    var valueDigests: [String: [Int: Data]] = [:]
    for (nsKey, nsValue) in valueDigestsMap {
        guard case .utf8String(let namespace) = nsKey,
              case .map(let digestsMap) = nsValue else {
            continue
        }
        var digests: [Int: Data] = [:]
        for (idKey, hashValue) in digestsMap {
            guard case .unsignedInt(let digestID) = idKey,
                  case .byteString(let hashBytes) = hashValue else {
                continue
            }
            digests[Int(digestID)] = Data(hashBytes)
        }
        valueDigests[namespace] = digests
    }

    // Parse validityInfo
    guard case .utf8String(let signed) = validityMap[.utf8String("signed")],
          case .utf8String(let validFrom) = validityMap[.utf8String("validFrom")],
          case .utf8String(let validUntil) = validityMap[.utf8String("validUntil")] else {
        return nil
    }

    return MobileSecurityObject(
        version: version,
        digestAlgorithm: digestAlgorithm,
        valueDigests: valueDigests,
        docType: docType,
        validityInfo: ValidityInfo(signed: signed, validFrom: validFrom, validUntil: validUntil)
    )
}
```

## Step 2: Verify the MSO in the Reader

> **Initial project**: Open `Views/ReaderView.swift`. Find the `📋 PASTE: MSOVerification Step 2` marker inside `handleResponse`.

Replace the simple attribute extraction with full MSO verification:

```swift
private func handleResponse(_ response: DeviceResponse) {
    guard response.status == 0,
          let document = response.documents?.first else {
        state = .error("Invalid response from holder")
        transportService.stopCentralMode()
        return
    }

    // Step 1: Verify issuerAuth (COSE_Sign1) signature
    guard let issuerPublicKey = CryptoService.shared.devicePublicKey,
          let msoPayload = CryptoService.shared.verifyCOSESign1(
              document.issuerSigned.issuerAuth, using: issuerPublicKey
          ) else {
        state = .error("Issuer signature verification failed")
        transportService.stopCentralMode()
        return
    }

    // Step 2: Decode the MSO from the verified payload
    guard let mso = cborService.decodeMSO(from: msoPayload) else {
        state = .error("Failed to decode Mobile Security Object")
        transportService.stopCentralMode()
        return
    }

    // Step 3: Verify docType matches
    guard mso.docType == document.docType else {
        state = .error("Document type mismatch in MSO")
        transportService.stopCentralMode()
        return
    }

    // Step 4: Verify each IssuerSignedItem's digest against the MSO
    var attributes: [String: Any] = [:]
    for (namespace, items) in document.issuerSigned.nameSpaces {
        guard let digests = mso.valueDigests[namespace] else {
            state = .error("Missing digests for namespace: \(namespace)")
            transportService.stopCentralMode()
            return
        }

        for item in items {
            // Recompute the digest: SHA-256 of Tag 24-wrapped IssuerSignedItem CBOR
            let itemBytes = item.toCBOR()
            let tagged = CBOR.tagged(CBOR.Tag(rawValue: 24), .byteString(Array(itemBytes)))
            let taggedBytes = Data(tagged.encode())
            let computedHash = CryptoService.shared.sha256(taggedBytes)

            guard let expectedHash = digests[item.digestID],
                  computedHash == expectedHash else {
                state = .error("Digest verification failed for \(item.elementIdentifier)")
                transportService.stopCentralMode()
                return
            }

            attributes[item.elementIdentifier] = item.elementValue
        }
    }

    state = .success(attributes)
    transportService.stopCentralMode()
}
```

### Verification Flow Summary

```
Reader receives DeviceResponse
    │
    ├── 1. Verify COSE_Sign1 signature on issuerAuth
    │       → Extracts MSO payload
    │
    ├── 2. Decode MSO from payload
    │       → MobileSecurityObject with valueDigests
    │
    ├── 3. Check docType matches
    │
    ├── 4. For each IssuerSignedItem:
    │       a. Recompute SHA-256(Tag24(item.toCBOR()))
    │       b. Compare with MSO valueDigests[namespace][digestID]
    │       c. If mismatch → reject
    │
    └── 5. All digests verified → display attributes
```

## What This Protects Against

| Attack | Protection |
|--------|-----------|
| Attribute tampering | SHA-256 digest mismatch detected in Step 4 |
| Adding fake attributes | No matching digest in MSO for the injected item |
| Replacing the entire MSO | COSE_Sign1 signature check fails in Step 1 |
| Using an MSO from a different document | docType mismatch detected in Step 3 |
| Expired credentials | validityInfo check (not enforced in this workshop) |

> Note: In a production implementation, Step 1 would verify the COSE_Sign1 signature against a trusted issuing authority's certificate chain, not the device key. The Reader would also check `validityInfo` dates and verify the certificate hasn't been revoked.
