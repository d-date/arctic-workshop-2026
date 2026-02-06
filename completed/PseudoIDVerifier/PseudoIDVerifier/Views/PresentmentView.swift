import SwiftUI
import Dependencies
import Observation

// MARK: - Presentment View (Holder Mode)

/// Main view for the Presentment/Holder mode
/// This is where the holder presents their credential
struct PresentmentView: View {
    @State private var viewModel = PresentmentViewModel()

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            switch viewModel.state {
            case .idle:
                IdleView(viewModel: viewModel)

            case .advertising:
                AdvertisingView(viewModel: viewModel)

            case .requestReceived(let request):
                DisclosureRequestView(
                    request: request,
                    credential: viewModel.credential,
                    onApprove: { viewModel.approveDisclosure() },
                    onDeny: { viewModel.denyDisclosure() }
                )

            case .authenticating:
                AuthenticatingView()

            case .sending:
                SendingView()

            case .success:
                SuccessView(viewModel: viewModel)

            case .error(let message):
                ErrorView(message: message, viewModel: viewModel)
            }
        }
        .navigationTitle("Present ID")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Idle State View

private struct IdleView: View {
    var viewModel: PresentmentViewModel

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Credential Card Preview
            CredentialCard(credential: viewModel.credential)
                .padding(.horizontal)

            Spacer()

            // Instructions
            VStack(spacing: 8) {
                Text("Ready to Present")
                    .font(.headline)

                Text("Tap the button below and hold your phone near the reader")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Present Button
            Button(action: viewModel.startPresenting) {
                Label("Present ID", systemImage: "wallet.pass")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Credential Card

private struct CredentialCard: View {
    let credential: MDoc

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "car.fill")
                    .font(.title2)
                Text("Driver's License")
                    .font(.headline)
                Spacer()
                Text("SAMPLE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }

            Divider()

            // Basic Info
            if let namespace = credential.issuerSigned.nameSpaces[mDLNamespace] {
                VStack(alignment: .leading, spacing: 8) {
                    if let name = findAttribute(namespace, .givenName),
                       let family = findAttribute(namespace, .familyName) {
                        Text("\(stringValue(name)) \(stringValue(family))")
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    if let docNum = findAttribute(namespace, .documentNumber) {
                        HStack {
                            Text("DL#")
                                .foregroundStyle(.secondary)
                            Text(stringValue(docNum))
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                    }

                    if let state = findAttribute(namespace, .residentState),
                       let country = findAttribute(namespace, .issuingCountry) {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.secondary)
                            Text("\(stringValue(state)), \(stringValue(country))")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.green.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }

    private func findAttribute(_ items: [IssuerSignedItem], _ identifier: MDLElementIdentifier) -> IssuerSignedItem? {
        items.first { $0.elementIdentifier == identifier.rawValue }
    }

    private func stringValue(_ item: IssuerSignedItem) -> String {
        if let str = item.elementValue as? String {
            return str
        }
        return String(describing: item.elementValue)
    }
}

// MARK: - Advertising View

private struct AdvertisingView: View {
    var viewModel: PresentmentViewModel
    @State private var animationPhase = 0.0

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Animated indicator
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(Color.green.opacity(0.3 - Double(index) * 0.1), lineWidth: 2)
                        .frame(width: 200 + CGFloat(index) * 40,
                               height: 200 + CGFloat(index) * 40)
                        .scaleEffect(1 + CGFloat(animationPhase) * 0.1)
                        .opacity(1 - animationPhase * 0.5)
                }

                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    animationPhase = 1.0
                }
            }

            VStack(spacing: 12) {
                Text("Ready to Present")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Hold your phone near the reader")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Cancel") {
                viewModel.cancelPresenting()
            }
            .font(.headline)
            .foregroundStyle(.red)
            .padding(.bottom, 40)
        }
        .padding()
    }
}

// MARK: - Authenticating View

private struct AuthenticatingView: View {
    @Dependency(\.authenticationService) var authService

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: authService.biometricType().systemImageName)
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Authenticating...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Sending View

private struct SendingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Sending credentials...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Success View

private struct SuccessView: View {
    var viewModel: PresentmentViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("Shared Successfully")
                .font(.title)
                .fontWeight(.bold)

            Text("Your information has been securely shared with the verifier")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button("Done") {
                viewModel.reset()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .padding(.top, 60)
    }
}

// MARK: - Error View

private struct ErrorView: View {
    let message: String
    var viewModel: PresentmentViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            Text("Sharing Failed")
                .font(.title)
                .fontWeight(.bold)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button("Try Again") {
                viewModel.reset()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Presentment View Model

@MainActor
@Observable
class PresentmentViewModel {
    var state: PresentmentState = .idle
    var credential: MDoc

    @ObservationIgnored @Dependency(\.bleService) var bleService
    @ObservationIgnored @Dependency(\.authenticationService) var authService
    @ObservationIgnored private let cborService = CBORService.shared

    @ObservationIgnored private var pendingRequest: DeviceRequest?

    enum PresentmentState {
        case idle
        case advertising
        case requestReceived(DeviceRequest)
        case authenticating
        case sending
        case success
        case error(String)
    }

    init() {
        // Load dummy credential for workshop
        self.credential = DummyCredentials.createSampleMDL()
        setupCallbacks()
    }

    private func setupCallbacks() {
        // Handle request received from reader
        bleService.setOnRequestReceived { [weak self] request in
            Task { @MainActor in
                self?.pendingRequest = request
                self?.state = .requestReceived(request)
            }
        }

        // Handle disconnection
        bleService.setOnDisconnected { [weak self] in
            Task { @MainActor in
                // Only reset if we're not already in success/error state
                if case .advertising = self?.state {
                    self?.state = .idle
                }
            }
        }
    }

    func startPresenting() {
        // The intended ISO 18013-5 flow:
        //   1. Holder CBOR-encodes DeviceEngagement and prepares it as an NDEF message
        //   2. Holder's iPhone provides DeviceEngagement as an NFC tag (HCE)
        //   3. Reader reads DeviceEngagement via NFC and extracts the BLE UUID
        //   4. BLE connection established
        //
        // iOS technical constraint:
        //   NFC tag emulation (HCE) is exclusive to Apple Wallet.
        //   Third-party apps cannot make an iPhone act as an NDEF tag.
        //   Apple's ID Verifier API (ProximityReader) works around this constraint,
        //   but requires a dedicated entitlement.
        //
        // This workshop uses direct BLE advertising for connection.
        state = .advertising
        bleService.startPeripheralMode()
    }

    func cancelPresenting() {
        bleService.stopPeripheralMode()
        state = .idle
        pendingRequest = nil
    }

    func approveDisclosure() {
        guard let request = pendingRequest else {
            state = .error("No pending request")
            return
        }

        state = .authenticating

        // Trigger biometric authentication
        authService.authenticateForDisclosure(
            "Approve sharing your ID information"
        ) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    self?.sendResponse(for: request)
                case .failure(let error):
                    if case .userCancelled = error {
                        // User cancelled - go back to request view
                        self?.state = .requestReceived(request)
                    } else {
                        self?.state = .error(error.localizedDescription)
                    }
                }
            }
        }
    }

    private func sendResponse(for request: DeviceRequest) {
        state = .sending

        // Create selective disclosure response
        let selectiveMDoc = cborService.createSelectiveResponse(from: credential, for: request)

        // Create the document for response
        let deviceAuth = DeviceAuth(
            deviceMac: nil,
            deviceSignature: CryptoService.shared.devicePublicKeyData
        )

        let deviceSigned = DeviceSigned(
            nameSpaces: Data(),
            deviceAuth: deviceAuth
        )

        let document = Document(
            docType: selectiveMDoc.docType,
            issuerSigned: selectiveMDoc.issuerSigned,
            deviceSigned: deviceSigned,
            errors: nil
        )

        let response = DeviceResponse(
            version: "1.0",
            documents: [document],
            documentErrors: nil,
            status: 0  // Success
        )

        // Send via BLE
        bleService.sendResponse(response)

        // Transition to success after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.state = .success
            self?.bleService.stopPeripheralMode()
        }
    }

    func denyDisclosure() {
        // Send error response
        let response = DeviceResponse(
            version: "1.0",
            documents: nil,
            documentErrors: nil,
            status: 10  // General error - user denied
        )

        bleService.sendResponse(response)
        bleService.stopPeripheralMode()

        state = .idle
        pendingRequest = nil
    }

    func reset() {
        bleService.stopPeripheralMode()
        state = .idle
        pendingRequest = nil
        authService.resetAuthentication()
    }
}

#Preview {
    NavigationStack {
        PresentmentView()
    }
}
