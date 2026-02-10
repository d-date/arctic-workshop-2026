import SwiftUI
import UIKit
@preconcurrency import Dependencies
import Observation

// MARK: - Reader View (Verifier Mode)

/// Main view for the Reader/Verifier mode
/// This is where the verifier initiates ID verification requests
struct ReaderView: View {
    @State private var viewModel = ReaderViewModel()

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            switch viewModel.state {
            case .idle:
                IdleView(viewModel: viewModel)

            case .scanning:
                ScanningView(viewModel: viewModel)

            case .connecting:
                ConnectingView()

            case .waitingForResponse:
                WaitingView()

            case .success(let attributes):
                SuccessView(attributes: attributes, viewModel: viewModel)

            case .error(let message):
                ErrorView(message: message, viewModel: viewModel)
            }
        }
        .navigationTitle("ID Reader")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Idle State View

private struct IdleView: View {
    var viewModel: ReaderViewModel

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Scenario Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Verification Type")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                ForEach(VerificationScenario.allCases) { scenario in
                    ScenarioButton(
                        scenario: scenario,
                        isSelected: viewModel.selectedScenario == scenario,
                        action: { viewModel.selectedScenario = scenario }
                    )
                }
            }
            .padding(.horizontal)

            Spacer()

            // Start Button
            Button(action: viewModel.startReading) {
                Label("Start Reading", systemImage: "wave.3.right")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Scenario Button

private struct ScenarioButton: View {
    let scenario: VerificationScenario
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(scenario.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(scenario.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title2)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scanning View (Tap to Pay style)

private struct ScanningView: View {
    var viewModel: ReaderViewModel
    @State private var animationPhase = 0.0

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Animated scanning indicator
            ZStack {
                // Outer rings
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(Color.blue.opacity(0.3 - Double(index) * 0.1), lineWidth: 2)
                        .frame(width: 200 + CGFloat(index) * 40,
                               height: 200 + CGFloat(index) * 40)
                        .scaleEffect(1 + CGFloat(animationPhase) * 0.1)
                        .opacity(1 - animationPhase * 0.5)
                }

                // Center icon
                Image(systemName: "wave.3.right")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    animationPhase = 1.0
                }
            }

            VStack(spacing: 12) {
                Text("Ready to Read")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Hold the other device near this iPhone")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button("Cancel") {
                viewModel.cancelReading()
            }
            .font(.headline)
            .foregroundStyle(.red)
            .padding(.bottom, 40)
        }
        .padding()
    }
}

// MARK: - Connecting View

private struct ConnectingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Connecting...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Waiting View

private struct WaitingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Waiting for approval...")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("The holder needs to approve the request")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Success View

private struct SuccessView: View {
    let attributes: [String: Any]
    var viewModel: ReaderViewModel

    private var portraitImage: UIImage? {
        guard let data = attributes[MDLElementIdentifier.portrait.rawValue] as? Data else { return nil }
        return UIImage(data: data)
    }

    private var nonPortraitKeys: [String] {
        attributes.keys
            .filter { $0 != MDLElementIdentifier.portrait.rawValue }
            .sorted()
    }

    var body: some View {
        VStack(spacing: 20) {
            // Success header
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)

                Text("Verified")
                    .font(.title)
                    .fontWeight(.bold)
            }
            .padding(.top, 40)

            // Portrait
            if let uiImage = portraitImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.green, lineWidth: 3))
            }

            // Attributes list
            VStack(alignment: .leading, spacing: 16) {
                ForEach(nonPortraitKeys, id: \.self) { key in
                    AttributeRow(
                        identifier: key,
                        value: attributes[key]
                    )
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
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
    }
}

// MARK: - Attribute Row

private struct AttributeRow: View {
    let identifier: String
    let value: Any?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(displayValue)
                    .font(.headline)
            }

            Spacer()

            if isBooleanAttribute {
                Image(systemName: boolValue ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(boolValue ? .green : .red)
                    .font(.title2)
            }
        }
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
        } else {
            return String(describing: value ?? "N/A")
        }
    }

    private var isBooleanAttribute: Bool {
        value is Bool
    }

    private var boolValue: Bool {
        value as? Bool ?? false
    }
}

// MARK: - Error View

private struct ErrorView: View {
    let message: String
    var viewModel: ReaderViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            Text("Verification Failed")
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

// MARK: - Reader View Model

@MainActor
@Observable
class ReaderViewModel {
    var state: ReaderState = .idle
    var selectedScenario: VerificationScenario = .ageVerification21

    @ObservationIgnored @Dependency(\.nfcService) var nfcService
    @ObservationIgnored @Dependency(\.transportService) var transportService
    @ObservationIgnored private let cborService = CBORService.shared

    enum ReaderState {
        case idle
        case scanning        // BLE scanning (Tap to Pay style UI)
        case connecting      // BLE connecting
        case waitingForResponse
        case success([String: Any])
        case error(String)
    }

    // MARK: - iOS Technical Constraints (NFC)
    //
    // In Apple's ID Verifier API (ProximityReader), the Reader starts an NFC session and
    // the Holder's iPhone responds as an NDEF tag with DeviceEngagement (NFC-to-BLE handover).
    // However, NFC tag emulation (HCE) is exclusive to Apple Wallet, so third-party apps
    // cannot make the Holder side act as an NDEF tag.
    //
    // Therefore, this workshop:
    // - Uses direct BLE connection (equivalent to ISO 18013-5 BLE engagement)
    // - Recreates a Tap to Pay style UI experience
    // - Uses the same ISO 18013-5 compliant CBOR structure for DeviceEngagement
    //
    // Reference: Apple's ID Verifier API internally implements
    // NFC engagement + BLE data transfer via the ProximityReader framework.

    init() {
        setupCallbacks()
    }

    private func setupCallbacks() {
        // Handle BLE connection
        transportService.setOnConnected { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                // Send the request after connection
                let request = self.selectedScenario.createRequest()
                self.transportService.sendRequest(request)
                self.state = .waitingForResponse
            }
        }

        // Handle response from holder
        transportService.setOnResponseReceived { [weak self] response in
            Task { @MainActor in
                self?.handleResponse(response)
            }
        }

        // Handle NFC engagement received
        nfcService.setOnEngagementReceived { [weak self] engagement, bleData in
            Task { @MainActor in
                self?.handleEngagementReceived(engagement, bleData: bleData)
            }
        }

        // Handle NFC error
        nfcService.setOnError { [weak self] error in
            Task { @MainActor in
                self?.state = .error(error.localizedDescription)
            }
        }
    }

    func startReading() {
        // The intended ISO 18013-5 flow:
        //   1. Reader starts NFCNDEFReaderSession
        //   2. Holder's iPhone responds as an NDEF tag with DeviceEngagement
        //   3. Reader extracts BLE UUID from DeviceEngagement and connects via BLE
        //
        // However, on iOS, NFC tag emulation (HCE) is exclusive to Apple Wallet,
        // so third-party apps cannot make the Holder act as an NDEF tag.
        // Apple's ID Verifier API (ProximityReader framework) implements this internally,
        // but requires a special entitlement and an agreement with Apple.
        //
        // This workshop uses direct BLE connection instead,
        // while recreating a Tap to Pay style UI experience.
        state = .scanning
        transportService.startCentralMode(nil)
    }

    private func handleEngagementReceived(_ engagement: DeviceEngagement, bleData: Data) {
        state = .connecting

        // Extract BLE UUID from engagement if available
        if let method = engagement.deviceRetrievalMethods.first(where: { $0.type == 2 }),
           let uuid = method.options.peripheralServerUUID {
            transportService.startCentralMode(UUID(uuidString: uuid))
        } else {
            transportService.startCentralMode(nil)
        }
    }

    private func handleResponse(_ response: DeviceResponse) {
        guard response.status == 0,
              let document = response.documents?.first else {
            state = .error("Invalid response from holder")
            transportService.stopCentralMode()
            return
        }

        // Extract attributes from the response
        var attributes: [String: Any] = [:]
        for (_, items) in document.issuerSigned.nameSpaces {
            for item in items {
                attributes[item.elementIdentifier] = item.elementValue
            }
        }

        state = .success(attributes)
        transportService.stopCentralMode()
    }

    func cancelReading() {
        nfcService.stopReaderSession()
        transportService.stopCentralMode()
        state = .idle
    }

    func reset() {
        transportService.stopCentralMode()
        state = .idle
    }
}

#Preview {
    NavigationStack {
        ReaderView()
    }
}
