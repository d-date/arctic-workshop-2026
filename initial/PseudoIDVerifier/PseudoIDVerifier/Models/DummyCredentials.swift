import Foundation

// MARK: - Dummy Credential Data for Workshop

/// Factory for creating dummy mdoc credentials for testing
enum DummyCredentials {
    /// Creates a sample mDL credential with dummy data
    static func createSampleMDL() -> MDoc {
        let items: [IssuerSignedItem] = [
            IssuerSignedItem(
                digestID: 0,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.familyName.rawValue,
                elementValue: "SMITH"
            ),
            IssuerSignedItem(
                digestID: 1,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.givenName.rawValue,
                elementValue: "JOHN"
            ),
            IssuerSignedItem(
                digestID: 2,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.birthDate.rawValue,
                elementValue: "1990-01-15" // Full date tag 1004 in real impl
            ),
            IssuerSignedItem(
                digestID: 3,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.issueDate.rawValue,
                elementValue: "2023-06-01"
            ),
            IssuerSignedItem(
                digestID: 4,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.expiryDate.rawValue,
                elementValue: "2028-06-01"
            ),
            IssuerSignedItem(
                digestID: 5,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.issuingCountry.rawValue,
                elementValue: "US"
            ),
            IssuerSignedItem(
                digestID: 6,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.issuingAuthority.rawValue,
                elementValue: "State of California"
            ),
            IssuerSignedItem(
                digestID: 7,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.documentNumber.rawValue,
                elementValue: "DL123456789"
            ),
            IssuerSignedItem(
                digestID: 8,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.ageOver18.rawValue,
                elementValue: true
            ),
            IssuerSignedItem(
                digestID: 9,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.ageOver21.rawValue,
                elementValue: true
            ),
            IssuerSignedItem(
                digestID: 10,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.ageInYears.rawValue,
                elementValue: 35
            ),
            IssuerSignedItem(
                digestID: 11,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.residentCity.rawValue,
                elementValue: "San Francisco"
            ),
            IssuerSignedItem(
                digestID: 12,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.residentState.rawValue,
                elementValue: "CA"
            ),
            IssuerSignedItem(
                digestID: 13,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.residentPostalCode.rawValue,
                elementValue: "94102"
            ),
            IssuerSignedItem(
                digestID: 14,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.residentCountry.rawValue,
                elementValue: "US"
            ),
            IssuerSignedItem(
                digestID: 15,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.portrait.rawValue,
                elementValue: generateDummyPortrait()
            )
        ]

        let issuerSigned = IssuerSigned(
            nameSpaces: [mDLNamespace: items],
            issuerAuth: generateDummyIssuerAuth()
        )

        return MDoc(docType: mDLDocType, issuerSigned: issuerSigned, deviceSigned: nil)
    }

    /// Generate random bytes for privacy protection
    private static func generateRandom() -> Data {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    /// Generate a dummy portrait JPEG (~32 KB) to simulate a real mDL photo.
    /// In a real implementation this would be the holder's JPEG-encoded face photo.
    private static func generateDummyPortrait() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32_768) // 32 KB
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    /// Generate a dummy issuer auth (in real implementation, this would be a COSE_Sign1)
    private static func generateDummyIssuerAuth() -> Data {
        // This is a placeholder - in a real implementation, this would be
        // a proper COSE_Sign1 structure signed by the issuing authority
        return Data("DUMMY_ISSUER_AUTH".utf8)
    }
}

// MARK: - Predefined Request Scenarios

/// Common verification scenarios for the workshop
enum VerificationScenario: CaseIterable, Identifiable {
    case ageVerification21
    case ageVerification18
    case fullIdentity
    case minimumDriving

    var id: Self { self }

    var displayName: String {
        switch self {
        case .ageVerification21: return "Age 21+ Verification"
        case .ageVerification18: return "Age 18+ Verification"
        case .fullIdentity: return "Full Identity Check"
        case .minimumDriving: return "Driving Privilege Check"
        }
    }

    var description: String {
        switch self {
        case .ageVerification21: return "Verify the holder is over 21 (e.g., alcohol purchase)"
        case .ageVerification18: return "Verify the holder is over 18 (e.g., tobacco purchase)"
        case .fullIdentity: return "Full identity verification with name and address"
        case .minimumDriving: return "Verify driving privileges only"
        }
    }

    /// The attributes requested for this scenario
    var requestedAttributes: [String: Bool] {
        switch self {
        case .ageVerification21:
            return [
                MDLElementIdentifier.ageOver21.rawValue: false,  // false = do not retain
                MDLElementIdentifier.portrait.rawValue: false
            ]
        case .ageVerification18:
            return [
                MDLElementIdentifier.ageOver18.rawValue: false,
                MDLElementIdentifier.portrait.rawValue: false
            ]
        case .fullIdentity:
            return [
                MDLElementIdentifier.familyName.rawValue: false,
                MDLElementIdentifier.givenName.rawValue: false,
                MDLElementIdentifier.birthDate.rawValue: false,
                MDLElementIdentifier.portrait.rawValue: false,
                MDLElementIdentifier.documentNumber.rawValue: false,
                MDLElementIdentifier.issuingCountry.rawValue: false
            ]
        case .minimumDriving:
            return [
                MDLElementIdentifier.drivingPrivileges.rawValue: false,
                MDLElementIdentifier.expiryDate.rawValue: false,
                MDLElementIdentifier.portrait.rawValue: false
            ]
        }
    }

    /// Create a DeviceRequest for this scenario
    func createRequest() -> DeviceRequest {
        let itemsRequest = ItemsRequest(
            docType: mDLDocType,
            nameSpaces: [mDLNamespace: requestedAttributes]
        )

        let docRequest = DocRequest(itemsRequest: itemsRequest)

        return DeviceRequest(docRequests: [docRequest])
    }
}
