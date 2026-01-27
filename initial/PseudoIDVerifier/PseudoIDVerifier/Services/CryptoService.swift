import Foundation
import CryptoKit

// MARK: - Cryptographic Service

/// Service for cryptographic operations (signing and verification)
/// Uses CryptoKit for ECDSA signatures compatible with COSE
class CryptoService {
    static let shared = CryptoService()

    // MARK: - Key Storage

    /// Device private key for signing (in real app, store in Keychain)
    private var devicePrivateKey: P256.Signing.PrivateKey?

    /// Session keys for secure communication
    private var sessionKey: SymmetricKey?

    private init() {
        // Generate or load device key
        loadOrGenerateDeviceKey()
    }

    // MARK: - Key Management

    /// Load existing device key from Keychain or generate new one
    private func loadOrGenerateDeviceKey() {
        // TODO: Implement key loading from Keychain
        //
        // For the workshop, we'll generate a new key each time
        // In production, you would:
        // 1. Try to load from Keychain
        // 2. If not found, generate and store

        devicePrivateKey = P256.Signing.PrivateKey()
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
        // TODO: Implement signing
        //
        // Steps:
        // 1. Ensure device private key exists
        // 2. Create signature using ECDSA
        // 3. Return DER-encoded signature
        //
        // Hint:
        // let signature = try devicePrivateKey.signature(for: data)
        // return signature.derRepresentation

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
        // TODO: Implement COSE_Sign1 creation
        //
        // COSE_Sign1 structure:
        // [
        //   protected_header,    // CBOR map with algorithm ID
        //   unprotected_header,  // empty map
        //   payload,             // The data being signed
        //   signature            // ECDSA signature
        // ]
        //
        // For this workshop, we'll create a simplified version

        fatalError("Not implemented - Complete this in Chapter 3")
    }

    // MARK: - Verification Operations

    /// Verify a signature using the provided public key
    /// - Parameters:
    ///   - signature: The signature to verify
    ///   - data: The original data that was signed
    ///   - publicKey: The public key to verify against
    /// - Returns: true if signature is valid
    func verify(signature: Data, for data: Data, using publicKey: P256.Signing.PublicKey) -> Bool {
        // TODO: Implement signature verification
        //
        // Steps:
        // 1. Create ECDSASignature from DER data
        // 2. Verify using the public key
        //
        // Hint:
        // let ecdsaSignature = try P256.Signing.ECDSASignature(derRepresentation: signature)
        // return publicKey.isValidSignature(ecdsaSignature, for: data)

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
        // TODO: Implement COSE_Sign1 verification
        //
        // Steps:
        // 1. Decode the CBOR structure
        // 2. Extract protected header, payload, and signature
        // 3. Reconstruct the Sig_structure
        // 4. Verify the signature

        fatalError("Not implemented - Complete this in Chapter 3")
    }

    // MARK: - Session Key Operations

    /// Establish a session key using ECDH
    /// - Parameter peerPublicKeyData: The peer's public key as raw bytes
    /// - Returns: The shared session key
    func establishSessionKey(with peerPublicKeyData: Data) throws -> SymmetricKey {
        // TODO: Implement ECDH key agreement
        //
        // Steps:
        // 1. Create P256.KeyAgreement.PrivateKey (or reuse device key for simplicity)
        // 2. Create peer's public key from raw data
        // 3. Perform ECDH to get shared secret
        // 4. Derive session key using HKDF
        //
        // Hint:
        // let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)
        // let sessionKey = sharedSecret.hkdfDerivedSymmetricKey(...)

        fatalError("Not implemented - Complete this in Chapter 3")
    }

    /// Encrypt data using the session key
    /// - Parameter data: The data to encrypt
    /// - Returns: Encrypted data with nonce prepended
    func encrypt(_ data: Data) throws -> Data {
        // TODO: Implement encryption using AES-GCM
        //
        // Hint:
        // let sealedBox = try AES.GCM.seal(data, using: sessionKey)
        // return sealedBox.combined!

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
        // TODO: Implement decryption using AES-GCM
        //
        // Hint:
        // let sealedBox = try AES.GCM.SealedBox(combined: data)
        // return try AES.GCM.open(sealedBox, using: sessionKey)

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
