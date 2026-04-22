import Foundation

enum ManifestError: Error, LocalizedError {
    case fileNotFound(String)
    case parseFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path): return "File not found in Manifest: \(path)"
        case .parseFailed: return "Failed to parse Manifest.db"
        case .saveFailed: return "Failed to save Manifest.db"
        }
    }
}

struct ManifestFile {
    let fileID: String
    let domain: String
    let flags: Int
    let protectionClass: Int
    let encryptionKey: Data?
}

class ManifestReader {
    private var db: SQLiteDatabase
    private let tempURL: URL

    init(manifestDBData: Data) throws {
        // Write to temp file for SQLite access
        let tempDir = FileManager.default.temporaryDirectory
        tempURL = tempDir.appendingPathComponent("Manifest_\(UUID().uuidString).db")
        try manifestDBData.write(to: tempURL)
        db = try SQLiteDatabase(path: tempURL.path, readonly: false)
    }

    deinit {
        db.close()
        try? FileManager.default.removeItem(at: tempURL)
    }

    func findFile(relativePath: String) throws -> ManifestFile? {
        let rows = try db.query(
            "SELECT fileID, domain, flags, file FROM Files WHERE relativePath = ?",
            bind: [relativePath]
        )
        guard let row = rows.first else { return nil }

        let fileID = row["fileID"] as? String ?? ""
        let domain = row["domain"] as? String ?? ""
        let flags = Int(row["flags"] as? Int64 ?? 0)

        var protectionClass = 0
        var encryptionKey: Data? = nil

        if let fileData = row["file"] as? Data {
            if let parsed = try? parseFilePlist(fileData) {
                protectionClass = parsed.protectionClass
                encryptionKey = parsed.encryptionKey
            }
        }

        return ManifestFile(
            fileID: fileID,
            domain: domain,
            flags: flags,
            protectionClass: protectionClass,
            encryptionKey: encryptionKey
        )
    }

    func updateFileID(old: String, new: String) throws {
        try db.execute("UPDATE Files SET fileID = ? WHERE fileID = ?", bind: [new, old])
    }

    func saveModifiedDB() throws -> Data {
        db.close()
        let data = try Data(contentsOf: tempURL)
        db = try SQLiteDatabase(path: tempURL.path, readonly: false)
        return data
    }

    // MARK: - Private

    private func parseFilePlist(_ data: Data) throws -> (protectionClass: Int, encryptionKey: Data?) {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = plist as? [String: Any] else {
            return (0, nil)
        }

        // The file plist is a protobuf-like structure; try NSKeyedArchiver format first
        // Apple uses a custom binary plist with specific keys
        var protectionClass = 0
        var encryptionKey: Data? = nil

        // Try direct key access (works for some backup versions)
        if let cls = dict["ProtectionClass"] as? Int {
            protectionClass = cls
        }
        if let key = dict["EncryptionKey"] as? Data {
            // First 4 bytes are protection class, rest is wrapped key
            if key.count > 4 {
                encryptionKey = key.dropFirst(4)
                if protectionClass == 0 {
                    protectionClass = Int(key.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
                }
            }
        }

        // Try nested $objects format (NSKeyedArchiver)
        if let objects = dict["$objects"] as? [Any] {
            for obj in objects {
                if let objDict = obj as? [String: Any] {
                    if let cls = objDict["ProtectionClass"] as? Int {
                        protectionClass = cls
                    }
                    if let key = objDict["EncryptionKey"] as? Data, key.count > 4 {
                        encryptionKey = key.dropFirst(4)
                        if protectionClass == 0 {
                            protectionClass = Int(key.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
                        }
                    }
                    if let keyDict = objDict["EncryptionKey"] as? [String: Any],
                       let keyData = keyDict["NS.data"] as? Data, keyData.count > 4 {
                        encryptionKey = keyData.dropFirst(4)
                        if protectionClass == 0 {
                            protectionClass = Int(keyData.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
                        }
                    }
                }
            }
        }

        return (protectionClass, encryptionKey)
    }
}
