import Foundation
import Observation
import MultipeerConnectivity

// MARK: - Multipeer Connectivity Service for Data Transfer

/// Service for peer-to-peer data transfer using MultipeerConnectivity.
/// Provides the same callback interface as BLEService, allowing the
/// TransportServiceClient to swap between MPC and BLE transparently.
///
/// MPC uses Bonjour (mDNS) for peer discovery. No chunking is needed —
/// `MCSession.send()` handles arbitrarily large data payloads.
///
/// A 1-byte header distinguishes message types:
/// - `0x01` = DeviceRequest (Reader → Holder)
/// - `0x02` = DeviceResponse (Holder → Reader)
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

    // ┌──────────────────────────────────────────────────────┐
    // │  Browser Mode (Reader/Verifier)                       │
    // │  📖 See: MPCTransport > Step 1                        │
    // └──────────────────────────────────────────────────────┘

    // MARK: - 📋 PASTE: <doc:MPCTransport> Step 1 — startBrowsing + stopBrowsing

    /// Start browsing for nearby peers advertising the mdoc service
    func startBrowsing() {
        // ✏️ Paste your implementation here
        //
        // Steps:
        // 1. Create a new MCSession via createSession()
        // 2. Create MCNearbyServiceBrowser with serviceType
        // 3. Set browser delegate and start browsing
        // 4. Set connectionState to .scanning

        fatalError("Not implemented — Paste code from <doc:MPCTransport> Step 1")
    }

    /// Stop browsing and disconnect
    func stopBrowsing() {
        // ✏️ Paste your implementation here

        fatalError("Not implemented — Paste code from <doc:MPCTransport> Step 1")
    }

    // ┌──────────────────────────────────────────────────────┐
    // │  Advertiser Mode (Holder/Presentment)                 │
    // │  📖 See: MPCTransport > Step 1                        │
    // └──────────────────────────────────────────────────────┘

    // MARK: - 📋 PASTE: <doc:MPCTransport> Step 1 — startAdvertising + stopAdvertising

    /// Start advertising to nearby peers
    func startAdvertising() {
        // ✏️ Paste your implementation here
        //
        // Steps:
        // 1. Create a new MCSession via createSession()
        // 2. Create MCNearbyServiceAdvertiser with serviceType
        // 3. Set advertiser delegate and start advertising
        // 4. Set connectionState to .advertising

        fatalError("Not implemented — Paste code from <doc:MPCTransport> Step 1")
    }

    /// Stop advertising and disconnect
    func stopAdvertising() {
        // ✏️ Paste your implementation here

        fatalError("Not implemented — Paste code from <doc:MPCTransport> Step 1")
    }

    // ┌──────────────────────────────────────────────────────┐
    // │  Send Request / Response                              │
    // │  📖 See: MPCTransport > Step 3                        │
    // └──────────────────────────────────────────────────────┘

    // MARK: - 📋 PASTE: <doc:MPCTransport> Step 3 — sendRequest + sendResponse

    /// Send a DeviceRequest to the connected peer (holder)
    func sendRequest(_ request: DeviceRequest) {
        // ✏️ Paste your implementation here
        //
        // Steps:
        // 1. Get the first connected peer from session
        // 2. Encode request to CBOR via CBORService
        // 3. Prepend messageTypeRequest header byte (0x01)
        // 4. Send via session.send(_:toPeers:with:.reliable)

        fatalError("Not implemented — Paste code from <doc:MPCTransport> Step 3")
    }

    /// Send a DeviceResponse to the connected peer (reader)
    func sendResponse(_ response: DeviceResponse) {
        // ✏️ Paste your implementation here
        //
        // Steps:
        // 1. Get the first connected peer from session
        // 2. Encode response to CBOR via CBORService
        // 3. Prepend messageTypeResponse header byte (0x02)
        // 4. Send via session.send(_:toPeers:with:.reliable)

        fatalError("Not implemented — Paste code from <doc:MPCTransport> Step 3")
    }
}

// ┌──────────────────────────────────────────────────────┐
// │  MCSessionDelegate                                    │
// │  📖 See: MPCTransport > Step 2                        │
// └──────────────────────────────────────────────────────┘

// MARK: - 📋 PASTE: <doc:MPCTransport> Step 2 — MCSessionDelegate

extension MPCService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        // ✏️ Paste your implementation here
        //
        // Steps:
        // 1. Switch on state (.connected, .notConnected, .connecting)
        // 2. Update connectionState on main queue
        // 3. Call onConnected/onDisconnected callbacks

        fatalError("Not implemented — Paste code from <doc:MPCTransport> Step 2")
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // ✏️ Paste your implementation here
        //
        // Steps:
        // 1. Read the first byte as message type header
        // 2. If 0x01 → decode payload as DeviceRequest → call onRequestReceived
        // 3. If 0x02 → decode payload as DeviceResponse → call onResponseReceived

        fatalError("Not implemented — Paste code from <doc:MPCTransport> Step 2")
    }

    // Required but unused delegate methods
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// ┌──────────────────────────────────────────────────────┐
// │  MCNearbyServiceBrowserDelegate                       │
// │  📖 See: MPCTransport > Step 2                        │
// └──────────────────────────────────────────────────────┘

// MARK: - 📋 PASTE: <doc:MPCTransport> Step 2 — MCNearbyServiceBrowserDelegate

extension MPCService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        // ✏️ Paste your implementation here
        //
        // Auto-invite the discovered peer:
        // browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)

        fatalError("Not implemented — Paste code from <doc:MPCTransport> Step 2")
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

// ┌──────────────────────────────────────────────────────┐
// │  MCNearbyServiceAdvertiserDelegate                    │
// │  📖 See: MPCTransport > Step 2                        │
// └──────────────────────────────────────────────────────┘

// MARK: - 📋 PASTE: <doc:MPCTransport> Step 2 — MCNearbyServiceAdvertiserDelegate

extension MPCService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // ✏️ Paste your implementation here
        //
        // Auto-accept the invitation:
        // invitationHandler(true, session)

        fatalError("Not implemented — Paste code from <doc:MPCTransport> Step 2")
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("MPCService: Failed to start advertising: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.error = .connectionFailed(error.localizedDescription)
            self.connectionState = .error(.connectionFailed(error.localizedDescription))
        }
    }
}
