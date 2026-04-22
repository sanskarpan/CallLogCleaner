import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var isPresented: Bool

    @State private var options = ExportOptions()
    @State private var isExporting = false
    @State private var exportScope: ExportScope = .filtered

    enum ExportScope: String, CaseIterable {
        case all      = "All Records"
        case filtered = "Filtered Records"
        case selected = "Selected Records"
    }

    private var scopeCount: Int {
        switch exportScope {
        case .all:      return viewModel.allRecords.count
        case .filtered: return viewModel.filteredRecords.count
        case .selected: return viewModel.selectedIDs.count
        }
    }

    private var sourceRecords: [CallRecord] {
        switch exportScope {
        case .all:      return viewModel.allRecords
        case .filtered: return viewModel.filteredRecords
        case .selected: return viewModel.allRecords.filter { viewModel.selectedIDs.contains($0.id) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Export Call Records", systemImage: "square.and.arrow.up")
                    .font(.appTitle2)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.xl)
            .sectionDivider()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    // Scope
                    formSection(title: "Records to Export") {
                        Picker("", selection: $exportScope) {
                            ForEach(ExportScope.allCases, id: \.rawValue) { scope in
                                Text(scope.rawValue).tag(scope)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text("\(scopeCount) records will be exported.")
                            .font(.appCaption)
                            .foregroundColor(.secondary)
                    }

                    // Format
                    formSection(title: "Format") {
                        HStack(spacing: Spacing.md) {
                            ForEach(ExportFormat.allCases) { format in
                                formatButton(format)
                            }
                            Spacer()
                        }
                    }

                    // Filters
                    formSection(title: "Include") {
                        HStack(spacing: Spacing.xl) {
                            Toggle("Answered Calls", isOn: $options.includeAnswered)
                                .toggleStyle(.checkbox)
                            Toggle("Missed Calls", isOn: $options.includeMissed)
                                .toggleStyle(.checkbox)
                        }
                        .font(.appBody)
                    }

                    // Date range
                    formSection(title: "Date Range (optional)") {
                        HStack(spacing: Spacing.lg) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("From").font(.appCaption).foregroundColor(.secondary)
                                HStack {
                                    DatePicker("", selection: Binding(
                                        get: { options.dateFrom ?? Date() },
                                        set: { options.dateFrom = $0 }
                                    ), displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    if options.dateFrom != nil {
                                        Button { options.dateFrom = nil } label: {
                                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("To").font(.appCaption).foregroundColor(.secondary)
                                HStack {
                                    DatePicker("", selection: Binding(
                                        get: { options.dateTo ?? Date() },
                                        set: { options.dateTo = $0 }
                                    ), displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    if options.dateTo != nil {
                                        Button { options.dateTo = nil } label: {
                                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(Spacing.xl)
            }

            Divider()
            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.escape)
                Button {
                    exportRecords()
                } label: {
                    if isExporting {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Export \(scopeCount) Records", systemImage: "square.and.arrow.up")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(scopeCount == 0 || isExporting)
                .keyboardShortcut(.return)
            }
            .padding(Spacing.lg)
        }
        .frame(width: 480)
        .background(Color.appBackground)
    }

    private func formatButton(_ format: ExportFormat) -> some View {
        Button {
            options.format = format
        } label: {
            VStack(spacing: Spacing.sm) {
                Image(systemName: format == .csv ? "tablecells" : "doc.text")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(options.format == format ? .white : .appPrimary)
                Text(format.rawValue)
                    .font(.appCallout.bold())
                    .foregroundColor(options.format == format ? .white : .primary)
                Text(format.fileExtension)
                    .font(.appCaption2)
                    .foregroundColor(options.format == format ? .white.opacity(0.7) : .secondary)
            }
            .frame(width: 100, height: 80)
            .background(options.format == format ? Color.appPrimary : Color.cardBackground)
            .cornerRadius(Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(options.format == format ? Color.clear : Color.primary.opacity(0.1), lineWidth: 1)
            )
            .appShadow(options.format == format ? .card : .subtle)
        }
        .buttonStyle(.plain)
        .animation(AppAnimation.fast, value: options.format)
    }

    private func formSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.appHeadline)
                .foregroundColor(.secondary)
            content()
        }
    }

    private func exportRecords() {
        options.format = options.format  // capture
        let records = sourceRecords
        let opts = options
        isExporting = true
        Task {
            do {
                try await ExportService.saveWithPanel(records: records, options: opts)
                await MainActor.run {
                    isExporting = false
                    isPresented = false
                    viewModel.toastManager.show("Export complete!", style: .success)
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    viewModel.toastManager.show(error.localizedDescription, style: .error)
                }
            }
        }
    }
}
