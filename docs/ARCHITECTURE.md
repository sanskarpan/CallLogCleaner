# Architecture

CallLogCleaner follows **MVVM** (Model-View-ViewModel) with a service layer beneath the ViewModel. There are no external package dependencies — the entire app runs on system frameworks.

---

## Layer Diagram

```
┌─────────────────────────────────────────────────────┐
│                      Views (SwiftUI)                 │
│  ContentView · BackupListView · BackupDetailView     │
│  CallHistoryTableView · FilterBarView                │
│  PasswordEntryView · DeleteConfirmationView          │
│  RestoreInstructionsView · AnalyticsDashboardView    │
│  SmartSelectSheet · ExportView · SettingsView        │
└──────────────────────┬──────────────────────────────┘
                       │ @ObservedObject / @EnvironmentObject
┌──────────────────────▼──────────────────────────────┐
│               AppViewModel  (@MainActor)             │
│  Published state · intent methods · ToastManager    │
└──┬──────────┬──────────┬──────────┬─────────────────┘
   │          │          │          │
   ▼          ▼          ▼          ▼
BackupScanner BackupModifier AnalyticsEngine ExportService
   │          │
   │    ┌─────┴──────────────┐
   │    │                    │
   ▼    ▼                    ▼
BackupDecryptor         ManifestReader
   │                         │
   ▼                         ▼
CryptoHelper           SQLiteDatabase ◀── CallHistoryService
```

---

## Layers

### Models (`Models/`)
Pure Swift value types — no business logic, no I/O.

| File | Purpose |
|------|---------|
| `BackupInfo` | Device and backup metadata parsed from `Info.plist` / `Manifest.plist` |
| `CallRecord` | A single row from `ZCALLRECORD`; `Identifiable`, `Equatable`, `Hashable` |
| `FilterCriteria` | Composable filter state; `matches(_:)` is the only logic present |

### Utilities (`Utilities/`)
Stateless, reusable low-level primitives.

| File | Purpose |
|------|---------|
| `SQLiteDatabase` | Thin wrapper around the SQLite3 C API — `query`, `execute`, `executeInTransaction` |
| `CryptoHelper` | Two-stage PBKDF2, RFC 3394 AES key unwrap, AES-256-CBC encrypt/decrypt, SHA-1 hashing |

Neither utility has any knowledge of iPhone backups or call records.

### Services (`Services/`)
Stateful service objects that perform I/O and orchestrate work.

| File | Purpose |
|------|---------|
| `BackupScanner` | Scans `~/Library/Application Support/MobileSync/Backup/` for all backup UDIDs |
| `BackupDecryptor` | Parses `BackupKeyBag` TLV, derives KEK, unwraps class keys, decrypts/re-encrypts files |
| `ManifestReader` | Queries `Manifest.db` for file metadata; parses binary plist `file` column |
| `CallHistoryService` | Reads `ZCALLRECORD` from `CallHistory.storedata`; deletes records in a transaction |
| `BackupModifier` | Orchestrates the full modify cycle (see below) |
| `AnalyticsEngine` | Stateless computation — accepts `[CallRecord]` + `TimeRange`, returns `AnalyticsData` |
| `ExportService` | Builds CSV/JSON strings from `[CallRecord]`; saves via `NSSavePanel` |

### ViewModel (`AppViewModel.swift`)
`@MainActor class AppViewModel: ObservableObject`

Single source of truth for all view state. Never accessed off the main actor.

**Published properties (selected):**
```swift
@Published var backups: [BackupInfo]
@Published var state: AppState
@Published var allRecords: [CallRecord]
@Published var filter: FilterCriteria
@Published var selectedIDs: Set<Int64>
@Published var sortOrder: [KeyPathComparator<CallRecord>]
@Published var selectedTab: AppTab
@Published var analyticsData: AnalyticsData?
```

**Intent methods:**
```swift
func scanBackups()
func loadBackup(_ backup: BackupInfo, password: String) async throws
func deleteSelected() async throws
func selectAllFiltered()
func updateAnalyticsRange(_ range: TimeRange)
```

### Components (`Components/`)
Reusable, design-system-aware SwiftUI components with no business logic.

| Component | Purpose |
|-----------|---------|
| `VisualEffectView` | `NSViewRepresentable` wrapper for `NSVisualEffectView` sidebar vibrancy |
| `StatCard` | Animated KPI tile (icon + value + subtitle) |
| `ToastView` + `ToastManager` | Slide-in notifications, 4 styles, 3 s auto-dismiss |
| `ChartCard` | Titled card container for every chart |
| `EmptyStateView` | Animated SF Symbol empty state with optional CTA |
| `PillBadge` | Pill-shaped coloured label |
| `DonutChartView` | `Path.addArc` donut chart — macOS 13 compatible (avoids `SectorMark` which needs macOS 14) |

---

## AppState Machine

```
                   scanBackups()
idle ─────────────────────────────────▶ loadingBackups
                                              │
                                     backups populated
                                              │
                                              ▼
                                   (user clicks backup)
                                              │
                                    isEncrypted == false
                                      ──────────────▶ error("unencrypted backup")
                                              │
                                    isEncrypted == true
                                              │
                                              ▼
                                       awaitingPassword
                                              │
                                    loadBackup(password:)
                                              │
                                    wrong password ──▶ error("Wrong password")
                                              │
                                    correct password
                                              ▼
                                     loadingCallHistory
                                              │
                                     decryption complete
                                              ▼
                                           ready  ◀──────────────────────────┐
                                              │                               │
                                    deleteSelected()                          │
                                              │                               │
                                              ▼                               │
                                     deleting(progress)                       │
                                              │                               │
                                     done (or error)                          │
                                              │                               │
                                              ▼                               │
                                      done(deletedCount)                      │
                                              │                               │
                                    resetToBackupSelection() ─────────────────┘
```

---

## BackupModifier Cycle

The most complex operation in the app — orchestrated by `BackupModifier.modifyCallHistory(...)`:

```
1.  Init BackupDecryptor(backupPath, password)
    └── Parse BackupKeyBag TLV
    └── Derive KEK via 2-stage PBKDF2
    └── Unwrap class keys via RFC 3394
    └── Throw .wrongPassword if none succeed

2.  decryptManifestDB()
    └── Unwrap ManifestKey using class key
    └── AES-256-CBC decrypt → raw SQLite bytes

3.  Init ManifestReader(manifestDBData)
    └── Write bytes to temp file
    └── Open with SQLiteDatabase (read-only)
    └── findFile("Library/CallHistoryDB/CallHistory.storedata")
        └── Parse binary plist in `file` column
        └── Extract ProtectionClass + EncryptionKey (wrapped)

4.  unwrapFileKey(protectionClass, wrappedKey)
    └── Use class_keys[protectionClass]
    └── RFC 3394 unwrap → file_key (32 bytes)

5.  decryptFile(fileID, protectionClass, wrappedKey)
    └── Read {backup}/{fileID[0:2]}/{fileID}
    └── AES-256-CBC(key=file_key, iv=0x00*16) → plaintext SQLite bytes

6.  Write plaintext bytes to tmp file
    Open with CallHistoryService
    DELETE FROM ZCALLRECORD WHERE Z_PK IN (...)
    DELETE FROM Z_2REMOTEPARTICIPANTHANDLES WHERE Z_2CALLRECORDS IN (...)
    Close SQLite

7.  Read modified bytes from tmp file
    encryptFile(modifiedBytes, file_key)
    └── AES-256-CBC(key=file_key, iv=0x00*16, PKCS7) → ciphertext

8.  newFileID = SHA1("HomeDomain-Library/CallHistoryDB/CallHistory.storedata")
       (Note: SHA1 of the *encrypted* bytes — this IS the file hash in the backup)
       Actually: newFileID = random UUID hex — any unique ID works;
       Manifest.db is the lookup table, not the filename

9.  Write ciphertext to {backup}/{newFileID[0:2]}/{newFileID}

10. ManifestReader: UPDATE Files SET fileID = newFileID WHERE fileID = oldFileID
    manifestDBBytes = saveModifiedDB()

11. Re-encrypt manifestDBBytes using ManifestKey
    Write new Manifest.db over old Manifest.db

12. Delete old {backup}/{oldFileID[0:2]}/{oldFileID}
    Clean temp files
```

---

## Design System

All visual constants live in `DesignSystem.swift`:

```swift
Color.appPrimary       // .accentColor
Color.appDanger        // #FF3B30
Color.callPhone        // blue
Color.callFaceTimeVideo // purple
Color.callFaceTimeAudio // teal

Spacing.xs  // 4
Spacing.sm  // 8
Spacing.md  // 12
Spacing.lg  // 16
Spacing.xl  // 24

Radius.xs   // 4
Radius.md   // 10
Radius.lg   // 14

Font.appTitle       // 20 semibold
Font.appBody        // 13 regular
Font.appCaption     // 11 regular
```

Views only reference token names — never raw numbers.

---

## Dependency Graph (compile-time)

```
Views → AppViewModel → Services → Utilities → (system frameworks)
Views → Components   → DesignSystem
Views → Models
```

No circular dependencies. Models have zero imports beyond `Foundation`.
