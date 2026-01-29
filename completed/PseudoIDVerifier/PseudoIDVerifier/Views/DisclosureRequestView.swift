import SwiftUI

// MARK: - Disclosure Request View

/// View displayed when a verifier requests specific attributes
/// Shows which information is being requested and allows user to approve/deny
struct DisclosureRequestView: View {
    let request: DeviceRequest
    let credential: MDoc
    let onApprove: () -> Void
    let onDeny: () -> Void

    @State private var showingAllAttributes = false

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
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            .padding(.bottom, 24)

            // Requested Attributes
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(requestedAttributes, id: \.identifier) { attr in
                        RequestedAttributeRow(
                            identifier: attr.identifier,
                            value: attr.value,
                            intentToRetain: attr.intentToRetain
                        )
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            // Warning about data sharing
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.orange)
                Text("Only the above information will be shared")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)

            // Action Buttons
            VStack(spacing: 12) {
                Button(action: onApprove) {
                    HStack {
                        Image(systemName: AuthenticationService.shared.biometricType.systemImageName)
                        Text("Approve with \(AuthenticationService.shared.biometricType.displayName)")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button(action: onDeny) {
                    Text("Deny")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Computed Properties

    private var requestedAttributes: [RequestedAttribute] {
        // Extract requested attributes from request and match with credential
        guard let docRequest = request.docRequests.first else {
            return []
        }

        var attributes: [RequestedAttribute] = []

        for (namespace, elements) in docRequest.itemsRequest.nameSpaces {
            guard let items = credential.issuerSigned.nameSpaces[namespace] else {
                continue
            }

            for (elementId, intentToRetain) in elements {
                if let item = items.first(where: { $0.elementIdentifier == elementId }) {
                    attributes.append(RequestedAttribute(
                        identifier: elementId,
                        value: item.elementValue,
                        intentToRetain: intentToRetain
                    ))
                }
            }
        }

        return attributes
    }
}

// MARK: - Requested Attribute Model

struct RequestedAttribute {
    let identifier: String
    let value: Any
    let intentToRetain: Bool
}

// MARK: - Requested Attribute Row

struct RequestedAttributeRow: View {
    let identifier: String
    let value: Any
    let intentToRetain: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(displayValue)
                    .font(.headline)
            }

            Spacer()

            // Value indicator
            if isBooleanValue {
                Image(systemName: boolValue ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .foregroundStyle(boolValue ? .green : .red)
                    .font(.title2)
            }

            // Retention indicator
            if intentToRetain {
                Image(systemName: "doc.badge.clock")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var displayName: String {
        MDLElementIdentifier(rawValue: identifier)?.displayName ?? identifier
    }

    private var displayValue: String {
        if let boolVal = value as? Bool {
            return boolVal ? "Yes" : "No"
        } else if let stringVal = value as? String {
            return stringVal
        } else if let intVal = value as? Int {
            return String(intVal)
        }
        return String(describing: value)
    }

    private var isBooleanValue: Bool {
        value is Bool
    }

    private var boolValue: Bool {
        value as? Bool ?? false
    }
}

// MARK: - Preview

#Preview {
    let request = VerificationScenario.ageVerification21.createRequest()
    let credential = DummyCredentials.createSampleMDL()

    return DisclosureRequestView(
        request: request,
        credential: credential,
        onApprove: { print("Approved") },
        onDeny: { print("Denied") }
    )
}
