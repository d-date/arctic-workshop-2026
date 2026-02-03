import Foundation
import SwiftCBOR

// MARK: - ISO 18013-5 mdoc Structures

/// The document type identifier for mobile driving license
let mDLDocType = "org.iso.18013.5.1.mDL"

/// The namespace for mDL attributes
let mDLNamespace = "org.iso.18013.5.1"

/// Mobile Document (mdoc) structure according to ISO 18013-5
struct MDoc {
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

/// Device-signed portion of the mdoc (for device authentication)
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

// MARK: - CBOR Encoding/Decoding

extension MDoc {
    /// Encode the mdoc to CBOR format
    /// - Returns: CBOR-encoded data
    func toCBOR() -> Data {
        // Delegate to CBORService for encoding
        return CBORService.shared.encode(mdoc: self)
    }

    /// Decode an mdoc from CBOR format
    /// - Parameter data: CBOR-encoded data
    /// - Returns: Decoded MDoc
    static func fromCBOR(_ data: Data) -> MDoc? {
        // Delegate to CBORService for decoding
        return CBORService.shared.decodeMDoc(from: data)
    }
}

extension IssuerSignedItem {
    /// Encode the item to CBOR format (tagged as per ISO 18013-5)
    func toCBOR() -> Data {
        var map: [CBOR: CBOR] = [:]

        map[.utf8String("digestID")] = .unsignedInt(UInt64(digestID))
        map[.utf8String("random")] = .byteString(Array(random))
        map[.utf8String("elementIdentifier")] = .utf8String(elementIdentifier)
        map[.utf8String("elementValue")] = encodeToCBOR(elementValue)

        return Data(CBOR.map(map).encode())
    }

    private func encodeToCBOR(_ value: Any) -> CBOR {
        switch value {
        case let boolVal as Bool:
            return .boolean(boolVal)
        case let intVal as Int:
            if intVal >= 0 {
                return .unsignedInt(UInt64(intVal))
            } else {
                return .negativeInt(UInt64(-intVal - 1))
            }
        case let stringVal as String:
            return .utf8String(stringVal)
        case let dataVal as Data:
            return .byteString(Array(dataVal))
        default:
            return .utf8String(String(describing: value))
        }
    }
}
