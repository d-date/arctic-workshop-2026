import Foundation
import Observation
import MultipeerConnectivity

// MARK: - Multipeer Connectivity Service for Data Transfer

/// Service for peer-to-peer data transfer using MultipeerConnectivity.
/// Provides the same callback interface as BLEService, allowing the
/// TransportServiceClient to swap between MPC and BLE transparently.
///
/// ## How it works
///
/// MPC uses Bonjour (mDNS) for peer discovery over Wi-Fi and Bluetooth.
/// The Reader browses for peers, the Holder advertises.
/// Once connected, CBOR-encoded data is sent via `MCSession.send()`.
///
/// ## Message Type Header
///
/// Since MPC has a single `didReceive data` callback (unlike BLE which has
/// separate characteristics for request/response), a 1-byte header distinguishes:
/// - `0x01` = DeviceRequest (Reader → Holder)
/// - `0x02` = DeviceResponse (Holder → Reader)
///
/// ## What MPC Cannot Do (vs ISO 18013-5 BLE)
///
/// - No NFC handover (Bonjour-based discovery, not NDEF)
/// - No Central/Peripheral asymmetric roles (peers are symmetric)
/// - No GATT Characteristics (single data channel)
/// - No BLE UUID-based device targeting
/// - No MTU constraints (no chunking needed)
/// - No visible session encryption key exchange (handled internally)
/// - No transport control (Wi-Fi vs BLE auto-selected)
@Observable
class MPCService: NSObject {
    static let shared = MPCService()

    // MARK: - Observable State

    var connectionState: ConnectionState = .disconnected
    var error: TransportError?

    // MARK: - MPC Objects

    @ObservationIgnored private let peerID: MCPeerID
    @ObservationIgnored private var session: MCSession?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?
    @ObservationIgnored private var advertiser: MCNearbyServiceAdvertiser?

    // MARK: - Constants

    /// Bonjour service type (max 15 chars, lowercase ASCII + hyphens)
    static let serviceType = "pseudo-id-vrfy"

    /// Message type header: DeviceRequest
    private let messageTypeRequest: UInt8 = 0x01

    /// Message type header: DeviceResponse
    private let messageTypeResponse: UInt8 = 0x02

    // MARK: - Callbacks

    @ObservationIgnored var onRequestReceived: ((DeviceRequest) -> Void)?
    @ObservationIgnored var onResponseReceived: ((DeviceResponse) -> Void)?
    @ObservationIgnored var onConnected: (() -> Void)?
    @ObservationIgnored var onDisconnected: (() -> Void)?

    // MARK: - Init

    private override init() {
        peerID = MCPeerID(displayName: UIDevice.current.name)
        super.init()
    }

    // MARK: - Session

    private func createSession() -> MCSession {
        let session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        session.delegate = self
        return session
    }

    // MARK: - Browser Mode (Reader/Verifier)

    /// Start browsing for nearby peers advertising the mdoc service
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

    /// Stop browsing and disconnect
    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        session?.disconnect()
        session = nil

        DispatchQueue.main.async {
            self.connectionState = .disconnected
        }
    }

    /// Send a DeviceRequest to the connected peer (holder)
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

    // MARK: - Advertiser Mode (Holder/Presentment)

    /// Start advertising to nearby peers
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

    /// Stop advertising and disconnect
    func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        session?.disconnect()
        session = nil

        DispatchQueue.main.async {
            self.connectionState = .disconnected
        }
    }

    /// Send a DeviceResponse to the connected peer (reader)
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
}

// MARK: - MCSessionDelegate

extension MPCService: MCSessionDelegate {
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
                } else {
                    print("MPCService: Failed to decode DeviceRequest")
                }

            case self.messageTypeResponse:
                if let response = CBORService.shared.decodeResponse(from: Data(payload)) {
                    self.onResponseReceived?(response)
                } else {
                    print("MPCService: Failed to decode DeviceResponse")
                }

            default:
                print("MPCService: Unknown message type: \(messageType)")
            }
        }
    }

    // Required but unused delegate methods
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MPCService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard let session = session else { return }
        print("MPCService: Found peer \(peerID.displayName), sending invitation")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("MPCService: Lost peer \(peerID.displayName)")
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("MPCService: Failed to start browsing: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.error = .connectionFailed(error.localizedDescription)
            self.connectionState = .error(.connectionFailed(error.localizedDescription))
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MPCService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("MPCService: Received invitation from \(peerID.displayName), auto-accepting")
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("MPCService: Failed to start advertising: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.error = .connectionFailed(error.localizedDescription)
            self.connectionState = .error(.connectionFailed(error.localizedDescription))
        }
    }
}
