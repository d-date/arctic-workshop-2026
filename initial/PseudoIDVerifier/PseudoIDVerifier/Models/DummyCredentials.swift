import Foundation
import UIKit

// MARK: - Dummy Credential Data for Workshop

/// Factory for creating dummy mdoc credentials for testing
enum DummyCredentials {
    /// Creates a sample mDL credential with dummy data
    static func createSampleMDL() -> MDoc {
        let person = samplePeople[0]
        return buildMDL(from: person)
    }

    /// Creates a new mDL credential with randomly selected identity data.
    /// Useful for workshop demos to visually confirm that different data is being sent each time.
    static func createRandomMDL() -> MDoc {
        let person = samplePeople.randomElement()!
        return buildMDL(from: person)
    }

    private struct SamplePerson {
        let givenName: String
        let familyName: String
        let birthDate: String
        let documentNumber: String
        let city: String
        let state: String
        let postalCode: String
        let age: Int
    }

    private static let samplePeople = [
        SamplePerson(givenName: "JOHN", familyName: "SMITH", birthDate: "1990-01-15",
                     documentNumber: "DL123456789", city: "San Francisco", state: "CA", postalCode: "94102", age: 35),
        SamplePerson(givenName: "EMMA", familyName: "JOHNSON", birthDate: "1985-07-22",
                     documentNumber: "DL987654321", city: "Los Angeles", state: "CA", postalCode: "90001", age: 40),
        SamplePerson(givenName: "TAKESHI", familyName: "TANAKA", birthDate: "1992-03-10",
                     documentNumber: "DL555666777", city: "San Jose", state: "CA", postalCode: "95101", age: 33),
        SamplePerson(givenName: "MARIA", familyName: "GARCIA", birthDate: "1988-11-30",
                     documentNumber: "DL111222333", city: "San Diego", state: "CA", postalCode: "92101", age: 37),
        SamplePerson(givenName: "ALEX", familyName: "CHEN", birthDate: "1995-05-18",
                     documentNumber: "DL444888999", city: "Sacramento", state: "CA", postalCode: "95814", age: 30),
    ]

    private static func buildMDL(from person: SamplePerson) -> MDoc {
        let items: [IssuerSignedItem] = [
            IssuerSignedItem(
                digestID: 0,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.familyName.rawValue,
                elementValue: person.familyName
            ),
            IssuerSignedItem(
                digestID: 1,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.givenName.rawValue,
                elementValue: person.givenName
            ),
            IssuerSignedItem(
                digestID: 2,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.birthDate.rawValue,
                elementValue: person.birthDate
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
                elementValue: person.documentNumber
            ),
            IssuerSignedItem(
                digestID: 8,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.ageOver18.rawValue,
                elementValue: person.age >= 18
            ),
            IssuerSignedItem(
                digestID: 9,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.ageOver21.rawValue,
                elementValue: person.age >= 21
            ),
            IssuerSignedItem(
                digestID: 10,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.ageInYears.rawValue,
                elementValue: person.age
            ),
            IssuerSignedItem(
                digestID: 11,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.residentCity.rawValue,
                elementValue: person.city
            ),
            IssuerSignedItem(
                digestID: 12,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.residentState.rawValue,
                elementValue: person.state
            ),
            IssuerSignedItem(
                digestID: 13,
                random: generateRandom(),
                elementIdentifier: MDLElementIdentifier.residentPostalCode.rawValue,
                elementValue: person.postalCode
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

    /// Generate a dummy portrait JPEG to simulate a real mDL photo.
    /// Renders a placeholder person icon as a valid JPEG so UIImage(data:) works.
    private static func generateDummyPortrait() -> Data {
        let size = CGSize(width: 240, height: 240)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            // Background
            UIColor.systemGray5.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            // Draw SF Symbol as placeholder face
            let config = UIImage.SymbolConfiguration(pointSize: 120, weight: .regular)
            if let symbol = UIImage(systemName: "person.crop.circle.fill", withConfiguration: config) {
                let symbolSize = symbol.size
                let origin = CGPoint(x: (size.width - symbolSize.width) / 2,
                                     y: (size.height - symbolSize.height) / 2)
                symbol.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
                    .draw(at: origin)
            }
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
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
nonisolated enum VerificationScenario: CaseIterable, Identifiable {
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
