import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultExportFormat") private var defaultExportFormat = "CSV"
    @AppStorage("showInspectorByDefault") private var showInspector = false
    @AppStorage("analyticsDefaultRange") private var analyticsRange = "30 Days"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.appTitle2)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.xl)
            .sectionDivider()

            Form {
                Section("Export") {
                    Picker("Default Format", selection: $defaultExportFormat) {
                        ForEach(ExportFormat.allCases) { f in
                            Text(f.rawValue).tag(f.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }

                Section("Analytics") {
                    Picker("Default Time Range", selection: $analyticsRange) {
                        ForEach(TimeRange.allCases) { r in
                            Text(r.rawValue).tag(r.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 360)
                }

                Section("Interface") {
                    Toggle("Show Call Inspector by Default", isOn: $showInspector)
                        .toggleStyle(.switch)
                }

                Section("About") {
                    HStack(spacing: Spacing.lg) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Radius.md)
                                .fill(Color.appPrimary.opacity(0.12))
                                .frame(width: 56, height: 56)
                            Image(systemName: "phone.fill.arrow.down.left")
                                .font(.system(size: 24))
                                .foregroundColor(.appPrimary)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("CallLog Cleaner")
                                .font(.appTitle2)
                            Text("Version 1.0.0")
                                .font(.appCaption)
                                .foregroundColor(.secondary)
                            Text("Reads and edits call history in encrypted iPhone backups. No data leaves your Mac.")
                                .font(.appCaption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, Spacing.sm)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, Spacing.md)
        }
        .frame(width: 480, height: 420)
        .background(Color.appBackground)
    }
}
