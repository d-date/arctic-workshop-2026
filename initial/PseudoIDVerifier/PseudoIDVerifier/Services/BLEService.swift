import Foundation
import CoreBluetooth

// MARK: - BLE Service for Data Transfer

/// Service for BLE-based data transfer between Reader and Holder
/// Implements the BLE transport layer similar to ISO 18013-5
class BLEService: NSObject, ObservableObject {
    static let shared = BLEService()

    // MARK: - Published State

    @Published var connectionState: BLEConnectionState = .disconnected
    @Published var error: BLEError?

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

    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?

    private var connectedPeripheral: CBPeripheral?
    private var connectedCentral: CBCentral?

    // MARK: - Characteristics (for peripheral mode)

    private var stateCharacteristic: CBMutableCharacteristic?
    private var client2ServerCharacteristic: CBMutableCharacteristic?
    private var server2ClientCharacteristic: CBMutableCharacteristic?

    // MARK: - Discovered Characteristics (for central mode)

    private var discoveredStateCharacteristic: CBCharacteristic?
    private var discoveredClient2ServerCharacteristic: CBCharacteristic?
    private var discoveredServer2ClientCharacteristic: CBCharacteristic?

    // MARK: - Data Buffers

    private var receivedData = Data()
    private var dataToSend = Data()
    private var sendDataIndex = 0

    // MARK: - Callbacks

    var onRequestReceived: ((DeviceRequest) -> Void)?
    var onResponseReceived: ((DeviceResponse) -> Void)?
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?

    // MARK: - Constants

    /// Maximum data length per BLE write (MTU - 3)
    private let maxChunkSize = 512

    private override init() {
        super.init()
    }

    // MARK: - Central Mode (Reader/Verifier)

    /// Start scanning for peripherals advertising the mdoc service
    /// - Parameter targetUUID: Optional specific peripheral UUID to connect to
    func startCentralMode(targetUUID: UUID? = nil) {
        // TODO: Implement central mode startup
        //
        // Steps:
        // 1. Create CBCentralManager with self as delegate
        // 2. Wait for centralManagerDidUpdateState to confirm powered on
        // 3. Start scanning for peripherals with serviceUUID
        //
        // Hint:
        // centralManager = CBCentralManager(delegate: self, queue: nil)

        fatalError("Not implemented - Complete this in Chapter 5")
    }

    /// Stop central mode and disconnect
    func stopCentralMode() {
        // TODO: Implement cleanup
        //
        // Steps:
        // 1. Stop scanning
        // 2. Disconnect from peripheral if connected
        // 3. Set centralManager to nil

        fatalError("Not implemented - Complete this in Chapter 5")
    }

    /// Send a device request to the connected peripheral (holder)
    /// - Parameter request: The request to send
    func sendRequest(_ request: DeviceRequest) {
        // TODO: Implement request sending
        //
        // Steps:
        // 1. Encode the request to CBOR using CBORService
        // 2. Write to the client2Server characteristic
        // 3. Handle chunking if data exceeds MTU

        fatalError("Not implemented - Complete this in Chapter 5")
    }

    // MARK: - Peripheral Mode (Holder/Presentment)

    /// Start peripheral mode to advertise and accept connections
    func startPeripheralMode() {
        // TODO: Implement peripheral mode startup
        //
        // Steps:
        // 1. Create CBPeripheralManager with self as delegate
        // 2. Wait for peripheralManagerDidUpdateState
        // 3. Create the service with characteristics
        // 4. Add the service
        // 5. Start advertising
        //
        // Characteristics setup:
        // - state: read, notify
        // - client2Server: write, write without response
        // - server2Client: read, notify

        fatalError("Not implemented - Complete this in Chapter 5")
    }

    /// Stop peripheral mode
    func stopPeripheralMode() {
        // TODO: Implement cleanup

        fatalError("Not implemented - Complete this in Chapter 5")
    }

    /// Send a device response to the connected central (reader)
    /// - Parameter response: The response to send
    func sendResponse(_ response: DeviceResponse) {
        // TODO: Implement response sending
        //
        // Steps:
        // 1. Encode the response to CBOR
        // 2. Update the server2Client characteristic
        // 3. Handle chunking for large responses

        fatalError("Not implemented - Complete this in Chapter 5")
    }

    // MARK: - Data Transfer Helpers

    /// Send data in chunks to handle BLE MTU limits
    private func sendDataInChunks(_ data: Data, to characteristic: CBMutableCharacteristic) {
        // TODO: Implement chunked data transfer
        //
        // BLE has a maximum transmission unit (MTU) limit
        // Large mdoc responses need to be split into chunks
        //
        // Approach:
        // 1. Split data into chunks of maxChunkSize
        // 2. Add a header byte indicating if more data follows
        // 3. Send each chunk via updateValue

        fatalError("Not implemented - Complete this in Chapter 5")
    }

    /// Reassemble chunked data
    private func reassembleChunkedData(_ chunk: Data) -> Data? {
        // TODO: Implement data reassembly
        //
        // Check the header byte to know if more chunks are expected
        // Append to receivedData buffer
        // Return complete data when all chunks received

        fatalError("Not implemented - Complete this in Chapter 5")
    }

    // MARK: - Service Setup (Peripheral Mode)

    private func setupService() {
        // TODO: Create and configure the BLE service
        //
        // Create characteristics:
        // stateCharacteristic = CBMutableCharacteristic(
        //     type: Self.stateCharacteristicUUID,
        //     properties: [.read, .notify],
        //     value: nil,
        //     permissions: [.readable]
        // )
        //
        // Create service and add characteristics:
        // let service = CBMutableService(type: Self.serviceUUID, primary: true)
        // service.characteristics = [...]
        // peripheralManager?.add(service)

        fatalError("Not implemented - Complete this in Chapter 5")
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // TODO: Handle central manager state changes
        //
        // When state is .poweredOn, start scanning:
        // central.scanForPeripherals(withServices: [Self.serviceUUID], options: nil)

        fatalError("Not implemented - Complete this in Chapter 5")
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                       advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // TODO: Handle discovered peripheral
        //
        // Steps:
        // 1. Store reference to peripheral
        // 2. Stop scanning
        // 3. Connect to peripheral

        fatalError("Not implemented - Complete this in Chapter 5")
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // TODO: Handle successful connection
        //
        // Steps:
        // 1. Set peripheral delegate to self
        // 2. Discover services
        // 3. Update connection state

        fatalError("Not implemented - Complete this in Chapter 5")
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // TODO: Handle connection failure

        fatalError("Not implemented - Complete this in Chapter 5")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // TODO: Handle disconnection

        fatalError("Not implemented - Complete this in Chapter 5")
    }
}

// MARK: - CBPeripheralDelegate

extension BLEService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        // TODO: Handle discovered services
        //
        // Find our service and discover its characteristics

        fatalError("Not implemented - Complete this in Chapter 5")
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // TODO: Handle discovered characteristics
        //
        // Store references to the characteristics
        // Subscribe to notifications for server2Client

        fatalError("Not implemented - Complete this in Chapter 5")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // TODO: Handle incoming data (response from holder)
        //
        // 1. Reassemble chunks if needed
        // 2. Decode CBOR to DeviceResponse
        // 3. Call onResponseReceived callback

        fatalError("Not implemented - Complete this in Chapter 5")
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        // TODO: Handle write confirmation

        fatalError("Not implemented - Complete this in Chapter 5")
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BLEService: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        // TODO: Handle peripheral manager state changes
        //
        // When state is .poweredOn, setup service and start advertising

        fatalError("Not implemented - Complete this in Chapter 5")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        // TODO: Handle service addition
        //
        // If successful, start advertising:
        // peripheral.startAdvertising([
        //     CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
        //     CBAdvertisementDataLocalNameKey: "PseudoIDVerifier"
        // ])

        fatalError("Not implemented - Complete this in Chapter 5")
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        // TODO: Handle advertising start

        fatalError("Not implemented - Complete this in Chapter 5")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral,
                          didSubscribeTo characteristic: CBCharacteristic) {
        // TODO: Handle central subscription
        //
        // Store reference to connected central
        // Update connection state

        fatalError("Not implemented - Complete this in Chapter 5")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                          didReceiveWrite requests: [CBATTRequest]) {
        // TODO: Handle incoming write request (request from reader)
        //
        // 1. Read data from client2Server characteristic
        // 2. Reassemble chunks if needed
        // 3. Decode CBOR to DeviceRequest
        // 4. Call onRequestReceived callback
        // 5. Respond to the write request

        fatalError("Not implemented - Complete this in Chapter 5")
    }
}

// MARK: - Connection State

enum BLEConnectionState {
    case disconnected
    case scanning
    case connecting
    case connected
    case advertising
    case error(BLEError)
}

// MARK: - Error Types

enum BLEError: LocalizedError {
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
