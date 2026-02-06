import Foundation

// MARK: - Mock BLE Service for Simulator

/// Simulates the full BLE flow for use on the iOS Simulator
class MockBLEService: BLEServiceProtocol {
    private(set) var connectionState: BLEConnectionState = .disconnected
    private(set) var error: BLEError?

    var onRequestReceived: ((DeviceRequest) -> Void)?
    var onResponseReceived: ((DeviceResponse) -> Void)?
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?

    private let connectionDelay: TimeInterval = 1.0
    private let transferDelay: TimeInterval = 0.5

    // MARK: - Central Mode (Reader)

    func startCentralMode(targetUUID: UUID? = nil) {
        connectionState = .scanning

        DispatchQueue.main.asyncAfter(deadline: .now() + connectionDelay) { [weak self] in
            self?.connectionState = .connecting

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.connectionState = .connected
                self?.onConnected?()
            }
        }
    }

    func stopCentralMode() {
        connectionState = .disconnected
        onDisconnected?()
    }

    func sendRequest(_ request: DeviceRequest) {
        // Simulate the holder approving and responding
        DispatchQueue.main.asyncAfter(deadline: .now() + transferDelay * 4) { [weak self] in
            let credential = DummyCredentials.createSampleMDL()
            let selectiveMDoc = CBORService.shared.createSelectiveResponse(
                from: credential, for: request
            )

            let deviceSigned = DeviceSigned(
                nameSpaces: Data(),
                deviceAuth: DeviceAuth(deviceMac: nil, deviceSignature: Data())
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
                status: 0
            )

            self?.onResponseReceived?(response)
        }
    }

    // MARK: - Peripheral Mode (Holder)

    func startPeripheralMode() {
        connectionState = .advertising

        DispatchQueue.main.asyncAfter(deadline: .now() + connectionDelay) { [weak self] in
            self?.connectionState = .connected
            self?.onConnected?()

            // Simulate receiving a verification request from a reader
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                let request = VerificationScenario.ageVerification21.createRequest()
                self?.onRequestReceived?(request)
            }
        }
    }

    func stopPeripheralMode() {
        connectionState = .disconnected
    }

    func sendResponse(_ response: DeviceResponse) {
        // Response sent successfully (no real transport needed)
        DispatchQueue.main.asyncAfter(deadline: .now() + transferDelay) { [weak self] in
            self?.onResponseReceived?(response)
        }
    }
}
