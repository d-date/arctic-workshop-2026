import SwiftUI
import Dependencies

// MARK: - Disclosure Request View

/// View displayed when a verifier requests specific attributes
/// Shows which information is being requested and allows user to approve/deny
struct DisclosureRequestView: View {
    let request: DeviceRequest
    let onApprove: () -> Void
    let onDeny: () -> Void

    @Dependency(\.authenticationService) var authService

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

            // Requested Attributes (names only)
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(requestedElementNames, id: \.self) { name in
                        RequestedAttributeRow(name: name)
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
                        Image(systemName: authService.biometricType().systemImageName)
                        Text("Approve with \(authService.biometricType().displayName)")
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

    private var requestedElementNames: [String] {
        guard let docRequest = request.docRequests.first else {
            return []
        }

        return docRequest.itemsRequest.nameSpaces.flatMap { _, elements in
            elements.map { elementId, _ in
                MDLElementIdentifier(rawValue: elementId)?.displayName ?? elementId
            }
        }
    }
}

// MARK: - Requested Attribute Row

struct RequestedAttributeRow: View {
    let name: String

    var body: some View {
        HStack {
            Text(name)
                .font(.headline)
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview {
    let request = VerificationScenario.ageVerification21.createRequest()

    return DisclosureRequestView(
        request: request,
        onApprove: { print("Approved") },
        onDeny: { print("Denied") }
    )
}
