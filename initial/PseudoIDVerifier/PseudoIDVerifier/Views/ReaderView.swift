import SwiftUI

// MARK: - Reader View (Verifier Mode)

/// Main view for the Reader/Verifier mode
/// This is where the verifier initiates ID verification requests
struct ReaderView: View {
    @StateObject private var viewModel = ReaderViewModel()

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
    @ObservedObject var viewModel: ReaderViewModel

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
    @ObservedObject var viewModel: ReaderViewModel
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
    @ObservedObject var viewModel: ReaderViewModel

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

            // Attributes list
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(attributes.keys.sorted()), id: \.self) { key in
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
    @ObservedObject var viewModel: ReaderViewModel

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
class ReaderViewModel: ObservableObject {
    @Published var state: ReaderState = .idle
    @Published var selectedScenario: VerificationScenario = .ageVerification21

    private let nfcService = NFCService.shared
    private let bleService = BLEService.shared
    private let cborService = CBORService.shared

    enum ReaderState {
        case idle
        case scanning
        case connecting
        case waitingForResponse
        case success([String: Any])
        case error(String)
    }

    func startReading() {
        // TODO: Implement reading flow
        //
        // Steps:
        // 1. Set state to .scanning
        // 2. Start NFC reader session
        // 3. On NFC success, extract BLE UUID and device engagement
        // 4. Set state to .connecting
        // 5. Connect via BLE
        // 6. Send device request
        // 7. Set state to .waitingForResponse
        // 8. On response, decode and display attributes

        fatalError("Not implemented - Complete this in Chapter 7")
    }

    func cancelReading() {
        // TODO: Cancel NFC session and reset state

        fatalError("Not implemented - Complete this in Chapter 7")
    }

    func reset() {
        state = .idle
    }
}

#Preview {
    NavigationStack {
        ReaderView()
    }
}
