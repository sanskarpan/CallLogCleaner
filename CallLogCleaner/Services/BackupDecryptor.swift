import Foundation
import CommonCrypto

enum BackupError: Error, LocalizedError {
    case wrongPassword
    case manifestNotFound
    case keyBagNotFound
    case manifestKeyNotFound
    case classKeyNotFound(Int)
    case fileNotFound(String)
    case decryptionFailed
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .wrongPassword: return "Wrong backup password."
        case .manifestNotFound: return "Manifest.plist not found."
        case .keyBagNotFound: return "BackupKeyBag not found in Manifest.plist."
        case .manifestKeyNotFound: return "ManifestKey not found in Manifest.plist."
        case .classKeyNotFound(let cls): return "Class key \(cls) not found."
        case .fileNotFound(let f): return "File not found: \(f)"
        case .decryptionFailed: return "Decryption failed."
        case .invalidData(let msg): return "Invalid data: \(msg)"
        }
    }
}

struct ClassKey {
    var cls: Int = 0
    var wrappedKey: Data = Data()
    var unwrappedKey: Data? = nil
}

class BackupDecryptor {
    private let backupPath: URL
    private var classKeys: [Int: ClassKey] = [:]
    private var unwrappedManifestKey: Data?

    private(set) var manifestKeyData: Data = Data()
    private(set) var manifestKeyClass: Int = 0

    init(backupPath: URL, password: String) throws {
        self.backupPath = backupPath

        let manifestPlistURL = backupPath.appendingPathComponent("Manifest.plist")
        guard FileManager.default.fileExists(atPath: manifestPlistURL.path) else {
            throw BackupError.manifestNotFound
        }

        let manifestData = try Data(contentsOf: manifestPlistURL)
        guard let manifest = try? PropertyListSerialization.propertyList(
            from: manifestData, format: nil
        ) as? [String: Any] else {
            throw BackupError.invalidData("Manifest.plist parse failed")
        }

        guard let keyBagData = manifest["BackupKeyBag"] as? Data else {
            throw BackupError.keyBagNotFound
        }

        guard let rawManifestKey = manifest["ManifestKey"] as? Data else {
            throw BackupError.manifestKeyNotFound
        }

        // Parse BackupKeyBag
        try parseKeyBag(keyBagData, password: password)

        // ManifestKey: first 4 bytes = protection class, rest = wrapped key
        guard rawManifestKey.count >= 4 else {
            throw BackupError.invalidData("ManifestKey too short")
        }
        let classBytes = rawManifestKey.prefix(4)
        let cls = Int(classBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
        manifestKeyClass = cls
        manifestKeyData = rawManifestKey.dropFirst(4)

        // Unwrap manifest key
        guard let classKey = classKeys[cls], let kek = classKey.unwrappedKey else {
            throw BackupError.classKeyNotFound(cls)
        }
        unwrappedManifestKey = try CryptoHelper.aesKeyUnwrap(wrappedKey: manifestKeyData, kek: kek)
    }

    // MARK: - Manifest DB

    func decryptManifestDB() throws -> Data {
        let manifestDBURL = backupPath.appendingPathComponent("Manifest.db")
        let encryptedData = try Data(contentsOf: manifestDBURL)
        guard let key = unwrappedManifestKey else { throw BackupError.decryptionFailed }
        return try CryptoHelper.aesDecrypt(data: encryptedData, key: key)
    }

    func encryptManifestDB(_ data: Data) throws -> Data {
        guard let key = unwrappedManifestKey else { throw BackupError.decryptionFailed }
        return try CryptoHelper.aesEncrypt(data: data, key: key)
    }

    // MARK: - File Decryption

    func decryptFile(fileID: String, protectionClass: Int, wrappedKey: Data) throws -> Data {
        guard let classKey = classKeys[protectionClass], let kek = classKey.unwrappedKey else {
            throw BackupError.classKeyNotFound(protectionClass)
        }

        let fileKey = try CryptoHelper.aesKeyUnwrap(wrappedKey: wrappedKey, kek: kek)

        let prefix = String(fileID.prefix(2))
        let fileURL = backupPath.appendingPathComponent(prefix).appendingPathComponent(fileID)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw BackupError.fileNotFound(fileID)
        }

        let encryptedData = try Data(contentsOf: fileURL)
        return try CryptoHelper.aesDecrypt(data: encryptedData, key: fileKey)
    }

    func encryptFile(data: Data, fileKey: Data) throws -> Data {
        return try CryptoHelper.aesEncrypt(data: data, key: fileKey)
    }

    func unwrapFileKey(protectionClass: Int, wrappedKey: Data) throws -> Data {
        guard let classKey = classKeys[protectionClass], let kek = classKey.unwrappedKey else {
            throw BackupError.classKeyNotFound(protectionClass)
        }
        return try CryptoHelper.aesKeyUnwrap(wrappedKey: wrappedKey, kek: kek)
    }

    // MARK: - KeyBag Parsing

    private func parseKeyBag(_ data: Data, password: String) throws {
        var offset = 0
        var dpsl = Data()
        var dpic = 0
        var bagSalt = Data()
        var bagIter = 0

        // First pass: get top-level PBKDF2 params
        var tempOffset = 0
        while tempOffset < data.count - 8 {
            let tag = String(bytes: data[tempOffset..<tempOffset+4], encoding: .ascii) ?? ""
            let len = Int(data[(tempOffset+4)..<(tempOffset+8)].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
            tempOffset += 8
            guard tempOffset + len <= data.count else { break }
            let value = data[tempOffset..<tempOffset+len]
            switch tag {
            case "DPSL": dpsl = Data(value)
            case "DPIC": dpic = Int(value.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
            case "SALT": bagSalt = Data(value)
            case "ITER": bagIter = Int(value.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
            default: break
            }
            tempOffset += len
        }

        guard !dpsl.isEmpty, dpic > 0, !bagSalt.isEmpty, bagIter > 0 else {
            throw BackupError.invalidData("Missing PBKDF2 params in keybag")
        }

        // Derive KEK
        let kek = try CryptoHelper.deriveBackupKey(
            password: password,
            dpsl: dpsl,
            dpic: dpic,
            salt: bagSalt,
            iter: bagIter
        )

        // Second pass: parse class keys and try to unwrap with KEK
        offset = 0
        var currentClass: ClassKey? = nil

        while offset < data.count - 8 {
            let tag = String(bytes: data[offset..<offset+4], encoding: .ascii) ?? ""
            let len = Int(data[(offset+4)..<(offset+8)].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
            offset += 8
            guard offset + len <= data.count else { break }
            let value = data[offset..<offset+len]

            switch tag {
            case "CLS":
                // Save previous class key if valid
                if let prev = currentClass, prev.cls > 0, !prev.wrappedKey.isEmpty {
                    var ck = prev
                    ck.unwrappedKey = try? CryptoHelper.aesKeyUnwrap(wrappedKey: ck.wrappedKey, kek: kek)
                    classKeys[ck.cls] = ck
                }
                var ck = ClassKey()
                ck.cls = Int(value.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
                currentClass = ck
            case "WPKY":
                currentClass?.wrappedKey = Data(value)
            default:
                break
            }
            offset += len
        }

        // Save last class key
        if let prev = currentClass, prev.cls > 0, !prev.wrappedKey.isEmpty {
            var ck = prev
            ck.unwrappedKey = try? CryptoHelper.aesKeyUnwrap(wrappedKey: ck.wrappedKey, kek: kek)
            classKeys[ck.cls] = ck
        }

        // Validate password by checking at least one key unwrapped
        let anyUnwrapped = classKeys.values.contains { $0.unwrappedKey != nil }
        if !anyUnwrapped {
            throw BackupError.wrongPassword
        }
    }
}
