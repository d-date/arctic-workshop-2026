import Foundation

// MARK: - Mock NFC Service for Simulator

/// Simulates NFC device engagement for use on the iOS Simulator
class MockNFCService: NFCServiceProtocol {
    private(set) var isScanning = false
    var isNFCAvailable: Bool { true }

    var onEngagementReceived: ((DeviceEngagement, Data) -> Void)?
    var onError: ((NFCError) -> Void)?

    private let scanDelay: TimeInterval = 1.5

    func startReaderSession() {
        isScanning = true

        DispatchQueue.main.asyncAfter(deadline: .now() + scanDelay) { [weak self] in
            guard let self = self else { return }

            let engagement = DeviceEngagement(
                security: Security(
                    cipherSuiteIdentifier: 1,
                    deviceEngagementKey: CryptoService.shared.devicePublicKeyData ?? Data()
                ),
                deviceRetrievalMethods: [
                    DeviceRetrievalMethod(
                        type: 2, // BLE
                        version: 1,
                        options: RetrievalOptions(
                            peripheralServerMode: true,
                            centralClientMode: nil,
                            peripheralServerUUID: nil,
                            centralClientUUID: nil,
                            bleDeviceAddress: nil
                        )
                    )
                ]
            )

            self.isScanning = false
            self.onEngagementReceived?(engagement, Data())
        }
    }

    func stopReaderSession() {
        isScanning = false
    }
}
