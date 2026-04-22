# CallLogCleaner — Production Upgrade Tickets

## EPIC A: Design System & Visual Overhaul
- [x] **T01** — `DesignSystem.swift`: Color tokens, typography scale, spacing, shadow presets, animation constants
- [x] **T02** — `Components/VisualEffectView.swift`: NSVisualEffectView SwiftUI wrapper (sidebar vibrancy, under-window blur)
- [x] **T03** — `Components/StatCard.swift`: Animated KPI card (icon + value + label + trend)
- [x] **T04** — `Components/ToastView.swift` + `ToastManager`: Slide-in toast notification system with auto-dismiss
- [x] **T05** — `Components/ChartCard.swift`: Reusable card container for charts (title, subtitle, action menu)
- [x] **T06** — `Components/EmptyStateView.swift`: Generic animated empty-state component (icon, title, body, action)
- [x] **T07** — `ContentView.swift` rewrite: Custom toolbar, sheet registration, toast overlay
- [x] **T08** — `BackupListView.swift` rewrite: Card-based sidebar with vibrancy, device icons, encrypted badge
- [x] **T09** — `BackupDetailView.swift` rewrite: Tab switcher (Records | Analytics), state orchestration
- [x] **T10** — `PasswordEntryView.swift` rewrite: Full-bleed gradient hero, animated lock icon
- [x] **T11** — `CallHistoryTableView.swift` rewrite: KPI row, context menus, row hover, improved layout
- [x] **T12** — `FilterBarView.swift` rewrite: Chip-style active filters, collapsible, preset support
- [x] **T13** — `DeleteConfirmationView.swift` rewrite: Risk-styled confirmation with preview list
- [x] **T14** — `RestoreInstructionsView.swift` rewrite: Step-by-step numbered timeline with icons

## EPIC B: Analytics Dashboard
- [x] **T15** — `Services/AnalyticsEngine.swift`: Compute stats, call frequency, top contacts, type distribution, hourly heatmap
- [x] **T16** — `Views/AnalyticsDashboardView.swift`: Full scrollable dashboard with charts
  - Summary row: Total Calls, Total Duration, Unique Contacts, Missed Rate
  - Area+line chart: calls per day (with time range picker: 7d / 30d / 90d / All)
  - Horizontal bar chart: top 10 contacts
  - Donut chart: call type distribution
  - Heatmap grid: calls by hour × weekday

## EPIC C: Export & Data Operations
- [x] **T17** — `Services/ExportService.swift`: Export filtered records to CSV, JSON, vCard list
- [x] **T18** — `Views/ExportView.swift`: Export configuration sheet (format, columns, date range)
- [x] **T19** — `AppViewModel.swift` — export action, analytics integration, toast support

## EPIC D: Smart Selection
- [x] **T20** — `Views/SmartSelectSheet.swift`: Smart-select panel with options:
  - Select by contact
  - Select all missed calls
  - Select calls longer / shorter than duration threshold
  - Select duplicate calls
  - Select by call type

## EPIC E: Settings & Preferences
- [x] **T21** — `Views/SettingsView.swift`: Settings panel (theme override, default export format, retention hint, about)

## EPIC F: AppViewModel Overhaul
- [x] **T22** — `AppViewModel.swift` rewrite: Add analytics state, export flow, toast queue, smart-select, keyboard shortcut handlers

## Build & Verify
- [x] **T23** — `project.pbxproj` update: Add all new source files to build phase + Charts framework
- [x] **T24** — `swiftc -typecheck` clean pass across all files
