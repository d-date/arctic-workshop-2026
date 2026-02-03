import SwiftUI

// MARK: - Presentment View (Holder Mode)

/// Main view for the Presentment/Holder mode
/// This is where the holder presents their credential
struct PresentmentView: View {
    @StateObject private var viewModel = PresentmentViewModel()

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
    @ObservedObject var viewModel: PresentmentViewModel

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
    @ObservedObject var viewModel: PresentmentViewModel
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
    @ObservedObject var viewModel: PresentmentViewModel

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
    @ObservedObject var viewModel: PresentmentViewModel

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
class PresentmentViewModel: ObservableObject {
    @Published var state: PresentmentState = .idle
    @Published var credential: MDoc

    private let bleService = BLEService.shared
    private let authService = AuthenticationService.shared
    private let cborService = CBORService.shared

    private var pendingRequest: DeviceRequest?

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
    }

    func startPresenting() {
        // TODO: Implement presentment flow
        //
        // ## iOS の技術的制約
        //
        // ISO 18013-5 の本来のフロー:
        //   1. Holder が DeviceEngagement を CBOR エンコードし NDEF メッセージとして準備
        //   2. Holder の iPhone が NFC タグとして DeviceEngagement を提供 (HCE)
        //   3. Reader が NFC で DeviceEngagement を読み取り、BLE UUID を抽出
        //   4. BLE 接続確立
        //
        // iOS では NFC タグエミュレーション (HCE) が Apple Wallet 専用のため、
        // 本ワークショップでは BLE advertising で直接接続する。
        //
        // ## 実装手順
        //
        // 1. Set state to .advertising
        // 2. Set up BLE callback: bleService.onRequestReceived
        // 3. Start BLE peripheral mode: bleService.startPeripheralMode()
        // 4. On request received, set state to .requestReceived

        fatalError("Not implemented - Complete this in Chapter 7")
    }

    func cancelPresenting() {
        // TODO: Stop BLE and reset state

        fatalError("Not implemented - Complete this in Chapter 7")
    }

    func approveDisclosure() {
        // TODO: Implement disclosure approval
        //
        // Steps:
        // 1. Set state to .authenticating
        // 2. Trigger biometric authentication
        // 3. On success, set state to .sending
        // 4. Create selective response from credential
        // 5. Send response via BLE
        // 6. Set state to .success

        fatalError("Not implemented - Complete this in Chapter 7")
    }

    func denyDisclosure() {
        // TODO: Handle denial
        // Send error response and reset

        fatalError("Not implemented - Complete this in Chapter 7")
    }

    func reset() {
        state = .idle
        pendingRequest = nil
    }
}

#Preview {
    NavigationStack {
        PresentmentView()
    }
}
