import Foundation
import SwiftUI

// MARK: - AppTab
enum AppTab: String, CaseIterable, Identifiable {
    case records   = "Records"
    case analytics = "Analytics"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .records:   return "list.bullet.rectangle"
        case .analytics: return "chart.bar.xaxis"
        }
    }
}

// MARK: - AppState
enum AppState: Equatable {
    case idle
    case loadingBackups
    case awaitingPassword(BackupInfo)
    case loadingCallHistory
    case ready
    case deleting(progress: String)
    case done(deletedCount: Int)
    case error(String)

    static func == (lhs: AppState, rhs: AppState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loadingBackups, .loadingBackups),
             (.loadingCallHistory, .loadingCallHistory), (.ready, .ready):
            return true
        case (.awaitingPassword(let a), .awaitingPassword(let b)): return a == b
        case (.deleting(let a), .deleting(let b)): return a == b
        case (.done(let a), .done(let b)): return a == b
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - AppViewModel
@MainActor
class AppViewModel: ObservableObject {

    // MARK: Core state
    @Published var backups: [BackupInfo] = []
    @Published var selectedBackup: BackupInfo?
    @Published var state: AppState = .idle

    // MARK: Call records
    @Published var allRecords: [CallRecord] = []
    @Published var filter = FilterCriteria()
    @Published var selectedIDs: Set<Int64> = []
    @Published var sortOrder: [KeyPathComparator<CallRecord>] = [.init(\.date, order: .reverse)]

    // MARK: UI state
    @Published var selectedTab: AppTab = .records
    @Published var analyticsTimeRange: TimeRange = .month
    @Published var analyticsData: AnalyticsData?
    @Published var showExport = false
    @Published var showSettings = false
    @Published var showSmartSelect = false
    @Published var showDeleteConfirmation = false
    @Published var showInspector = false
    @Published var inspectedRecord: CallRecord?

    // MARK: Helpers
    let toastManager = ToastManager()
    var currentPassword: String = ""

    // MARK: - Computed

    var filteredRecords: [CallRecord] {
        let filtered = allRecords.filter { filter.matches($0) }
        return filtered.sorted(using: sortOrder)
    }

    var selectedFilteredCount: Int {
        let filteredIDs = Set(filteredRecords.map(\.id))
        return selectedIDs.intersection(filteredIDs).count
    }

    var totalDuration: TimeInterval {
        allRecords.reduce(0) { $0 + $1.duration }
    }

    var missedCount: Int {
        allRecords.filter { !$0.isAnswered }.count
    }

    var uniqueContactCount: Int {
        Set(allRecords.map { $0.displayName }).count
    }

    // MARK: - Backup Scanning

    func scanBackups() {
        state = .loadingBackups
        Task {
            let found = BackupScanner.findAllBackups()
            backups = found
            state = .idle
        }
    }

    func selectBackup(_ backup: BackupInfo) {
        selectedBackup = backup
        if !backup.isEncrypted {
            state = .error("This backup is unencrypted. Call history is only available in encrypted backups. Enable encryption in Finder and try again.")
            return
        }
        state = .awaitingPassword(backup)
    }

    // MARK: - Load Call History

    func loadBackup(_ backup: BackupInfo, password: String) async {
        state = .loadingCallHistory
        currentPassword = password
        do {
            let decryptor = try BackupDecryptor(backupPath: backup.path, password: password)
            let manifestData = try decryptor.decryptManifestDB()
            let manifestReader = try ManifestReader(manifestDBData: manifestData)

            let relPath = "Library/CallHistoryDB/CallHistory.storedata"
            guard let manifestFile = try manifestReader.findFile(relativePath: relPath) else {
                state = .error("No call history found in this backup.")
                return
            }
            guard let wrappedKey = manifestFile.encryptionKey else {
                state = .error("CallHistory file has no encryption key.")
                return
            }
            let callHistoryData = try decryptor.decryptFile(
                fileID: manifestFile.fileID,
                protectionClass: manifestFile.protectionClass,
                wrappedKey: wrappedKey
            )
            let tempDir = FileManager.default.temporaryDirectory
            let tempDBURL = tempDir.appendingPathComponent("CallHistory_temp_\(UUID().uuidString).storedata")
            try callHistoryData.write(to: tempDBURL)
            defer { try? FileManager.default.removeItem(at: tempDBURL) }

            let service = try CallHistoryService(dbPath: tempDBURL)
            let records = try service.loadAllRecords()

            allRecords = records
            selectedIDs = []
            filter.reset()
            selectedTab = .records
            state = .ready
            computeAnalytics()
            toastManager.show("Loaded \(records.count) call records", style: .success)
        } catch BackupError.wrongPassword {
            currentPassword = ""
            state = .awaitingPassword(backup)
            toastManager.show("Incorrect password. Please try again.", style: .error)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    // MARK: - Analytics

    func computeAnalytics() {
        guard !allRecords.isEmpty else { analyticsData = nil; return }
        let records = allRecords
        let range = analyticsTimeRange
        Task.detached(priority: .userInitiated) {
            let data = AnalyticsEngine.compute(records: records, timeRange: range)
            await MainActor.run { self.analyticsData = data }
        }
    }

    func updateAnalyticsRange(_ range: TimeRange) {
        analyticsTimeRange = range
        computeAnalytics()
    }

    // MARK: - Selection

    func selectAllFiltered() {
        let ids = Set(filteredRecords.map(\.id))
        selectedIDs.formUnion(ids)
    }

    func deselectAll() {
        selectedIDs.removeAll()
    }

    func toggleSelection(_ id: Int64) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

    // MARK: - Deletion

    func deleteSelected() async {
        guard let backup = selectedBackup, !selectedIDs.isEmpty else { return }
        let idsToDelete = Array(selectedIDs)
        let count = idsToDelete.count
        let modifier = BackupModifier()
        do {
            try await modifier.modifyCallHistory(
                backupPath: backup.path,
                password: currentPassword,
                recordIDsToDelete: idsToDelete
            ) { [weak self] progress in
                Task { @MainActor in self?.state = .deleting(progress: progress) }
            }
            allRecords.removeAll { idsToDelete.contains($0.id) }
            selectedIDs.removeAll()
            computeAnalytics()
            state = .done(deletedCount: count)
        } catch {
            state = .error(error.localizedDescription)
            toastManager.show("Deletion failed: \(error.localizedDescription)", style: .error)
        }
    }

    // MARK: - Reset

    func resetToBackupSelection() {
        allRecords = []
        selectedIDs = []
        selectedBackup = nil
        filter.reset()
        state = .idle
        currentPassword = ""
        analyticsData = nil
        selectedTab = .records
        showExport = false
        showSmartSelect = false
        inspectedRecord = nil
    }
}
