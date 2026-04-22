# CallLogCleaner

A macOS app that lets you view, filter, and permanently delete call records from encrypted iPhone backups — without a jailbreak, without iCloud, and without Apple's permission.

> **How it works in one sentence:** Your Mac already has a full copy of your iPhone's call history sitting in an encrypted backup. CallLogCleaner decrypts it, lets you surgically remove whatever you want, re-encrypts it, and puts it back. Restore the backup in Finder and your phone reflects the changes.

---

## Features

### Core
- **Automatic backup discovery** — scans `~/Library/Application Support/MobileSync/Backup/` for all encrypted iPhone backups, no manual path needed
- **Full backup decryption** — two-stage PBKDF2 key derivation, RFC 3394 AES key unwrap, AES-256-CBC file decryption — pure CommonCrypto, zero external packages
- **Non-destructive workflow** — original encrypted file is backed up before any modification; the backup is only updated after successful re-encryption

### Call Log Table
- Sortable, multi-column `Table` view (Date, Contact, Duration, Type, Direction, Status)
- Avatar initials with deterministically hashed accent colour per contact
- Pill badges for call type (Phone / FaceTime Video / FaceTime Audio) and answered/missed status
- Right-click context menus: copy number, select all from contact, select all filtered, delete selection

### Filtering
- Full-text search across phone number and contact name
- Date range picker (from / to)
- Call type filter chips (Phone / FaceTime Video / FaceTime Audio)
- Direction filter (All / Incoming / Outgoing)
- Missed-only toggle
- Dismissible active-filter chips for at-a-glance visibility

### Smart Selection
Five intelligent bulk-select modes accessed via the toolbar:
| Mode | Logic |
|------|-------|
| Missed Calls | All unanswered incoming calls |
| By Contact | All calls matching a name or number |
| Short Calls | All calls under a configurable duration threshold (0–60 s) |
| Duplicates | Same number within ±60 s — keeps earliest, marks the rest |
| By Call Type | Any combination of Phone / FaceTime Video / FaceTime Audio |

### Analytics Dashboard
- **Call activity** — area + line chart, calls per day, selectable time ranges (7 d / 30 d / 90 d / All)
- **Top contacts** — horizontal bar chart, top 8 contacts by call count
- **Call type distribution** — donut chart (Phone / FaceTime Video / FaceTime Audio)
- **Heatmap** — 7 × 24 grid of weekday × hour showing call density

### Export
- Scope: all records / filtered records / selected records
- Formats: CSV (RFC 4180, 8 columns) or JSON (pretty-printed array)
- Optional date range override and answered/missed toggles
- Saves via native `NSSavePanel`

---

## Requirements

| Requirement | Value |
|-------------|-------|
| macOS | 13.0 Ventura or later |
| Xcode | 15.0 or later |
| iPhone backup | **Encrypted** (password-protected) backup created via Finder |

> **Why encrypted only?** Apple only stores `CallHistory.storedata` in encrypted backups. Unencrypted backups do not include this file.

---

## Building

```bash
git clone https://github.com/sanskarpan/CallLogCleaner.git
cd CallLogCleaner
open CallLogCleaner.xcodeproj
```

Press `Cmd+R` in Xcode to build and run. No package dependencies to resolve — the project uses only system frameworks (`Foundation`, `SwiftUI`, `AppKit`, `SQLite3`, `CommonCrypto`, `Charts`).

### Command-line build

```bash
xcodebuild -project CallLogCleaner.xcodeproj \
           -scheme CallLogCleaner \
           -configuration Release \
           build
```

### Type-check only (no Xcode required)

```bash
SDK=$(xcrun --sdk macosx --show-sdk-path)
xcrun swiftc -typecheck -sdk "$SDK" -target arm64-apple-macosx13.0 \
  CallLogCleaner/**/*.swift CallLogCleaner/*.swift
```

---

## Usage

1. **Create an encrypted iPhone backup** in Finder (iPhone → General → Back Up Now, with "Encrypt local backup" enabled)
2. **Launch CallLogCleaner** — it auto-discovers all backups in the sidebar
3. **Click your backup** → enter the backup password when prompted
4. **Browse, filter, and select** the call records you want to remove
5. **Click Delete Selected** → review the confirmation sheet → confirm
6. **Restore the backup** to your iPhone via Finder (General → Restore Backup)

---

## Project Structure

```
CallLogCleaner/
├── CallLogCleaner.xcodeproj/
│   └── project.pbxproj
└── CallLogCleaner/
    ├── CallLogCleanerApp.swift       # @main entry point
    ├── AppViewModel.swift            # MVVM: all published state + intent methods
    ├── DesignSystem.swift            # colour tokens, typography, spacing, shadows
    ├── Info.plist
    ├── CallLogCleaner.entitlements   # sandbox disabled
    ├── Models/
    │   ├── BackupInfo.swift          # device/backup metadata
    │   ├── CallRecord.swift          # single ZCALLRECORD row
    │   └── FilterCriteria.swift      # composable filter state
    ├── Services/
    │   ├── BackupScanner.swift       # discovers backups on disk
    │   ├── BackupDecryptor.swift     # BackupKeyBag TLV → class keys → AES-CBC
    │   ├── ManifestReader.swift      # Manifest.db queries + binary plist parsing
    │   ├── CallHistoryService.swift  # SQLite R/W on CallHistory.storedata
    │   ├── BackupModifier.swift      # orchestrates extract → edit → re-pack
    │   ├── AnalyticsEngine.swift     # stateless analytics computation
    │   └── ExportService.swift       # CSV/JSON export + NSSavePanel
    ├── Utilities/
    │   ├── SQLiteDatabase.swift      # thin SQLite3 C-API wrapper
    │   └── CryptoHelper.swift        # PBKDF2, AES-CBC, RFC 3394, SHA-1
    ├── Components/
    │   ├── VisualEffectView.swift    # NSVisualEffectView SwiftUI wrapper
    │   ├── StatCard.swift            # KPI card
    │   ├── ToastView.swift           # slide-in notification system
    │   ├── ChartCard.swift           # titled chart container
    │   ├── EmptyStateView.swift      # generic empty state
    │   ├── PillBadge.swift           # pill-shaped label
    │   └── DonutChartView.swift      # Path-based donut chart (macOS 13 compat.)
    └── Views/
        ├── ContentView.swift
        ├── BackupListView.swift
        ├── BackupDetailView.swift
        ├── PasswordEntryView.swift
        ├── CallHistoryTableView.swift
        ├── FilterBarView.swift
        ├── DeleteConfirmationView.swift
        ├── RestoreInstructionsView.swift
        ├── AnalyticsDashboardView.swift
        ├── SmartSelectSheet.swift
        ├── ExportView.swift
        └── SettingsView.swift
```

---

## How the Decryption Works (High-Level)

```
Manifest.plist
  └── BackupKeyBag (TLV blob)
        ├── DPSL, DPIC  ─┐
        ├── SALT, ITER   ├──▶ 2-stage PBKDF2 ──▶ KEK
        └── class keys (CLS + WPKY) ──▶ unwrap with KEK via RFC 3394 ──▶ class keys

Manifest.db (encrypted with ManifestKey from Manifest.plist)
  └── Files table
        └── file column (binary plist) ──▶ ProtectionClass + EncryptionKey (wrapped)

Per-file decryption:
  class_key[ProtectionClass] ──▶ unwrap EncryptionKey ──▶ file_key
  file_key + AES-256-CBC (null IV) ──▶ decrypt ──▶ CallHistory.storedata (SQLite)
```

For the full cryptographic specification see [`docs/ENCRYPTION.md`](docs/ENCRYPTION.md).

---

## Architecture

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for a detailed walkthrough of the layer diagram, MVVM pattern, service dependencies, and state machine.

---

## Security

See [`SECURITY.md`](SECURITY.md) for the responsible disclosure policy and data-handling guarantees.

---

## Legal Notice

This tool accesses your **own** backups on your **own** Mac. It does not connect to the internet, does not transmit data anywhere, and does not bypass any Apple server-side systems. Use it only on backups you own and have the right to modify.
