import Foundation

class BackupScanner {

    static let backupRoot = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/MobileSync/Backup")

    static func findAllBackups() -> [BackupInfo] {
        var backups: [BackupInfo] = []
        let fm = FileManager.default

        guard let contents = try? fm.contentsOfDirectory(
            at: backupRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for url in contents {
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            guard let info = parseBackup(at: url) else { continue }
            backups.append(info)
        }

        return backups.sorted { $0.lastBackupDate > $1.lastBackupDate }
    }

    // MARK: - Private

    private static func parseBackup(at url: URL) -> BackupInfo? {
        let fm = FileManager.default
        let infoURL = url.appendingPathComponent("Info.plist")
        let manifestURL = url.appendingPathComponent("Manifest.plist")

        guard fm.fileExists(atPath: infoURL.path),
              fm.fileExists(atPath: manifestURL.path) else { return nil }

        guard let infoDict = NSDictionary(contentsOf: infoURL) as? [String: Any],
              let manifestDict = NSDictionary(contentsOf: manifestURL) as? [String: Any] else { return nil }

        let deviceName = infoDict["Device Name"] as? String ?? "Unknown Device"
        let deviceModel = infoDict["Product Type"] as? String ?? ""
        let phoneNumber = infoDict["Phone Number"] as? String ?? ""
        let iOSVersion = infoDict["Product Version"] as? String ?? ""
        let isEncrypted = manifestDict["IsEncrypted"] as? Bool ?? false
        let backupDate = manifestDict["Date"] as? Date ?? Date()

        let size = calculateSize(at: url)

        return BackupInfo(
            id: url.lastPathComponent,
            path: url,
            deviceName: deviceName,
            deviceModel: deviceModel,
            phoneNumber: phoneNumber,
            iOSVersion: iOSVersion,
            lastBackupDate: backupDate,
            isEncrypted: isEncrypted,
            backupSize: size
        )
    }

    private static func calculateSize(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}
