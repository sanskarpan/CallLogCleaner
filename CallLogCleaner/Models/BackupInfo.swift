import Foundation

struct BackupInfo: Identifiable, Equatable {
    let id: String           // backup UDID folder name
    let path: URL
    let deviceName: String
    let deviceModel: String  // e.g. "iPhone15,2"
    let phoneNumber: String
    let iOSVersion: String
    let lastBackupDate: Date
    let isEncrypted: Bool
    let backupSize: Int64    // bytes

    static func == (lhs: BackupInfo, rhs: BackupInfo) -> Bool {
        lhs.id == rhs.id
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: backupSize)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastBackupDate)
    }
}
