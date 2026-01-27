# Selective Disclosure

Implement attribute selection and user consent for sharing data.

## Overview

Selective disclosure is a core privacy feature of ISO 18013-5. It allows holders to share only the specific attributes requested by a verifier, rather than their entire credential.

### How It Works

1. **Verifier requests specific attributes**: e.g., "age_over_21" and "portrait"
2. **Holder sees the request**: UI shows exactly what's being requested
3. **Holder approves with biometrics**: Face ID/Touch ID confirms consent
4. **Only requested attributes are sent**: Other data stays private

### Step 1: Define Request/Response Structures

Create `Models/DeviceRequest.swift`:

```swift
import Foundation

/// Request from reader to holder
struct DeviceRequest {
    let version: String
    let docRequests: [DocRequest]

    init(version: String = "1.0", docRequests: [DocRequest]) {
        self.version = version
        self.docRequests = docRequests
    }
}

/// Request for a specific document type
struct DocRequest {
    let itemsRequest: ItemsRequest
    let readerAuth: Data?  // Optional COSE_Sign1
}

/// Specification of requested items
struct ItemsRequest {
    let docType: String
    let nameSpaces: [String: [String: Bool]]  // namespace → element → intentToRetain
}

/// Response from holder to reader
struct DeviceResponse {
    let version: String
    let documents: [Document]?
    let documentErrors: [DocumentError]?
    let status: Int  // 0 = success
}

struct Document {
    let docType: String
    let issuerSigned: IssuerSigned
    let deviceSigned: DeviceSigned
    let errors: [String: [String: Int]]?
}
```

### Step 2: Create Verification Scenarios

Add predefined scenarios:

```swift
enum VerificationScenario: CaseIterable, Identifiable {
    case ageVerification21
    case ageVerification18
    case fullIdentity

    var id: Self { self }

    var displayName: String {
        switch self {
        case .ageVerification21: return "Age 21+ Verification"
        case .ageVerification18: return "Age 18+ Verification"
        case .fullIdentity: return "Full Identity Check"
        }
    }

    var requestedAttributes: [String: Bool] {
        switch self {
        case .ageVerification21:
            return [
                "age_over_21": false,  // false = do not retain
                "portrait": false
            ]
        case .ageVerification18:
            return [
                "age_over_18": false,
                "portrait": false
            ]
        case .fullIdentity:
            return [
                "family_name": false,
                "given_name": false,
                "birth_date": false,
                "document_number": false
            ]
        }
    }

    func createRequest() -> DeviceRequest {
        let itemsRequest = ItemsRequest(
            docType: mDLDocType,
            nameSpaces: [mDLNamespace: requestedAttributes]
        )

        return DeviceRequest(docRequests: [
            DocRequest(itemsRequest: itemsRequest, readerAuth: nil)
        ])
    }
}
```

### Step 3: Implement Selective Filtering

Add to `CBORService`:

```swift
extension CBORService {
    /// Create a response containing only the requested attributes
    func createSelectiveResponse(from mdoc: MDoc,
                                  for request: DeviceRequest) -> MDoc {
        guard let docRequest = request.docRequests.first else {
            return mdoc
        }

        // Get requested element identifiers
        var requestedElements = Set<String>()
        for (_, elements) in docRequest.itemsRequest.nameSpaces {
            for (elementId, _) in elements {
                requestedElements.insert(elementId)
            }
        }

        // Filter nameSpaces to only include requested items
        var filteredNameSpaces: [String: [IssuerSignedItem]] = [:]

        for (namespace, items) in mdoc.issuerSigned.nameSpaces {
            let filteredItems = items.filter {
                requestedElements.contains($0.elementIdentifier)
            }
            if !filteredItems.isEmpty {
                filteredNameSpaces[namespace] = filteredItems
            }
        }

        let filteredIssuerSigned = IssuerSigned(
            nameSpaces: filteredNameSpaces,
            issuerAuth: mdoc.issuerSigned.issuerAuth
        )

        return MDoc(
            docType: mdoc.docType,
            issuerSigned: filteredIssuerSigned,
            deviceSigned: nil
        )
    }
}
```

### Step 4: Create Disclosure Request UI

Create `Views/DisclosureRequestView.swift`:

```swift
import SwiftUI

struct DisclosureRequestView: View {
    let request: DeviceRequest
    let credential: MDoc
    let onApprove: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)

                Text("Information Request")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("A verifier is requesting the following information")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            // Requested attributes list
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(requestedAttributes, id: \.identifier) { attr in
                        RequestedAttributeRow(
                            identifier: attr.identifier,
                            value: attr.value
                        )
                    }
                }
                .padding()
            }

            // Warning
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.orange)
                Text("Only the above information will be shared")
                    .font(.caption)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)

            // Action buttons
            VStack(spacing: 12) {
                Button(action: onApprove) {
                    HStack {
                        Image(systemName: "faceid")
                        Text("Approve with Face ID")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button("Deny", action: onDeny)
                    .foregroundStyle(.red)
            }
            .padding()
        }
    }

    private var requestedAttributes: [RequestedAttribute] {
        // Extract from request and match with credential
        // ... implementation
    }
}
```

### Step 5: Privacy Considerations

When implementing selective disclosure:

1. **Minimum data principle**: Only request what you need
2. **Intent to retain**: The boolean indicates if the verifier will store the data
3. **User awareness**: Always show users exactly what will be shared
4. **Audit trail**: Consider logging disclosures for the user

### Example Flow

```
Reader                                  Holder
   │                                      │
   │ Request: age_over_21, portrait       │
   │─────────────────────────────────────►│
   │                                      │
   │                                      │ Show: "Verifier requests:
   │                                      │        - Age Over 21
   │                                      │        - Portrait"
   │                                      │
   │                                      │ [Approve with Face ID]
   │                                      │
   │◄─────────────────────────────────────│
   │ Response: age_over_21=true,          │
   │           portrait=<bytes>           │
   │                                      │
   │ (Does NOT receive: name, address,    │
   │  birth date, document number, etc.)  │
```

## Next Steps

Continue to <doc:BiometricAuthentication> to implement Face ID approval.
