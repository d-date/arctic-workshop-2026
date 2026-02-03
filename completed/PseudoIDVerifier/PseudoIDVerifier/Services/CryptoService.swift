import Foundation
import CryptoKit
import SwiftCBOR

// MARK: - Cryptographic Service

/// Service for cryptographic operations (signing and verification)
/// Uses CryptoKit for ECDSA signatures compatible with COSE
class CryptoService {
    static let shared = CryptoService()

    // MARK: - Key Storage

    /// Device private key for signing (in real app, store in Keychain)
    private var devicePrivateKey: P256.Signing.PrivateKey?

    /// Key agreement private key for ECDH
    private var keyAgreementPrivateKey: P256.KeyAgreement.PrivateKey?

    /// Session keys for secure communication
    private var sessionKey: SymmetricKey?

    private init() {
        // Generate or load device key
        loadOrGenerateDeviceKey()
    }

    // MARK: - Key Management

    /// Load existing device key from Keychain or generate new one
    private func loadOrGenerateDeviceKey() {
        // For the workshop, we generate a new key each time
        // In production, you would:
        // 1. Try to load from Keychain
        // 2. If not found, generate and store

        devicePrivateKey = P256.Signing.PrivateKey()
        keyAgreementPrivateKey = P256.KeyAgreement.PrivateKey()
    }

    /// Get the device's public key
    var devicePublicKey: P256.Signing.PublicKey? {
        devicePrivateKey?.publicKey
    }

    /// Get the device's public key as raw bytes
    var devicePublicKeyData: Data? {
        devicePrivateKey?.publicKey.rawRepresentation
    }

    // MARK: - Signing Operations

    /// Sign data using the device's private key
    /// - Parameter data: The data to sign
    /// - Returns: The signature
    func sign(_ data: Data) throws -> Data {
        guard let privateKey = devicePrivateKey else {
            throw CryptoError.keyNotAvailable
        }

        let signature = try privateKey.signature(for: data)
        return signature.derRepresentation
    }

    /// Create a COSE_Sign1 structure (simplified)
    /// - Parameters:
    ///   - payload: The payload to sign
    ///   - additionalData: Additional authenticated data
    /// - Returns: COSE_Sign1 encoded as CBOR
    func createCOSESign1(payload: Data, additionalData: Data? = nil) throws -> Data {
        guard let privateKey = devicePrivateKey else {
            throw CryptoError.keyNotAvailable
        }

        // COSE_Sign1 structure:
        // [
        //   protected_header,    // CBOR map with algorithm ID
        //   unprotected_header,  // empty map
        //   payload,             // The data being signed
        //   signature            // ECDSA signature
        // ]

        // Protected header: algorithm ES256 (-7)
        let protectedHeader: [CBOR: CBOR] = [
            .unsignedInt(1): .negativeInt(6)  // alg: ES256 = -7
        ]
        let protectedBytes = Data(CBOR.map(protectedHeader).encode())

        // Create Sig_structure for signing
        // Sig_structure = [
        //   context: "Signature1",
        //   body_protected: protected_header,
        //   external_aad: bstr (empty or additionalData),
        //   payload: bstr
        // ]
        let sigStructure: [CBOR] = [
            .utf8String("Signature1"),
            .byteString(Array(protectedBytes)),
            .byteString(additionalData.map { Array($0) } ?? []),
            .byteString(Array(payload))
        ]
        let sigStructureBytes = Data(CBOR.array(sigStructure).encode())

        // Sign the Sig_structure
        let signature = try privateKey.signature(for: sigStructureBytes)

        // Build COSE_Sign1 array
        let coseSign1: [CBOR] = [
            .byteString(Array(protectedBytes)),
            .map([:]),  // Empty unprotected header
            .byteString(Array(payload)),
            .byteString(Array(signature.rawRepresentation))
        ]

        return Data(CBOR.array(coseSign1).encode())
    }

    // MARK: - Verification Operations

    /// Verify a signature using the provided public key
    /// - Parameters:
    ///   - signature: The signature to verify
    ///   - data: The original data that was signed
    ///   - publicKey: The public key to verify against
    /// - Returns: true if signature is valid
    func verify(signature: Data, for data: Data, using publicKey: P256.Signing.PublicKey) -> Bool {
        do {
            let ecdsaSignature = try P256.Signing.ECDSASignature(derRepresentation: signature)
            return publicKey.isValidSignature(ecdsaSignature, for: data)
        } catch {
            return false
        }
    }

    /// Verify a COSE_Sign1 structure
    /// - Parameters:
    ///   - coseSign1: CBOR-encoded COSE_Sign1
    ///   - publicKey: The public key to verify against
    /// - Returns: The payload if signature is valid, nil otherwise
    func verifyCOSESign1(_ coseSign1: Data, using publicKey: P256.Signing.PublicKey) -> Data? {
        guard let cbor = try? CBOR.decode(Array(coseSign1)),
              case .array(let coseArray) = cbor,
              coseArray.count >= 4,
              case .byteString(let protectedBytes) = coseArray[0],
              case .byteString(let payloadBytes) = coseArray[2],
              case .byteString(let signatureBytes) = coseArray[3] else {
            return nil
        }

        // Reconstruct Sig_structure
        let sigStructure: [CBOR] = [
            .utf8String("Signature1"),
            .byteString(protectedBytes),
            .byteString([]),  // external_aad
            .byteString(payloadBytes)
        ]
        let sigStructureData = Data(CBOR.array(sigStructure).encode())

        // Verify signature
        do {
            let signature = try P256.Signing.ECDSASignature(rawRepresentation: Data(signatureBytes))
            if publicKey.isValidSignature(signature, for: sigStructureData) {
                return Data(payloadBytes)
            }
        } catch {
            return nil
        }

        return nil
    }

    // MARK: - Session Key Operations

    /// Establish a session key using ECDH
    /// - Parameter peerPublicKeyData: The peer's public key as raw bytes
    /// - Returns: The shared session key
    func establishSessionKey(with peerPublicKeyData: Data) throws -> SymmetricKey {
        guard let privateKey = keyAgreementPrivateKey else {
            throw CryptoError.keyNotAvailable
        }

        // Create peer's public key from raw data
        let peerPublicKey = try P256.KeyAgreement.PublicKey(rawRepresentation: peerPublicKeyData)

        // Perform ECDH to get shared secret
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)

        // Derive session key using HKDF
        let derivedKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("ISO18013-5 Session Key".utf8),
            outputByteCount: 32
        )

        sessionKey = derivedKey
        return derivedKey
    }

    /// Encrypt data using the session key
    /// - Parameter data: The data to encrypt
    /// - Returns: Encrypted data with nonce prepended
    func encrypt(_ data: Data) throws -> Data {
        guard let key = sessionKey else {
            throw CryptoError.sessionKeyNotEstablished
        }

        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }
        return combined
    }

    /// Decrypt data using the session key
    /// - Parameter data: The encrypted data (nonce + ciphertext + tag)
    /// - Returns: Decrypted data
    func decrypt(_ data: Data) throws -> Data {
        guard let key = sessionKey else {
            throw CryptoError.sessionKeyNotEstablished
        }

        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // MARK: - Utility Methods

    /// Generate random bytes
    /// - Parameter count: Number of bytes to generate
    /// - Returns: Random data
    func generateRandomBytes(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }

    /// Generate a challenge nonce for device authentication
    /// - Returns: 16-byte random challenge
    func generateChallenge() -> Data {
        generateRandomBytes(count: 16)
    }

    /// Hash data using SHA-256
    /// - Parameter data: The data to hash
    /// - Returns: SHA-256 digest
    func sha256(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }
}

// MARK: - Error Types

enum CryptoError: LocalizedError {
    case keyNotAvailable
    case sessionKeyNotEstablished
    case invalidPublicKey
    case signatureFailed
    case verificationFailed
    case encryptionFailed
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .keyNotAvailable:
            return "Device key is not available"
        case .sessionKeyNotEstablished:
            return "Session key has not been established"
        case .invalidPublicKey:
            return "Invalid public key format"
        case .signatureFailed:
            return "Failed to create signature"
        case .verificationFailed:
            return "Signature verification failed"
        case .encryptionFailed:
            return "Encryption failed"
        case .decryptionFailed:
            return "Decryption failed"
        }
    }
}
