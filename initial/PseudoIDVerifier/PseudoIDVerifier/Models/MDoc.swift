import Foundation

// MARK: - ISO 18013-5 mdoc Structures

/// The document type identifier for mobile driving license
nonisolated let mDLDocType = "org.iso.18013.5.1.mDL"

/// The namespace for mDL attributes
nonisolated let mDLNamespace = "org.iso.18013.5.1"

/// Mobile Document (mdoc) structure according to ISO 18013-5
nonisolated struct MDoc {
    let docType: String
    let issuerSigned: IssuerSigned
    let deviceSigned: DeviceSigned?

    init(docType: String = mDLDocType, issuerSigned: IssuerSigned, deviceSigned: DeviceSigned? = nil) {
        self.docType = docType
        self.issuerSigned = issuerSigned
        self.deviceSigned = deviceSigned
    }
}

/// Issuer-signed portion of the mdoc
nonisolated struct IssuerSigned {
    /// Map of namespace to array of signed items
    let nameSpaces: [String: [IssuerSignedItem]]

    /// COSE_Sign1 structure containing the issuer's signature
    let issuerAuth: Data
}

/// Individual signed item within a namespace
nonisolated struct IssuerSignedItem {
    /// Unique identifier for this item within the document
    let digestID: Int

    /// Random bytes for privacy protection
    let random: Data

    /// The attribute identifier (e.g., "family_name", "age_over_21")
    let elementIdentifier: String

    /// The attribute value
    let elementValue: Any
}

/// Device-signed portion of the mdoc (for device authentication)
nonisolated struct DeviceSigned {
    /// CBOR-encoded device namespaces
    let nameSpaces: Data

    /// Device authentication data
    let deviceAuth: DeviceAuth
}

/// Device authentication structure
nonisolated struct DeviceAuth {
    /// COSE_Mac0 or COSE_Sign1 for device authentication
    let deviceMac: Data?
    let deviceSignature: Data?
}

// MARK: - CBOR Convenience (delegates to CBORService)
//
// > Note: These convenience methods delegate to CBORService.shared.
// > You do NOT need to implement them separately.
// > After completing <doc:CBOREncodingDecoding>, you can use:
// >   CBORService.shared.encode(mdoc:)
// >   CBORService.shared.decodeMDoc(from:)
// > or uncomment these wrappers.

extension MDoc {
    /// Encode the mdoc to CBOR format (delegates to CBORService)
    func toCBOR() -> Data {
        CBORService.shared.encode(mdoc: self)
    }

    /// Decode an mdoc from CBOR format (delegates to CBORService)
    static func fromCBOR(_ data: Data) -> MDoc? {
        CBORService.shared.decodeMDoc(from: data)
    }
}

extension IssuerSignedItem {
    /// Encode the item to CBOR format (handled internally by CBORService)
    func toCBOR() -> Data {
        // IssuerSignedItem encoding is handled as a private method
        // inside CBORService.encodeIssuerSignedItem(_:)
        fatalError("Use CBORService.shared.encode(mdoc:) instead")
    }
}
