import Foundation
import CommonCrypto

class BackupModifier {

    func modifyCallHistory(
        backupPath: URL,
        password: String,
        recordIDsToDelete: [Int64],
        progressCallback: @escaping (String) -> Void
    ) async throws {

        progressCallback("Initializing decryptor…")
        let decryptor = try BackupDecryptor(backupPath: backupPath, password: password)

        progressCallback("Decrypting Manifest.db…")
        let manifestData = try decryptor.decryptManifestDB()
        let manifestReader = try ManifestReader(manifestDBData: manifestData)

        progressCallback("Locating CallHistory.storedata…")
        let relPath = "Library/CallHistoryDB/CallHistory.storedata"
        guard let manifestFile = try manifestReader.findFile(relativePath: relPath) else {
            throw ManifestError.fileNotFound(relPath)
        }

        guard let wrappedKey = manifestFile.encryptionKey else {
            throw BackupError.invalidData("CallHistory file has no encryption key")
        }

        progressCallback("Decrypting CallHistory.storedata…")
        let fileKey = try decryptor.unwrapFileKey(
            protectionClass: manifestFile.protectionClass,
            wrappedKey: wrappedKey
        )
        let callHistoryData = try decryptor.decryptFile(
            fileID: manifestFile.fileID,
            protectionClass: manifestFile.protectionClass,
            wrappedKey: wrappedKey
        )

        progressCallback("Opening database…")
        let tempDir = FileManager.default.temporaryDirectory
        let tempDBURL = tempDir.appendingPathComponent("CallHistory_\(UUID().uuidString).storedata")
        try callHistoryData.write(to: tempDBURL)
        defer { try? FileManager.default.removeItem(at: tempDBURL) }

        // Backup original file
        let origPrefix = String(manifestFile.fileID.prefix(2))
        let origFileURL = backupPath
            .appendingPathComponent(origPrefix)
            .appendingPathComponent(manifestFile.fileID)
        let backupFileURL = origFileURL.appendingPathExtension("backup")
        try? FileManager.default.copyItem(at: origFileURL, to: backupFileURL)

        progressCallback("Deleting \(recordIDsToDelete.count) records…")
        let service = try CallHistoryService(dbPath: tempDBURL)
        try service.deleteRecords(ids: recordIDsToDelete)

        progressCallback("Re-encrypting CallHistory.storedata…")
        let modifiedData = try Data(contentsOf: tempDBURL)
        let reencryptedData = try decryptor.encryptFile(data: modifiedData, fileKey: fileKey)

        // Compute new file hash
        let newFileHash = CryptoHelper.sha1("HomeDomain" + "-" + relPath)
        let newPrefix = String(newFileHash.prefix(2))

        progressCallback("Writing modified backup file…")
        let newFileDir = backupPath.appendingPathComponent(newPrefix)
        try FileManager.default.createDirectory(at: newFileDir, withIntermediateDirectories: true)
        let newFileURL = newFileDir.appendingPathComponent(newFileHash)
        try reencryptedData.write(to: newFileURL)

        progressCallback("Updating Manifest.db…")
        // Only update if fileID changed
        if manifestFile.fileID != newFileHash {
            try manifestReader.updateFileID(old: manifestFile.fileID, new: newFileHash)
            let modifiedManifest = try manifestReader.saveModifiedDB()
            let reencryptedManifest = try decryptor.encryptManifestDB(modifiedManifest)
            let manifestDBURL = backupPath.appendingPathComponent("Manifest.db")
            try reencryptedManifest.write(to: manifestDBURL)

            // Remove old file
            if manifestFile.fileID != newFileHash {
                try? FileManager.default.removeItem(at: origFileURL)
            }
        }

        progressCallback("Done.")
    }
}
