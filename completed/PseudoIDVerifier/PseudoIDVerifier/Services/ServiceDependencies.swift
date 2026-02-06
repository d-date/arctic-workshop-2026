import Dependencies
import DependenciesMacros
import LocalAuthentication

// MARK: - BLE Service Dependency

extension BLEServiceClient: DependencyKey {
    static var liveValue: BLEServiceClient {
        #if targetEnvironment(simulator)
        .simulator
        #else
        let service = BLEService.shared
        return BLEServiceClient(
            connectionState: { service.connectionState },
            error: { service.error },
            setOnRequestReceived: { service.onRequestReceived = $0 },
            setOnResponseReceived: { service.onResponseReceived = $0 },
            setOnConnected: { service.onConnected = $0 },
            setOnDisconnected: { service.onDisconnected = $0 },
            startCentralMode: { service.startCentralMode(targetUUID: $0) },
            stopCentralMode: { service.stopCentralMode() },
            sendRequest: { service.sendRequest($0) },
            startPeripheralMode: { service.startPeripheralMode() },
            stopPeripheralMode: { service.stopPeripheralMode() },
            sendResponse: { service.sendResponse($0) }
        )
        #endif
    }

    static var previewValue: BLEServiceClient { .simulator }

    /// Simulator mock that simulates the full BLE flow with delays
    static var simulator: BLEServiceClient {
        final class Storage: @unchecked Sendable {
            var connectionState: BLEConnectionState = .disconnected
            var error: BLEError?
            var onRequestReceived: ((DeviceRequest) -> Void)?
            var onResponseReceived: ((DeviceResponse) -> Void)?
            var onConnected: (() -> Void)?
            var onDisconnected: (() -> Void)?
        }

        let storage = Storage()
        let connectionDelay: TimeInterval = 1.0
        let transferDelay: TimeInterval = 0.5

        return BLEServiceClient(
            connectionState: { storage.connectionState },
            error: { storage.error },
            setOnRequestReceived: { storage.onRequestReceived = $0 },
            setOnResponseReceived: { storage.onResponseReceived = $0 },
            setOnConnected: { storage.onConnected = $0 },
            setOnDisconnected: { storage.onDisconnected = $0 },
            startCentralMode: { _ in
                storage.connectionState = .scanning

                DispatchQueue.main.asyncAfter(deadline: .now() + connectionDelay) {
                    storage.connectionState = .connecting

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        storage.connectionState = .connected
                        storage.onConnected?()
                    }
                }
            },
            stopCentralMode: {
                storage.connectionState = .disconnected
                storage.onDisconnected?()
            },
            sendRequest: { request in
                DispatchQueue.main.asyncAfter(deadline: .now() + transferDelay * 4) {
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

                    storage.onResponseReceived?(response)
                }
            },
            startPeripheralMode: {
                storage.connectionState = .advertising

                DispatchQueue.main.asyncAfter(deadline: .now() + connectionDelay) {
                    storage.connectionState = .connected
                    storage.onConnected?()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        let request = VerificationScenario.ageVerification21.createRequest()
                        storage.onRequestReceived?(request)
                    }
                }
            },
            stopPeripheralMode: {
                storage.connectionState = .disconnected
            },
            sendResponse: { response in
                DispatchQueue.main.asyncAfter(deadline: .now() + transferDelay) {
                    storage.onResponseReceived?(response)
                }
            }
        )
    }
}

extension DependencyValues {
    var bleService: BLEServiceClient {
        get { self[BLEServiceClient.self] }
        set { self[BLEServiceClient.self] = newValue }
    }
}

// MARK: - NFC Service Dependency

extension NFCServiceClient: DependencyKey {
    static var liveValue: NFCServiceClient {
        #if targetEnvironment(simulator)
        .simulator
        #else
        let service = NFCService.shared
        return NFCServiceClient(
            isScanning: { service.isScanning },
            isNFCAvailable: { service.isNFCAvailable },
            setOnEngagementReceived: { service.onEngagementReceived = $0 },
            setOnError: { service.onError = $0 },
            startReaderSession: { service.startReaderSession() },
            stopReaderSession: { service.stopReaderSession() }
        )
        #endif
    }

    static var previewValue: NFCServiceClient { .simulator }

    /// Simulator mock that simulates NFC device engagement
    static var simulator: NFCServiceClient {
        final class Storage: @unchecked Sendable {
            var isScanning = false
            var onEngagementReceived: ((DeviceEngagement, Data) -> Void)?
            var onError: ((NFCError) -> Void)?
        }

        let storage = Storage()
        let scanDelay: TimeInterval = 1.5

        return NFCServiceClient(
            isScanning: { storage.isScanning },
            isNFCAvailable: { true },
            setOnEngagementReceived: { storage.onEngagementReceived = $0 },
            setOnError: { storage.onError = $0 },
            startReaderSession: {
                storage.isScanning = true

                DispatchQueue.main.asyncAfter(deadline: .now() + scanDelay) {
                    let engagement = DeviceEngagement(
                        security: Security(
                            cipherSuiteIdentifier: 1,
                            deviceEngagementKey: CryptoService.shared.devicePublicKeyData ?? Data()
                        ),
                        deviceRetrievalMethods: [
                            DeviceRetrievalMethod(
                                type: 2,
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

                    storage.isScanning = false
                    storage.onEngagementReceived?(engagement, Data())
                }
            },
            stopReaderSession: {
                storage.isScanning = false
            }
        )
    }
}

extension DependencyValues {
    var nfcService: NFCServiceClient {
        get { self[NFCServiceClient.self] }
        set { self[NFCServiceClient.self] = newValue }
    }
}

// MARK: - Authentication Service Dependency

extension AuthenticationServiceClient: DependencyKey {
    static var liveValue: AuthenticationServiceClient {
        #if targetEnvironment(simulator)
        .simulator
        #else
        let service = AuthenticationService.shared
        return AuthenticationServiceClient(
            isAuthenticated: { service.isAuthenticated },
            isBiometricAvailable: { service.isBiometricAvailable },
            biometricType: { service.biometricType },
            authenticateForDisclosure: { reason, completion in
                service.authenticateForDisclosure(reason: reason, completion: completion)
            },
            resetAuthentication: { service.resetAuthentication() }
        )
        #endif
    }

    static var previewValue: AuthenticationServiceClient { .simulator }

    /// Simulator mock that always succeeds
    static var simulator: AuthenticationServiceClient {
        let simulatedDelay: TimeInterval = 0.5

        return AuthenticationServiceClient(
            isAuthenticated: { false },
            isBiometricAvailable: { true },
            biometricType: { .faceID },
            authenticateForDisclosure: { _, completion in
                DispatchQueue.main.asyncAfter(deadline: .now() + simulatedDelay) {
                    completion(.success(()))
                }
            },
            resetAuthentication: { }
        )
    }
}

extension DependencyValues {
    var authenticationService: AuthenticationServiceClient {
        get { self[AuthenticationServiceClient.self] }
        set { self[AuthenticationServiceClient.self] = newValue }
    }
}
