import SwiftUI
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

// MARK: - Authenticating View

private struct AuthenticatingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: AuthenticationService.shared.biometricType.systemImageName)
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

// ┌──────────────────────────────────────────────────────┐
// │  Presentment View Model                              │
// │  📖 See: IntegrationTesting > "Implement ViewModels" │
// └──────────────────────────────────────────────────────┘

// MARK: - Presentment View Model

@MainActor
@Observable
class PresentmentViewModel {
    var state: PresentmentState = .idle
    var credential: MDoc

    @ObservationIgnored private let transportService = BLEService.shared
    @ObservationIgnored private let authService = AuthenticationService.shared
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
        // ✏️ Add setupCallbacks() call here after implementing the method below
    }

    // MARK: - 📋 PASTE: <doc:IntegrationTesting> ViewModel Step 4 — setupCallbacks

    /// Set up BLE callbacks to handle incoming requests and disconnection.
    /// ✏️ Paste your implementation here
    private func setupCallbacks() {
        // Steps:
        // 1. transportService.onRequestReceived → store request, set state to .requestReceived
        // 2. transportService.onDisconnected →
        //    - .advertising → reset to .idle (reader disconnected before request)
        //    - .success → call stopPeripheralMode() (reader received data, clean up)

        fatalError("Not implemented — Paste code from <doc:IntegrationTesting> ViewModel Step 4")
    }

    // MARK: - 📋 PASTE: <doc:IntegrationTesting> ViewModel Step 5 — startPresenting

    func startPresenting() {
        // ✏️ Paste your implementation here
        //
        // ## iOS Technical Constraints
        //
        // The intended ISO 18013-5 flow:
        //   1. Holder CBOR-encodes DeviceEngagement and prepares it as an NDEF message
        //   2. Holder's iPhone provides DeviceEngagement as an NFC tag (HCE)
        //   3. Reader reads DeviceEngagement via NFC and extracts the BLE UUID
        //   4. BLE connection established
        //
        // On iOS, NFC tag emulation (HCE) is exclusive to Apple Wallet,
        // so this workshop uses direct BLE advertising for connection.
        //
        // ## Implementation steps
        //
        // 1. Set state to .advertising
        // 2. Set up BLE callback: transportService.onRequestReceived
        // 3. Start BLE peripheral mode: transportService.startPeripheralMode()
        // 4. On request received, set state to .requestReceived

        fatalError("Not implemented — Paste code from <doc:IntegrationTesting> ViewModel Step 5")
    }

    // MARK: - 📋 PASTE: <doc:IntegrationTesting> ViewModel Step 5 — cancelPresenting

    func cancelPresenting() {
        // ✏️ Paste your implementation here

        fatalError("Not implemented — Paste code from <doc:IntegrationTesting> ViewModel Step 5")
    }

    // MARK: - 📋 PASTE: <doc:IntegrationTesting> ViewModel Step 6 — approveDisclosure

    func approveDisclosure() {
        // ✏️ Paste your implementation here
        //
        // Steps:
        // 1. Check pendingRequest exists
        // 2. Set state to .authenticating
        // 3. Call authService.authenticateForDisclosure
        // 4. On success → call sendResponse(for:)
        // 5. On failure (userCancelled) → go back to .requestReceived
        // 6. On failure (other) → set state to .error

        fatalError("Not implemented — Paste code from <doc:IntegrationTesting> ViewModel Step 6")
    }

    // MARK: - 📋 PASTE: <doc:IntegrationTesting> ViewModel Step 6 — sendResponse

    /// Create selective disclosure response and send via BLE
    /// ✏️ Paste your implementation here
    private func sendResponse(for request: DeviceRequest) {
        // Steps:
        // 1. Set state to .sending
        // 2. Call cborService.createSelectiveResponse
        // 3. Create Document + DeviceResponse
        // 4. Send via transportService.sendResponse
        // 5. Transition to .success
        //
        // ⚠️ Do NOT call stopPeripheralMode() here — let the reader disconnect
        //    first so all BLE data is received. See onDisconnected in Step 4.

        fatalError("Not implemented — Paste code from <doc:IntegrationTesting> ViewModel Step 6")
    }

    // MARK: - 📋 PASTE: <doc:IntegrationTesting> ViewModel Step 6 — denyDisclosure

    func denyDisclosure() {
        // ✏️ Paste your implementation here
        //
        // Send error response (status: 10) and reset

        fatalError("Not implemented — Paste code from <doc:IntegrationTesting> ViewModel Step 6")
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
