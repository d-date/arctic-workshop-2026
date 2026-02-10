# BLE Transport

Implement Bluetooth Low Energy communication for data transfer.

## Overview

In ISO 18013-5, data transfer occurs over BLE after the NFC handover. In this chapter, you'll implement the BLE transport layer using CoreBluetooth, gaining full control over Central/Peripheral roles, GATT characteristics, and data chunking.

Due to iOS technical constraints (NFC tag emulation is unavailable), this workshop uses direct BLE connection, but the BLE transport layer itself is an ISO 18013-5 compliant implementation.

The Reader operates as a BLE **Central**, and the Holder operates as a BLE **Peripheral**.

> Note: In the intended ISO 18013-5 flow, the BLE service UUID is obtained from the NFC DeviceEngagement.
> This workshop uses a fixed UUID for direct connection,
> but the data structures (`DeviceRequest`, `DeviceResponse`) are the same.
> See <doc:NFCHandshake> for NFC details.

### BLE Roles

| Role | Mode | Description |
|------|------|-------------|
| Reader | Central | Scans, connects, sends requests |
| Holder | Peripheral | Advertises, accepts connections, sends responses |

### Service and Characteristics

ISO 18013-5 defines specific UUIDs, but for this workshop we'll use custom UUIDs:

```swift
// Service UUID
static let serviceUUID = CBUUID(string: "0000FF01-0000-1000-8000-00805F9B34FB")

// Characteristics
static let stateCharacteristicUUID = CBUUID(string: "0000FF02-...")     // State
static let client2ServerCharacteristicUUID = CBUUID(string: "0000FF03-...") // Request
static let server2ClientCharacteristicUUID = CBUUID(string: "0000FF04-...") // Response
```

### Step 1: Create BLEService

> **Initial project**: Open `Services/BLEService.swift`. The scaffolding (UUIDs, properties, callbacks, enums) is already provided. Find the `📋 PASTE` markers for each step below.

Review the existing scaffolding in `Services/BLEService.swift`:

```swift
import Foundation
import Observation
import CoreBluetooth

@Observable
class BLEService: NSObject {
    static let shared = BLEService()

    var connectionState: ConnectionState = .disconnected
    var error: TransportError?

    // UUIDs
    static let serviceUUID = CBUUID(string: "0000FF01-0000-1000-8000-00805F9B34FB")
    static let stateCharacteristicUUID = CBUUID(string: "0000FF02-0000-1000-8000-00805F9B34FB")
    static let client2ServerCharacteristicUUID = CBUUID(string: "0000FF03-0000-1000-8000-00805F9B34FB")
    static let server2ClientCharacteristicUUID = CBUUID(string: "0000FF04-0000-1000-8000-00805F9B34FB")

    // Core Bluetooth Objects
    @ObservationIgnored private var centralManager: CBCentralManager?
    @ObservationIgnored private var peripheralManager: CBPeripheralManager?

    // Connected devices
    @ObservationIgnored private var connectedPeripheral: CBPeripheral?
    @ObservationIgnored private var connectedCentral: CBCentral?

    // Characteristics
    @ObservationIgnored private var client2ServerCharacteristic: CBMutableCharacteristic?
    @ObservationIgnored private var server2ClientCharacteristic: CBMutableCharacteristic?

    // Callbacks
    @ObservationIgnored var onRequestReceived: ((DeviceRequest) -> Void)?
    @ObservationIgnored var onResponseReceived: ((DeviceResponse) -> Void)?
    @ObservationIgnored var onConnected: (() -> Void)?

    private override init() {
        super.init()
    }
}
```

### Step 2: Implement Central Mode (Reader)

> **Pair Work**: This step is for the **Reader** participant.

> **Initial project**: Find the `📋 PASTE: Step 2` markers in `Services/BLEService.swift`.

```swift
extension BLEService {
    func startCentralMode() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
        connectionState = .scanning
    }

    func stopCentralMode() {
        centralManager?.stopScan()
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        centralManager = nil
        connectionState = .disconnected
    }

    func sendRequest(_ request: DeviceRequest) {
        guard let peripheral = connectedPeripheral,
              let characteristic = discoveredClient2ServerCharacteristic else {
            return
        }

        let data = CBORService.shared.encode(request: request)
        sendDataInChunks(data, to: peripheral, characteristic: characteristic)
    }
}

extension BLEService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(
                withServices: [Self.serviceUUID],
                options: nil
            )
        }
    }

    func centralManager(_ central: CBCentralManager,
                       didDiscover peripheral: CBPeripheral,
                       advertisementData: [String: Any],
                       rssi RSSI: NSNumber) {
        connectedPeripheral = peripheral
        central.stopScan()
        central.connect(peripheral, options: nil)
        connectionState = .connecting
    }

    func centralManager(_ central: CBCentralManager,
                       didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([Self.serviceUUID])
        connectionState = .connected
        onConnected?()
    }
}
```

### Step 3: Implement Peripheral Mode (Holder)

> **Pair Work**: This step is for the **Holder** participant.

> **Initial project**: Find the `📋 PASTE: Step 3` markers in `Services/BLEService.swift`.

```swift
extension BLEService {
    func startPeripheralMode() {
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    func stopPeripheralMode() {
        peripheralManager?.stopAdvertising()
        peripheralManager?.removeAllServices()
        peripheralManager = nil
        connectionState = .disconnected
    }

    func sendResponse(_ response: DeviceResponse) {
        guard let characteristic = server2ClientCharacteristic,
              let central = connectedCentral else {
            return
        }

        let data = CBORService.shared.encode(response: response)
        peripheralManager?.updateValue(
            data,
            for: characteristic,
            onSubscribedCentrals: [central]
        )
    }

    private func setupService() {
        client2ServerCharacteristic = CBMutableCharacteristic(
            type: Self.client2ServerUUID,
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )

        server2ClientCharacteristic = CBMutableCharacteristic(
            type: Self.server2ClientUUID,
            properties: [.read, .notify],
            value: nil,
            permissions: [.readable]
        )

        let service = CBMutableService(type: Self.serviceUUID, primary: true)
        service.characteristics = [
            client2ServerCharacteristic!,
            server2ClientCharacteristic!
        ]

        peripheralManager?.add(service)
    }
}

extension BLEService: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            setupService()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                          didAdd service: CBService,
                          error: Error?) {
        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
            CBAdvertisementDataLocalNameKey: "PseudoIDVerifier"
        ])
        connectionState = .advertising
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                          central: CBCentral,
                          didSubscribeTo characteristic: CBCharacteristic) {
        connectedCentral = central
        connectionState = .connected
        onConnected?()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                          didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if request.characteristic.uuid == Self.client2ServerUUID,
               let data = request.value {
                // Decode and handle request
                if let deviceRequest = CBORService.shared.decodeRequest(from: data) {
                    onRequestReceived?(deviceRequest)
                }
                peripheral.respond(to: request, withResult: .success)
            }
        }
    }
}
```

### Step 4: Handle Data Chunking

> **Pair Work**: Both participants implement this step. Reader needs `sendDataInChunks` (Central write). Holder needs `reassembleChunkedData`.

> **Initial project**: Find the `📋 PASTE: Step 4` markers in `Services/BLEService.swift`.

BLE has MTU limits. Implement chunking for large data:

```swift
extension BLEService {
    private let maxChunkSize = 512
    private let headerMoreData: UInt8 = 0x01
    private let headerLastChunk: UInt8 = 0x00

    // Central mode: write chunks to peripheral
    private func sendDataInChunks(_ data: Data,
                                   to peripheral: CBPeripheral,
                                   characteristic: CBCharacteristic) {
        var offset = 0

        while offset < data.count {
            let chunkSize = min(maxChunkSize - 1, data.count - offset)
            let isLast = (offset + chunkSize >= data.count)

            var chunk = Data()
            chunk.append(isLast ? headerLastChunk : headerMoreData)
            chunk.append(data[offset..<(offset + chunkSize)])

            peripheral.writeValue(chunk, for: characteristic, type: .withResponse)
            offset += chunkSize
        }
    }

    private var receivedData = Data()

    private func reassembleChunkedData(_ chunk: Data) -> Data? {
        guard !chunk.isEmpty else { return nil }

        let header = chunk[0]
        receivedData.append(chunk.dropFirst())

        if header == headerLastChunk {
            let complete = receivedData
            receivedData = Data()
            return complete
        }
        return nil
    }
}
```

### Step 5: Handle `updateValue` Queue Overflow (Peripheral Mode)

> **Pair Work**: This step is for the **Holder** participant.

> Important: This step is critical for **Full Identity Check**, which includes portrait
> data. The portrait is a JPEG image — typically tens of kilobytes — that requires many
> BLE chunks. Without this fix, the reader will be stuck on "Waiting for approval…" forever.

In Peripheral mode (Holder), `sendResponse` uses `peripheralManager.updateValue(_:for:onSubscribedCentrals:)` to push data to the Reader via notifications. Unlike `writeValue` in Central mode, **`updateValue` can return `false`** when the BLE transmit queue is full. When this happens, the chunk is silently dropped.

For small payloads (e.g. Age Verification with 2 attributes), all chunks may fit in a single queue flush. But for Full Identity Check — which includes portrait data (JPEG, ~20–50 KB) plus 5 other attributes — the CBOR-encoded response can easily exceed the queue capacity. Chunks are lost, and the Reader never receives a complete response.

**Solution**: Buffer all chunks and drain them progressively. When `updateValue` returns `false`, stop and wait for the `peripheralManagerIsReady(toUpdateSubscribers:)` callback, then resume sending.

```swift
// Peripheral mode: notify chunks to central with backpressure handling
@ObservationIgnored private var pendingChunks: [Data] = []
@ObservationIgnored private var sendCharacteristic: CBMutableCharacteristic?
@ObservationIgnored private var sendCentral: CBCentral?

private func sendDataInChunks(_ data: Data,
                               toCharacteristic characteristic: CBMutableCharacteristic,
                               central: CBCentral) {
    sendCharacteristic = characteristic
    sendCentral = central
    pendingChunks.removeAll()

    var offset = 0
    while offset < data.count {
        let chunkSize = min(maxChunkSize - 1, data.count - offset)
        let isLast = (offset + chunkSize >= data.count)

        var chunk = Data()
        chunk.append(isLast ? headerLastChunk : headerMoreData)
        chunk.append(data[offset..<(offset + chunkSize)])

        pendingChunks.append(chunk)
        offset += chunkSize
    }

    drainPendingChunks()
}

private func drainPendingChunks() {
    guard let characteristic = sendCharacteristic,
          let central = sendCentral else { return }

    while !pendingChunks.isEmpty {
        let chunk = pendingChunks[0]
        let sent = peripheralManager?.updateValue(
            chunk, for: characteristic, onSubscribedCentrals: [central]
        ) ?? false

        if sent {
            pendingChunks.removeFirst()
        } else {
            // Queue full — peripheralManagerIsReady will call us back
            break
        }
    }
}

// Add this delegate method to CBPeripheralManagerDelegate:
func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
    drainPendingChunks()
}
```

> Tip: The `sendResponse` method in Step 3 should also use `sendDataInChunks` for chunking,
> rather than calling `updateValue` directly on the full data.

### Connection States

These enums define the transport layer states (defined in `BLEService.swift`):

```swift
enum ConnectionState {
    case disconnected
    case scanning
    case connecting
    case connected
    case advertising
    case error(TransportError)
}

enum TransportError: LocalizedError {
    case bluetoothUnavailable
    case bluetoothPoweredOff
    case connectionFailed(String)
    case timeout
}
```

### Pair Test: BLE

After both partners have implemented their steps, test BLE together:

1. **Holder** device: Start Peripheral mode (advertising)
2. **Reader** device: Start Central mode (scanning)
3. Verify BLE connection is established
4. **Reader** sends a DeviceRequest via BLE
5. **Holder** receives and prints the decoded request

> Tip: Try the Age 21+ scenario first (small payload), then Full Identity Check (large payload with portrait) to verify chunking works.

## Next Steps

After the BLE pair test, the paths diverge:

- **Reader**: Continue to <doc:MSOVerification> to implement issuerAuth signature and digest verification.
- **Holder**: Continue to <doc:SelectiveDisclosure> to implement attribute filtering and user consent UI, then <doc:BiometricAuthentication>.

## See Also

- <doc:CBOREncodingDecoding>
- <doc:SelectiveDisclosure>
- <doc:MSOVerification>
