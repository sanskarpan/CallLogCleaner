import Foundation
import CommonCrypto

enum CryptoError: Error {
    case keyDerivationFailed
    case keyUnwrapFailed
    case decryptionFailed
    case encryptionFailed
    case invalidInput
}

enum CryptoHelper {

    // MARK: - PBKDF2 Two-Stage Key Derivation

    /// Derives the backup KEK using Apple's two-stage PBKDF2:
    /// Stage 1: PBKDF2-SHA256(password, dpsl, dpic) → intermediate key
    /// Stage 2: PBKDF2-SHA1(intermediate, salt, iter) → KEK
    static func deriveBackupKey(password: String, dpsl: Data, dpic: Int,
                                salt: Data, iter: Int) throws -> Data {
        guard let passwordData = password.data(using: .utf8) else {
            throw CryptoError.invalidInput
        }

        // Stage 1: PBKDF2-SHA256
        var stage1Key = Data(count: 32)
        let stage1Result = stage1Key.withUnsafeMutableBytes { stage1Ptr -> Int32 in
            dpsl.withUnsafeBytes { dpslPtr -> Int32 in
                passwordData.withUnsafeBytes { passPtr -> Int32 in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passPtr.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        dpslPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        dpsl.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(dpic),
                        stage1Ptr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }
        guard stage1Result == kCCSuccess else { throw CryptoError.keyDerivationFailed }

        // Stage 2: PBKDF2-SHA1
        var kek = Data(count: 32)
        let stage2Result = kek.withUnsafeMutableBytes { kekPtr -> Int32 in
            salt.withUnsafeBytes { saltPtr -> Int32 in
                stage1Key.withUnsafeBytes { s1Ptr -> Int32 in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        s1Ptr.baseAddress?.assumingMemoryBound(to: Int8.self),
                        stage1Key.count,
                        saltPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                        UInt32(iter),
                        kekPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }
        guard stage2Result == kCCSuccess else { throw CryptoError.keyDerivationFailed }
        return kek
    }

    // MARK: - RFC 3394 AES Key Unwrap

    static func aesKeyUnwrap(wrappedKey: Data, kek: Data) throws -> Data {
        let wrappedKeyLen = wrappedKey.count
        guard wrappedKeyLen >= 16 else { throw CryptoError.invalidInput }
        let unwrappedLen = wrappedKeyLen - 8
        var result = Data(count: unwrappedLen)
        var outLen = unwrappedLen

        let status = result.withUnsafeMutableBytes { resultPtr -> Int32 in
            wrappedKey.withUnsafeBytes { wrappedPtr -> Int32 in
                kek.withUnsafeBytes { kekPtr -> Int32 in
                    CCSymmetricKeyUnwrap(
                        CCWrappingAlgorithm(kCCWRAPAES),
                        CCrfc3394_iv, CCrfc3394_ivLen,
                        kekPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        kek.count,
                        wrappedPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        wrappedKeyLen,
                        resultPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        &outLen
                    )
                }
            }
        }
        guard status == kCCSuccess else { throw CryptoError.keyUnwrapFailed }
        return result.prefix(outLen)
    }

    // MARK: - AES-256-CBC (null IV)

    static func aesDecrypt(data: Data, key: Data) throws -> Data {
        return try aesCrypt(data: data, key: key, operation: CCOperation(kCCDecrypt))
    }

    static func aesEncrypt(data: Data, key: Data) throws -> Data {
        return try aesCrypt(data: data, key: key, operation: CCOperation(kCCEncrypt))
    }

    private static func aesCrypt(data: Data, key: Data, operation: CCOperation) throws -> Data {
        let iv = Data(count: kCCBlockSizeAES128)  // null IV
        let bufferSize = data.count + kCCBlockSizeAES128
        var outBuffer = Data(count: bufferSize)
        var outLen = 0

        let status = outBuffer.withUnsafeMutableBytes { outPtr -> CCCryptorStatus in
            data.withUnsafeBytes { dataPtr -> CCCryptorStatus in
                key.withUnsafeBytes { keyPtr -> CCCryptorStatus in
                    iv.withUnsafeBytes { ivPtr -> CCCryptorStatus in
                        CCCrypt(
                            operation,
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress, key.count,
                            ivPtr.baseAddress,
                            dataPtr.baseAddress, data.count,
                            outPtr.baseAddress, bufferSize,
                            &outLen
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else {
            throw operation == CCOperation(kCCDecrypt) ? CryptoError.decryptionFailed : CryptoError.encryptionFailed
        }
        return outBuffer.prefix(outLen)
    }

    // MARK: - SHA1

    static func sha1(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        return sha1(data)
    }

    static func sha1(_ data: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes { ptr in
            _ = CC_SHA1(ptr.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
