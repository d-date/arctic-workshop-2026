# Understanding mdoc

Learn about the mobile document structure defined by ISO 18013-5.

## Overview

The mdoc (mobile document) is the core data structure for mobile credentials. It contains signed attributes that can be selectively disclosed to verifiers.

### mdoc Structure

```
MDoc
├── docType: String              // "org.iso.18013.5.1.mDL"
├── issuerSigned: IssuerSigned
│   ├── nameSpaces: [String: [IssuerSignedItem]]
│   │   └── "org.iso.18013.5.1": [
│   │       IssuerSignedItem(digestID, random, elementIdentifier, elementValue),
│   │       ...
│   │   ]
│   └── issuerAuth: Data         // COSE_Sign1
└── deviceSigned: DeviceSigned?  // Optional device authentication
```

### Step 1: Define the MDoc Model

Create `Models/MDoc.swift`:

```swift
import Foundation

// Document type identifier for mobile driving license
let mDLDocType = "org.iso.18013.5.1.mDL"

// Namespace for mDL attributes
let mDLNamespace = "org.iso.18013.5.1"

/// Mobile Document (mdoc) structure according to ISO 18013-5
struct MDoc {
    let docType: String
    let issuerSigned: IssuerSigned
    let deviceSigned: DeviceSigned?
}

/// Issuer-signed portion of the mdoc
struct IssuerSigned {
    /// Map of namespace to array of signed items
    let nameSpaces: [String: [IssuerSignedItem]]

    /// COSE_Sign1 structure containing the issuer's signature
    let issuerAuth: Data
}

/// Individual signed item within a namespace
struct IssuerSignedItem {
    /// Unique identifier for this item within the document
    let digestID: Int

    /// Random bytes for privacy protection
    let random: Data

    /// The attribute identifier (e.g., "family_name", "age_over_21")
    let elementIdentifier: String

    /// The attribute value
    let elementValue: Any
}
```

### Step 2: Define Device Structures

Add to `MDoc.swift`:

```swift
/// Device-signed portion of the mdoc
struct DeviceSigned {
    /// CBOR-encoded device namespaces
    let nameSpaces: Data

    /// Device authentication data
    let deviceAuth: DeviceAuth
}

/// Device authentication structure
struct DeviceAuth {
    /// COSE_Mac0 or COSE_Sign1 for device authentication
    let deviceMac: Data?
    let deviceSignature: Data?
}
```

### Step 3: Define Element Identifiers

Create an enum for standard mDL attributes:

```swift
/// Standard mDL element identifiers
enum MDLElementIdentifier: String, CaseIterable {
    case familyName = "family_name"
    case givenName = "given_name"
    case birthDate = "birth_date"
    case issueDate = "issue_date"
    case expiryDate = "expiry_date"
    case issuingCountry = "issuing_country"
    case documentNumber = "document_number"

    // Age attestations
    case ageOver18 = "age_over_18"
    case ageOver21 = "age_over_21"
    case ageInYears = "age_in_years"

    var displayName: String {
        switch self {
        case .familyName: return "Family Name"
        case .givenName: return "Given Name"
        case .birthDate: return "Birth Date"
        case .ageOver18: return "Age Over 18"
        case .ageOver21: return "Age Over 21"
        // ... add other cases
        }
    }
}
```

### Step 4: Create Dummy Credentials

For the workshop, we'll use dummy data. Create `Models/DummyCredentials.swift`:

```swift
import Foundation

enum DummyCredentials {
    static func createSampleMDL() -> MDoc {
        let items: [IssuerSignedItem] = [
            IssuerSignedItem(
                digestID: 0,
                random: generateRandom(),
                elementIdentifier: "family_name",
                elementValue: "SMITH"
            ),
            IssuerSignedItem(
                digestID: 1,
                random: generateRandom(),
                elementIdentifier: "given_name",
                elementValue: "JOHN"
            ),
            IssuerSignedItem(
                digestID: 2,
                random: generateRandom(),
                elementIdentifier: "age_over_21",
                elementValue: true
            ),
            // Add more attributes...
        ]

        let issuerSigned = IssuerSigned(
            nameSpaces: [mDLNamespace: items],
            issuerAuth: Data("DUMMY_AUTH".utf8)
        )

        return MDoc(
            docType: mDLDocType,
            issuerSigned: issuerSigned,
            deviceSigned: nil
        )
    }

    private static func generateRandom() -> Data {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }
}
```

### Why Random Bytes?

Each `IssuerSignedItem` includes random bytes. This is crucial for privacy:

1. **Prevents correlation**: Without random bytes, the same attribute would always hash to the same value
2. **Enables selective disclosure**: The random salt ensures each attribute can be independently verified

### Verification

At this point, you should be able to:

1. Create an MDoc instance using `DummyCredentials.createSampleMDL()`
2. Access attributes via `mdoc.issuerSigned.nameSpaces[mDLNamespace]`

## Next Steps

Continue to <doc:CBOREncodingDecoding> to implement CBOR serialization.

## See Also

- <doc:CBOREncodingDecoding>
- <doc:MSOVerification>
