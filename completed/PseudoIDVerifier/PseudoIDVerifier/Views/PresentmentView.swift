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

            case .advertising, .requestReceived, .authenticating, .sending:
                AdvertisingView(viewModel: viewModel)

            case .success:
                SuccessView(viewModel: viewModel)

            case .error(let message):
                ErrorView(message: message, viewModel: viewModel)
            }
        }
        .navigationTitle("Present ID")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.isDisclosureSheetPresented) {
            DisclosureSheetView(
                viewModel: viewModel
            )
            .interactiveDismissDisabled()
        }
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

            Button(action: viewModel.refreshCredential) {
                Label("Randomize", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }

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

// MARK: - Disclosure Sheet View

private struct DisclosureSheetView: View {
    var viewModel: PresentmentViewModel

    @Dependency(\.authenticationService) var authService

    var body: some View {
        switch viewModel.state {
        case .requestReceived(let request):
            DisclosureRequestView(
                request: request,
                onApprove: { viewModel.approveDisclosure() },
                onDeny: { viewModel.denyDisclosure() }
            )
        case .authenticating:
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: authService.biometricType().systemImageName)
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Authenticating...")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        case .sending:
            VStack(spacing: 20) {
                Spacer()
                ProgressView()
                    .scaleEffect(1.5)

                Text("Sending credentials...")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        default:
            EmptyView()
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
    var state: PresentmentState = .idle {
        didSet { syncDisclosureSheet() }
    }
    var isDisclosureSheetPresented = false
    var credential: MDoc

    @ObservationIgnored @Dependency(\.transportService) var transportService
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

    private func syncDisclosureSheet() {
        switch state {
        case .requestReceived, .authenticating, .sending:
            isDisclosureSheetPresented = true
        default:
            isDisclosureSheetPresented = false
        }
    }

    init() {
        // Load dummy credential for workshop
        self.credential = DummyCredentials.createSampleMDL()
        setupCallbacks()
    }

    private func setupCallbacks() {
        // Handle request received from reader
        transportService.setOnRequestReceived { [weak self] request in
            Task { @MainActor in
                self?.pendingRequest = request
                self?.state = .requestReceived(request)
            }
        }

        // Handle disconnection
        transportService.setOnDisconnected { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                switch self.state {
                case .advertising:
                    // Reader disconnected before request was sent
                    self.state = .idle
                case .success:
                    // Reader received response and disconnected — clean up transport
                    self.transportService.stopPeripheralMode()
                default:
                    break
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
        transportService.startPeripheralMode()
    }

    func cancelPresenting() {
        transportService.stopPeripheralMode()
        state = .idle
        pendingRequest = nil
    }

    func approveDisclosure() {
        guard let request = pendingRequest else {
            state = .error("No pending request")
            return
        }

        state = .authenticating

        Task {
            do {
                _ = try await authService.authenticate(reason: "Approve sharing your ID information")
                sendResponse(for: request)
            } catch is CancellationError {
                state = .requestReceived(request)
            } catch let error as AuthError {
                if case .userCancelled = error {
                    state = .requestReceived(request)
                } else {
                    state = .error(error.localizedDescription)
                }
            } catch {
                state = .error(error.localizedDescription)
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

        // Send via BLE/MPC
        transportService.sendResponse(response)

        // Transition to success state.
        // Do NOT stop peripheral mode here — the reader will disconnect
        // after receiving the response, which tears down the session cleanly.
        // Stopping too early (e.g. after 0.5s) can destroy the MPC/BLE session
        // before the data reaches the reader, causing "Waiting for approval" to hang.
        state = .success
    }

    func denyDisclosure() {
        // Send error response
        let response = DeviceResponse(
            version: "1.0",
            documents: nil,
            documentErrors: nil,
            status: 10  // General error - user denied
        )

        transportService.sendResponse(response)
        transportService.stopPeripheralMode()

        state = .idle
        pendingRequest = nil
    }

    func refreshCredential() {
        credential = DummyCredentials.createRandomMDL()
    }

    func reset() {
        transportService.stopPeripheralMode()
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
