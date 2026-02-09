import Foundation
import Observation
import CoreBluetooth

// MARK: - BLE Service for Data Transfer

/// Service for BLE-based data transfer between Reader and Holder
/// Implements the BLE transport layer similar to ISO 18013-5
@Observable
class BLEService: NSObject {
    static let shared = BLEService()

    // MARK: - Observable State

    var connectionState: ConnectionState = .disconnected
    var error: TransportError?

    // MARK: - UUIDs

    /// Service UUID for mdoc data transfer
    static let serviceUUID = CBUUID(string: "0000FF01-0000-1000-8000-00805F9B34FB")

    /// Characteristic for state (indicates data transfer state)
    static let stateCharacteristicUUID = CBUUID(string: "0000FF02-0000-1000-8000-00805F9B34FB")

    /// Characteristic for client2server data (Reader → Holder)
    static let client2ServerCharacteristicUUID = CBUUID(string: "0000FF03-0000-1000-8000-00805F9B34FB")

    /// Characteristic for server2client data (Holder → Reader)
    static let server2ClientCharacteristicUUID = CBUUID(string: "0000FF04-0000-1000-8000-00805F9B34FB")

    // MARK: - Core Bluetooth Objects

    @ObservationIgnored private var centralManager: CBCentralManager?
    @ObservationIgnored private var peripheralManager: CBPeripheralManager?

    @ObservationIgnored private var connectedPeripheral: CBPeripheral?
    @ObservationIgnored private var connectedCentral: CBCentral?

    // MARK: - Characteristics (for peripheral mode)

    @ObservationIgnored private var stateCharacteristic: CBMutableCharacteristic?
    @ObservationIgnored private var client2ServerCharacteristic: CBMutableCharacteristic?
    @ObservationIgnored private var server2ClientCharacteristic: CBMutableCharacteristic?

    // MARK: - Discovered Characteristics (for central mode)

    @ObservationIgnored private var discoveredStateCharacteristic: CBCharacteristic?
    @ObservationIgnored private var discoveredClient2ServerCharacteristic: CBCharacteristic?
    @ObservationIgnored private var discoveredServer2ClientCharacteristic: CBCharacteristic?

    // MARK: - Data Buffers

    @ObservationIgnored private var receivedData = Data()
    @ObservationIgnored private var dataToSend = Data()
    @ObservationIgnored private var sendDataIndex = 0

    // MARK: - Callbacks

    @ObservationIgnored var onRequestReceived: ((DeviceRequest) -> Void)?
    @ObservationIgnored var onResponseReceived: ((DeviceResponse) -> Void)?
    @ObservationIgnored var onConnected: (() -> Void)?
    @ObservationIgnored var onDisconnected: (() -> Void)?

    // MARK: - Constants

    /// Maximum data length per BLE write (MTU - 3)
    private let maxChunkSize = 512

    /// Header byte: 0x00 = last chunk, 0x01 = more chunks follow
    private let headerMoreData: UInt8 = 0x01
    private let headerLastChunk: UInt8 = 0x00

    private override init() {
        super.init()
    }

    // MARK: - Central Mode (Reader/Verifier)

    /// Start scanning for peripherals advertising the mdoc service
    func startCentralMode(targetUUID: UUID? = nil) {
        receivedData = Data()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        DispatchQueue.main.async {
            self.connectionState = .scanning
        }
    }

    /// Stop central mode and disconnect
    func stopCentralMode() {
        centralManager?.stopScan()
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        centralManager = nil
        receivedData = Data()

        DispatchQueue.main.async {
            self.connectionState = .disconnected
        }
    }

    /// Send a device request to the connected peripheral (holder)
    func sendRequest(_ request: DeviceRequest) {
        guard let peripheral = connectedPeripheral,
              let characteristic = discoveredClient2ServerCharacteristic else {
            print("BLEService: Cannot send request - not connected")
            return
        }

        let data = CBORService.shared.encode(request: request)
        sendDataInChunks(data, toPeripheral: peripheral, characteristic: characteristic)
    }

    // MARK: - Peripheral Mode (Holder/Presentment)

    /// Start peripheral mode to advertise and accept connections
    func startPeripheralMode() {
        receivedData = Data()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    /// Stop peripheral mode
    func stopPeripheralMode() {
        peripheralManager?.stopAdvertising()
        peripheralManager?.removeAllServices()
        peripheralManager = nil
        connectedCentral = nil
        receivedData = Data()

        DispatchQueue.main.async {
            self.connectionState = .disconnected
        }
    }

    /// Send a device response to the connected central (reader)
    func sendResponse(_ response: DeviceResponse) {
        guard let characteristic = server2ClientCharacteristic,
              let central = connectedCentral else {
            print("BLEService: Cannot send response - not connected")
            return
        }

        let data = CBORService.shared.encode(response: response)
        sendDataInChunks(data, toCharacteristic: characteristic, central: central)
    }

    // MARK: - Data Transfer Helpers (Central Mode)

    private func sendDataInChunks(_ data: Data, toPeripheral peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        var offset = 0
        let totalLength = data.count

        while offset < totalLength {
            let chunkSize = min(maxChunkSize - 1, totalLength - offset)
            let isLastChunk = (offset + chunkSize >= totalLength)

            var chunk = Data()
            chunk.append(isLastChunk ? headerLastChunk : headerMoreData)
            chunk.append(data[offset..<(offset + chunkSize)])

            peripheral.writeValue(chunk, for: characteristic, type: .withResponse)
            offset += chunkSize
        }
    }

    // MARK: - Data Transfer Helpers (Peripheral Mode)

    private func sendDataInChunks(_ data: Data, toCharacteristic characteristic: CBMutableCharacteristic, central: CBCentral) {
        var offset = 0
        let totalLength = data.count

        while offset < totalLength {
            let chunkSize = min(maxChunkSize - 1, totalLength - offset)
            let isLastChunk = (offset + chunkSize >= totalLength)

            var chunk = Data()
            chunk.append(isLastChunk ? headerLastChunk : headerMoreData)
            chunk.append(data[offset..<(offset + chunkSize)])

            peripheralManager?.updateValue(chunk, for: characteristic, onSubscribedCentrals: [central])
            offset += chunkSize
        }
    }

    /// Reassemble chunked data
    private func reassembleChunkedData(_ chunk: Data) -> Data? {
        guard !chunk.isEmpty else { return nil }

        let header = chunk[0]
        let payload = chunk.dropFirst()

        receivedData.append(payload)

        if header == headerLastChunk {
            // All chunks received
            let completeData = receivedData
            receivedData = Data()
            return completeData
        }

        // More chunks expected
        return nil
    }

    // MARK: - Service Setup (Peripheral Mode)

    private func setupService() {
        // State characteristic
        stateCharacteristic = CBMutableCharacteristic(
            type: Self.stateCharacteristicUUID,
            properties: [.read, .notify],
            value: nil,
            permissions: [.readable]
        )

        // Client to Server characteristic (Reader → Holder)
        client2ServerCharacteristic = CBMutableCharacteristic(
            type: Self.client2ServerCharacteristicUUID,
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )

        // Server to Client characteristic (Holder → Reader)
        server2ClientCharacteristic = CBMutableCharacteristic(
            type: Self.server2ClientCharacteristicUUID,
            properties: [.read, .notify],
            value: nil,
            permissions: [.readable]
        )

        let service = CBMutableService(type: Self.serviceUUID, primary: true)
        service.characteristics = [
            stateCharacteristic!,
            client2ServerCharacteristic!,
            server2ClientCharacteristic!
        ]

        peripheralManager?.add(service)
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            central.scanForPeripherals(withServices: [Self.serviceUUID], options: nil)
            DispatchQueue.main.async {
                self.connectionState = .scanning
            }

        case .poweredOff:
            DispatchQueue.main.async {
                self.error = .bluetoothPoweredOff
                self.connectionState = .error(.bluetoothPoweredOff)
            }

        case .unsupported, .unauthorized:
            DispatchQueue.main.async {
                self.error = .bluetoothUnavailable
                self.connectionState = .error(.bluetoothUnavailable)
            }

        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                       advertisementData: [String: Any], rssi RSSI: NSNumber) {
        print("BLEService: Discovered peripheral: \(peripheral.name ?? "Unknown")")

        connectedPeripheral = peripheral
        central.stopScan()
        central.connect(peripheral, options: nil)

        DispatchQueue.main.async {
            self.connectionState = .connecting
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("BLEService: Connected to peripheral, discovering services...")

        peripheral.delegate = self
        peripheral.discoverServices([Self.serviceUUID])

        DispatchQueue.main.async {
            self.connectionState = .connecting
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("BLEService: Failed to connect: \(error?.localizedDescription ?? "Unknown")")

        DispatchQueue.main.async {
            self.error = .connectionFailed(error?.localizedDescription ?? "Unknown error")
            self.connectionState = .error(.connectionFailed(error?.localizedDescription ?? "Unknown"))
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("BLEService: Disconnected from peripheral")

        connectedPeripheral = nil

        DispatchQueue.main.async {
            self.connectionState = .disconnected
            self.onDisconnected?()
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil,
              let services = peripheral.services else {
            print("BLEService: Error discovering services: \(error?.localizedDescription ?? "")")
            return
        }

        for service in services {
            if service.uuid == Self.serviceUUID {
                peripheral.discoverCharacteristics([
                    Self.stateCharacteristicUUID,
                    Self.client2ServerCharacteristicUUID,
                    Self.server2ClientCharacteristicUUID
                ], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil,
              let characteristics = service.characteristics else {
            print("BLEService: Error discovering characteristics: \(error?.localizedDescription ?? "")")
            return
        }

        for characteristic in characteristics {
            switch characteristic.uuid {
            case Self.stateCharacteristicUUID:
                discoveredStateCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)

            case Self.client2ServerCharacteristicUUID:
                discoveredClient2ServerCharacteristic = characteristic

            case Self.server2ClientCharacteristicUUID:
                discoveredServer2ClientCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)

            default:
                break
            }
        }

        print("BLEService: Characteristics discovered and subscribed")

        // Notify connection ready only after characteristics are available,
        // so sendRequest can safely write to the client2Server characteristic.
        if discoveredClient2ServerCharacteristic != nil,
           discoveredServer2ClientCharacteristic != nil {
            DispatchQueue.main.async {
                self.connectionState = .connected
                self.onConnected?()
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil,
              let data = characteristic.value else {
            return
        }

        if characteristic.uuid == Self.server2ClientCharacteristicUUID {
            // Response from holder
            if let completeData = reassembleChunkedData(data) {
                if let response = CBORService.shared.decodeResponse(from: completeData) {
                    DispatchQueue.main.async {
                        self.onResponseReceived?(response)
                    }
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("BLEService: Write error: \(error.localizedDescription)")
        }
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BLEService: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            setupService()

        case .poweredOff:
            DispatchQueue.main.async {
                self.error = .bluetoothPoweredOff
                self.connectionState = .error(.bluetoothPoweredOff)
            }

        case .unsupported, .unauthorized:
            DispatchQueue.main.async {
                self.error = .bluetoothUnavailable
                self.connectionState = .error(.bluetoothUnavailable)
            }

        default:
            break
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            print("BLEService: Error adding service: \(error.localizedDescription)")
            return
        }

        print("BLEService: Service added, starting advertising")

        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
            CBAdvertisementDataLocalNameKey: "PseudoIDVerifier"
        ])
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("BLEService: Error starting advertising: \(error.localizedDescription)")
            return
        }

        print("BLEService: Advertising started")

        DispatchQueue.main.async {
            self.connectionState = .advertising
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral,
                          didSubscribeTo characteristic: CBCharacteristic) {
        print("BLEService: Central subscribed to characteristic")

        connectedCentral = central

        DispatchQueue.main.async {
            self.connectionState = .connected
            self.onConnected?()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                          didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if request.characteristic.uuid == Self.client2ServerCharacteristicUUID,
               let data = request.value {

                // Reassemble chunked data
                if let completeData = reassembleChunkedData(data) {
                    // Decode the request
                    if let deviceRequest = CBORService.shared.decodeRequest(from: completeData) {
                        DispatchQueue.main.async {
                            self.onRequestReceived?(deviceRequest)
                        }
                    }
                }

                peripheral.respond(to: request, withResult: .success)
            }
        }
    }
}

// MARK: - Connection State

enum ConnectionState {
    case disconnected
    case scanning
    case connecting
    case connected
    case advertising
    case error(TransportError)
}

// MARK: - Error Types

enum TransportError: LocalizedError {
    case bluetoothUnavailable
    case bluetoothPoweredOff
    case connectionFailed(String)
    case transferFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable:
            return "Bluetooth is not available on this device"
        case .bluetoothPoweredOff:
            return "Please turn on Bluetooth"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .transferFailed(let reason):
            return "Data transfer failed: \(reason)"
        case .timeout:
            return "Connection timed out"
        }
    }
}
