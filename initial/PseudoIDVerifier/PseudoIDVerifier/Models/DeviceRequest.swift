import Foundation

// MARK: - Device Engagement and Request Structures (ISO 18013-5)

/// Device engagement structure for initiating a session
struct DeviceEngagement {
    /// Protocol version
    let version: String

    /// Security information for the session
    let security: Security

    /// Device retrieval methods (BLE, NFC, WiFi Aware)
    let deviceRetrievalMethods: [DeviceRetrievalMethod]

    /// Optional server retrieval methods
    let serverRetrievalMethods: [ServerRetrievalMethod]?

    init(version: String = "1.0", security: Security, deviceRetrievalMethods: [DeviceRetrievalMethod]) {
        self.version = version
        self.security = security
        self.deviceRetrievalMethods = deviceRetrievalMethods
        self.serverRetrievalMethods = nil
    }
}

/// Security structure containing session establishment info
struct Security {
    /// Cipher suite identifier
    let cipherSuiteIdentifier: Int

    /// Device engagement public key (ephemeral)
    let deviceEngagementKey: Data
}

/// Device retrieval method
struct DeviceRetrievalMethod {
    /// Method type: 1 = NFC, 2 = BLE, 3 = WiFi Aware
    let type: Int

    /// Version of the retrieval method
    let version: Int

    /// Method-specific options
    let options: RetrievalOptions
}

/// BLE-specific retrieval options
struct RetrievalOptions {
    /// Whether the mdoc acts as BLE peripheral
    let peripheralServerMode: Bool?

    /// Whether the mdoc acts as BLE central
    let centralClientMode: Bool?

    /// Peripheral server UUID
    let peripheralServerUUID: String?

    /// Central client UUID
    let centralClientUUID: String?

    /// BLE device address (optional)
    let bleDeviceAddress: Data?
}

/// Server retrieval method (not used in this workshop)
struct ServerRetrievalMethod {
    let webAPI: String?
}

// MARK: - Request Structures

/// Request from reader to holder
struct DeviceRequest {
    /// Protocol version
    let version: String

    /// Array of document requests
    let docRequests: [DocRequest]

    init(version: String = "1.0", docRequests: [DocRequest]) {
        self.version = version
        self.docRequests = docRequests
    }
}

/// Request for a specific document type
struct DocRequest {
    /// The requested items
    let itemsRequest: ItemsRequest

    /// Optional reader authentication (COSE_Sign1)
    let readerAuth: Data?

    init(itemsRequest: ItemsRequest, readerAuth: Data? = nil) {
        self.itemsRequest = itemsRequest
        self.readerAuth = readerAuth
    }
}

/// Specification of requested items
struct ItemsRequest {
    /// Document type being requested
    let docType: String

    /// Map of namespace -> element identifier -> intent to retain
    let nameSpaces: [String: [String: Bool]]

    init(docType: String = mDLDocType, nameSpaces: [String: [String: Bool]]) {
        self.docType = docType
        self.nameSpaces = nameSpaces
    }
}

// MARK: - Response Structures

/// Response from holder to reader
struct DeviceResponse {
    /// Protocol version
    let version: String

    /// Array of documents
    let documents: [Document]?

    /// Array of document errors (if any)
    let documentErrors: [DocumentError]?

    /// Status code
    let status: Int
}

/// A document in the response
struct Document {
    /// Document type
    let docType: String

    /// Issuer-signed data
    let issuerSigned: IssuerSigned

    /// Device-signed data
    let deviceSigned: DeviceSigned

    /// Errors for specific elements (if any)
    let errors: [String: [String: Int]]?
}

/// Error information for a document
struct DocumentError {
    /// Document type
    let docType: String

    /// Error code
    let errorCode: Int
}

// MARK: - Common Attribute Identifiers (ISO 18013-5)

/// Standard mDL element identifiers
enum MDLElementIdentifier: String, CaseIterable {
    case familyName = "family_name"
    case givenName = "given_name"
    case birthDate = "birth_date"
    case issueDate = "issue_date"
    case expiryDate = "expiry_date"
    case issuingCountry = "issuing_country"
    case issuingAuthority = "issuing_authority"
    case documentNumber = "document_number"
    case portrait = "portrait"
    case drivingPrivileges = "driving_privileges"
    case unDistinguishingSign = "un_distinguishing_sign"

    // Age attestations
    case ageOver18 = "age_over_18"
    case ageOver21 = "age_over_21"
    case ageBirthYear = "age_birth_year"
    case ageInYears = "age_in_years"

    // Address (optional)
    case residentAddress = "resident_address"
    case residentCity = "resident_city"
    case residentState = "resident_state"
    case residentPostalCode = "resident_postal_code"
    case residentCountry = "resident_country"

    var displayName: String {
        switch self {
        case .familyName: return "Family Name"
        case .givenName: return "Given Name"
        case .birthDate: return "Birth Date"
        case .issueDate: return "Issue Date"
        case .expiryDate: return "Expiry Date"
        case .issuingCountry: return "Issuing Country"
        case .issuingAuthority: return "Issuing Authority"
        case .documentNumber: return "Document Number"
        case .portrait: return "Portrait"
        case .drivingPrivileges: return "Driving Privileges"
        case .unDistinguishingSign: return "UN Distinguishing Sign"
        case .ageOver18: return "Age Over 18"
        case .ageOver21: return "Age Over 21"
        case .ageBirthYear: return "Birth Year"
        case .ageInYears: return "Age in Years"
        case .residentAddress: return "Address"
        case .residentCity: return "City"
        case .residentState: return "State"
        case .residentPostalCode: return "Postal Code"
        case .residentCountry: return "Country"
        }
    }
}

// MARK: - CBOR Convenience (delegates to CBORService)
//
// > Note: These convenience methods delegate to CBORService.shared.
// > After completing <doc:CBOREncodingDecoding>, you can use:
// >   CBORService.shared.encode(request:)
// >   CBORService.shared.decodeRequest(from:)
// > or uncomment these wrappers.

extension DeviceRequest {
    /// Encode the request to CBOR format (delegates to CBORService)
    func toCBOR() -> Data {
        CBORService.shared.encode(request: self)
    }

    /// Decode a request from CBOR format (delegates to CBORService)
    static func fromCBOR(_ data: Data) -> DeviceRequest? {
        CBORService.shared.decodeRequest(from: data)
    }
}

extension DeviceResponse {
    /// Encode the response to CBOR format (delegates to CBORService)
    func toCBOR() -> Data {
        CBORService.shared.encode(response: self)
    }

    /// Decode a response from CBOR format (delegates to CBORService)
    static func fromCBOR(_ data: Data) -> DeviceResponse? {
        CBORService.shared.decodeResponse(from: data)
    }
}
