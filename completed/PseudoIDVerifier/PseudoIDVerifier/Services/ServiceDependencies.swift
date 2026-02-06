import Dependencies

// MARK: - BLE Service Dependency

private enum BLEServiceKey: DependencyKey {
    static var liveValue: any BLEServiceProtocol {
        #if targetEnvironment(simulator)
        MockBLEService()
        #else
        BLEService.shared
        #endif
    }
    static var previewValue: any BLEServiceProtocol { MockBLEService() }
    static var testValue: any BLEServiceProtocol { MockBLEService() }
}

extension DependencyValues {
    var bleService: any BLEServiceProtocol {
        get { self[BLEServiceKey.self] }
        set { self[BLEServiceKey.self] = newValue }
    }
}

// MARK: - NFC Service Dependency

private enum NFCServiceKey: DependencyKey {
    static var liveValue: any NFCServiceProtocol {
        #if targetEnvironment(simulator)
        MockNFCService()
        #else
        NFCService.shared
        #endif
    }
    static var previewValue: any NFCServiceProtocol { MockNFCService() }
    static var testValue: any NFCServiceProtocol { MockNFCService() }
}

extension DependencyValues {
    var nfcService: any NFCServiceProtocol {
        get { self[NFCServiceKey.self] }
        set { self[NFCServiceKey.self] = newValue }
    }
}

// MARK: - Authentication Service Dependency

private enum AuthServiceKey: DependencyKey {
    static var liveValue: any AuthenticationServiceProtocol {
        #if targetEnvironment(simulator)
        MockAuthenticationService()
        #else
        AuthenticationService.shared
        #endif
    }
    static var previewValue: any AuthenticationServiceProtocol { MockAuthenticationService() }
    static var testValue: any AuthenticationServiceProtocol { MockAuthenticationService() }
}

extension DependencyValues {
    var authenticationService: any AuthenticationServiceProtocol {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }
}
