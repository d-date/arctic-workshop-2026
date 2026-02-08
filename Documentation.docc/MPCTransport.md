# MPC Transport

Quick prototype: Implement peer-to-peer communication with Multipeer Connectivity.

## Overview

Before diving into the full BLE transport layer required by ISO 18013-5, we start with the simplest possible transport. Apple's Multipeer Connectivity (MPC) framework handles discovery, connection, and data transfer with minimal code. There is no chunking, no GATT characteristics, no BLE UUIDs -- just `session.send(data)`.

MPC uses Bonjour (mDNS) for peer discovery. Each device creates an `MCPeerID` to identify itself, and an `MCSession` to manage the connection. An `MCNearbyServiceBrowser` discovers nearby peers, while an `MCNearbyServiceAdvertiser` makes a device visible to browsers. MPC automatically selects Wi-Fi or Bluetooth as the underlying transport -- you have no control over which is used.

> Note: MPC is not part of ISO 18013-5. We use it here as a rapid prototyping tool
> so you can verify the CBOR encoding/decoding pipeline end-to-end
> before tackling the more complex BLE implementation.
> See <doc:BLETransport> for the standards-compliant transport.

### Roles

| Role | MPC Component | Description |
|------|---------------|-------------|
| Reader | Browser | Browses for peers, sends invitation |
| Holder | Advertiser | Advertises service, accepts invitations |

### Message Type Header

Unlike BLE, which uses separate GATT characteristics for client-to-server and server-to-client data, MPC has a single `didReceive data` callback. To distinguish message types, we prepend a 1-byte header:

- `0x01` = DeviceRequest
- `0x02` = DeviceResponse

### Step 1: Browse and Advertise

> **Initial project**: Open `Services/MPCService.swift`. Find the `📋 PASTE: Step 1` markers.

Implement the four methods that start and stop browsing and advertising:

```swift
func startBrowsing() {
    let session = createSession()
    self.session = session

    browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
    browser?.delegate = self
    browser?.startBrowsingForPeers()

    DispatchQueue.main.async {
        self.connectionState = .scanning
    }
}

func stopBrowsing() {
    browser?.stopBrowsingForPeers()
    browser = nil
    session?.disconnect()
    session = nil

    DispatchQueue.main.async {
        self.connectionState = .disconnected
    }
}

func startAdvertising() {
    let session = createSession()
    self.session = session

    advertiser = MCNearbyServiceAdvertiser(
        peer: peerID,
        discoveryInfo: nil,
        serviceType: Self.serviceType
    )
    advertiser?.delegate = self
    advertiser?.startAdvertisingPeer()

    DispatchQueue.main.async {
        self.connectionState = .advertising
    }
}

func stopAdvertising() {
    advertiser?.stopAdvertisingPeer()
    advertiser = nil
    session?.disconnect()
    session = nil

    DispatchQueue.main.async {
        self.connectionState = .disconnected
    }
}
```

### Step 2: Session and Discovery Delegates

> **Initial project**: Find the `📋 PASTE: Step 2` markers in `Services/MPCService.swift`.

Implement `MCSessionDelegate` to handle connection state changes and incoming data, `MCNearbyServiceBrowserDelegate` to auto-invite discovered peers, and `MCNearbyServiceAdvertiserDelegate` to auto-accept invitations:

```swift
// MARK: - MCSessionDelegate

func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
    DispatchQueue.main.async {
        switch state {
        case .connected:
            print("MPCService: Connected to \(peerID.displayName)")
            self.connectionState = .connected
            self.onConnected?()
        case .notConnected:
            print("MPCService: Disconnected from \(peerID.displayName)")
            self.connectionState = .disconnected
            self.onDisconnected?()
        case .connecting:
            print("MPCService: Connecting to \(peerID.displayName)")
            self.connectionState = .connecting
        @unknown default:
            break
        }
    }
}

func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    guard !data.isEmpty else { return }

    let messageType = data[0]
    let payload = data.dropFirst()

    DispatchQueue.main.async {
        switch messageType {
        case self.messageTypeRequest:
            if let request = CBORService.shared.decodeRequest(from: Data(payload)) {
                self.onRequestReceived?(request)
            }
        case self.messageTypeResponse:
            if let response = CBORService.shared.decodeResponse(from: Data(payload)) {
                self.onResponseReceived?(response)
            }
        default:
            print("MPCService: Unknown message type: \(messageType)")
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
    guard let session = session else { return }
    print("MPCService: Found peer \(peerID.displayName), sending invitation")
    browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
}

// MARK: - MCNearbyServiceAdvertiserDelegate

func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
    print("MPCService: Received invitation from \(peerID.displayName), auto-accepting")
    invitationHandler(true, session)
}
```

### Step 3: Send Request and Response

> **Initial project**: Find the `📋 PASTE: Step 3` markers in `Services/MPCService.swift`.

Each message is prefixed with the 1-byte header before sending:

```swift
func sendRequest(_ request: DeviceRequest) {
    guard let session = session,
          let peer = session.connectedPeers.first else {
        print("MPCService: Cannot send request — no connected peer")
        return
    }

    let cborData = CBORService.shared.encode(request: request)
    var data = Data([messageTypeRequest])
    data.append(cborData)

    do {
        try session.send(data, toPeers: [peer], with: .reliable)
    } catch {
        print("MPCService: Send request failed: \(error.localizedDescription)")
    }
}

func sendResponse(_ response: DeviceResponse) {
    guard let session = session,
          let peer = session.connectedPeers.first else {
        print("MPCService: Cannot send response — no connected peer")
        return
    }

    let cborData = CBORService.shared.encode(response: response)
    var data = Data([messageTypeResponse])
    data.append(cborData)

    do {
        try session.send(data, toPeers: [peer], with: .reliable)
    } catch {
        print("MPCService: Send response failed: \(error.localizedDescription)")
    }
}
```

### What MPC Cannot Do

This is the most important section of this chapter. MPC works well for rapid prototyping, but it cannot satisfy the requirements of ISO 18013-5. The following table summarizes the gaps:

| Capability | ISO 18013-5 (BLE) | Multipeer Connectivity |
|---|---|---|
| NFC Handover | NDEF to BLE UUID | Bonjour only |
| Asymmetric Roles | Central / Peripheral | Symmetric peers |
| Device Targeting | BLE UUID from NFC | Bonjour discovery |
| GATT Characteristics | Separate channels | Single data channel |
| Transport Control | BLE only | Auto (Wi-Fi/BLE) |
| Data Chunking | Required (MTU limits) | Not needed |
| Session Encryption | App-layer ECDH | Internal (hidden) |

Each limitation is explained below:

1. **No NFC Handover** -- MPC uses Bonjour (mDNS) for discovery. There is no way to initiate an MPC session from an NFC tap or pass a BLE UUID via NFC NDEF. ISO 18013-5 requires the Holder to present a DeviceEngagement via NFC that contains a BLE service UUID for the Reader to connect to.

2. **No Asymmetric Roles** -- ISO 18013-5 designates the Reader as BLE Central and the Holder as BLE Peripheral. These roles carry protocol-level meaning: the Central initiates the connection and sends the request, while the Peripheral advertises and sends the response. MPC treats all peers symmetrically. We use Browser and Advertiser to simulate asymmetric roles, but the underlying framework makes no such distinction.

3. **No Device Targeting** -- In ISO 18013-5, the BLE UUID obtained from the NFC DeviceEngagement ensures the Reader connects to a specific device. MPC discovers all nearby peers broadcasting the same service type. In a room with multiple Holders, MPC has no mechanism to target a particular one.

4. **No GATT Characteristics** -- BLE uses separate GATT characteristics for client-to-server and server-to-client data, providing directional semantics at the transport level. MPC has a single `didReceive data` callback for all incoming data, which is why we added the 1-byte message type header as a workaround.

5. **No Transport Control** -- MPC automatically selects Wi-Fi or Bluetooth depending on conditions. The application has no say in which transport is used. ISO 18013-5 explicitly specifies BLE for proximity verification to ensure the Holder is physically present.

6. **No Visible Encryption** -- ISO 18013-5 uses ECDH key agreement at the application layer, giving both parties explicit control over session keys. MPC encrypts data internally, but the encryption mechanism is opaque. There is nothing to learn about session key establishment, which is a core part of the standard.

> Now you understand _why_ ISO 18013-5 chose BLE over a simpler framework like MultipeerConnectivity.
> The standard needs NFC handover, asymmetric roles, and fine-grained transport control
> that MPC simply cannot provide.

## Next Steps

Continue to <doc:BLETransport> to implement the ISO 18013-5 compliant BLE transport layer.
