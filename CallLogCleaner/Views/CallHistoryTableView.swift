import SwiftUI

struct CallHistoryTableView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            // KPI summary strip
            kpiStrip
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(Color(NSColor.windowBackgroundColor))
                .overlay(Divider(), alignment: .bottom)

            // Filter bar
            FilterBarView(filter: $viewModel.filter)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
                .overlay(Divider(), alignment: .bottom)

            // Table
            if viewModel.filteredRecords.isEmpty {
                emptyState
            } else {
                callTable
            }

            // Status bar
            statusBar
                .background(Color(NSColor.windowBackgroundColor))
                .overlay(Divider(), alignment: .top)
        }
    }

    // MARK: - KPI Strip

    private var kpiStrip: some View {
        HStack(spacing: Spacing.md) {
            kpiChip(
                value: "\(viewModel.allRecords.count)",
                label: "Total",
                icon: "phone.fill",
                color: .appPrimary
            )
            kpiChip(
                value: "\(viewModel.missedCount)",
                label: "Missed",
                icon: "phone.down.fill",
                color: .appDanger
            )
            kpiChip(
                value: "\(viewModel.uniqueContactCount)",
                label: "Contacts",
                icon: "person.2.fill",
                color: .callFaceTimeAudio
            )
            kpiChip(
                value: formatDuration(viewModel.totalDuration),
                label: "Total Time",
                icon: "clock.fill",
                color: .appWarning
            )
            Spacer()
        }
    }

    private func kpiChip(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(label)
                    .font(.appCaption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, Spacing.sm + 2)
        .padding(.vertical, Spacing.xs + 1)
        .background(color.opacity(0.07))
        .cornerRadius(Radius.sm)
    }

    // MARK: - Table

    private var callTable: some View {
        Table(viewModel.filteredRecords, selection: $viewModel.selectedIDs, sortOrder: $viewModel.sortOrder) {
            TableColumn("Date", value: \.date) { record in
                Text(record.formattedDate)
                    .font(.appMonoSmall)
                    .foregroundColor(.secondary)
            }
            .width(min: 130, ideal: 145)

            TableColumn("Contact / Number", value: \.address) { record in
                HStack(spacing: Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(avatarColor(for: record.displayName).opacity(0.15))
                            .frame(width: 26, height: 26)
                        Text(avatarInitial(for: record.displayName))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(avatarColor(for: record.displayName))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        if let name = record.name, !name.isEmpty {
                            Text(name)
                                .font(.appBody.weight(.medium))
                                .lineLimit(1)
                            Text(record.address)
                                .font(.appCaption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text(record.address)
                                .font(.appMono)
                        }
                    }
                }
            }
            .width(min: 160, ideal: 200)

            TableColumn("Duration", value: \.duration) { record in
                Text(record.formattedDuration)
                    .font(.appMono)
                    .foregroundColor(record.duration > 0 ? .primary : .secondary)
            }
            .width(60)

            TableColumn("Type") { record in
                callTypeBadge(record.callType)
            }
            .width(min: 90, ideal: 110)

            TableColumn("Dir.") { record in
                Image(systemName: record.direction == .outgoing ? "arrow.up.right.circle.fill" : "arrow.down.left.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(record.direction == .outgoing ? .callPhone : .appSuccess)
                    .help(record.direction == .outgoing ? "Outgoing" : "Incoming")
            }
            .width(36)

            TableColumn("Status") { record in
                if record.isAnswered {
                    PillBadge(text: "Answered", color: .appSuccess, size: .small)
                } else {
                    PillBadge(text: "Missed", color: .appDanger, size: .small)
                }
            }
            .width(min: 70, ideal: 85)
        }
        .contextMenu(forSelectionType: Int64.self) { ids in
            if !ids.isEmpty {
                let records = viewModel.allRecords.filter { ids.contains($0.id) }
                let firstRecord = records.first

                Button("Copy Number") {
                    if let number = firstRecord?.address {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(number, forType: .string)
                    }
                }

                if let name = firstRecord?.displayName {
                    Button("Select All from \"\(name)\"") {
                        let contactIDs = Set(viewModel.allRecords.filter { $0.displayName == name }.map { $0.id })
                        viewModel.selectedIDs.formUnion(contactIDs)
                    }
                }

                Divider()

                Button("Select All Filtered") {
                    viewModel.selectAllFiltered()
                }

                Divider()

                Button(role: .destructive) {
                    viewModel.selectedIDs = ids
                    viewModel.showDeleteConfirmation = true
                } label: {
                    Label("Delete \(ids.count) Record\(ids.count == 1 ? "" : "s")", systemImage: "trash")
                }
            }
        } primaryAction: { ids in
            if let id = ids.first {
                viewModel.inspectedRecord = viewModel.allRecords.first { $0.id == id }
            }
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: Spacing.md) {
            Text("\(viewModel.filteredRecords.count) of \(viewModel.allRecords.count) records")
                .font(.appCaption)
                .foregroundColor(.secondary)

            if viewModel.filter.isActive {
                PillBadge(text: "Filtered", color: .appPrimary, icon: "line.3.horizontal.decrease.circle", size: .small)
            }

            Spacer()

            if viewModel.selectedFilteredCount > 0 {
                Text("\(viewModel.selectedFilteredCount) selected")
                    .font(.appCaption.weight(.medium))
                    .foregroundColor(.appPrimary)
                Button("Deselect All") { viewModel.deselectAll() }
                    .font(.appCaption)
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }

            Button {
                viewModel.selectAllFiltered()
            } label: {
                Text("Select All")
                    .font(.appCaption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.appPrimary)
            .disabled(viewModel.filteredRecords.isEmpty)

            Button {
                viewModel.showSmartSelect = true
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "wand.and.sparkles")
                        .font(.system(size: 10))
                    Text("Smart Select")
                        .font(.appCaption)
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.appPrimary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm + 2)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: viewModel.allRecords.isEmpty ? "phone.slash" : "magnifyingglass",
            title: viewModel.allRecords.isEmpty ? "No Call Records" : "No Matching Records",
            message: viewModel.allRecords.isEmpty
                ? "This backup contains no call history."
                : "Try adjusting your filters.",
            actionTitle: viewModel.filter.isActive ? "Clear Filters" : nil,
            action: viewModel.filter.isActive ? { viewModel.filter.reset() } : nil
        )
    }

    // MARK: - Helpers

    private func callTypeBadge(_ type: CallType) -> some View {
        let (text, color) = callTypeInfo(type)
        return PillBadge(text: text, color: color, size: .small)
    }

    private func callTypeInfo(_ type: CallType) -> (String, Color) {
        switch type {
        case .phone:         return ("Phone", .callPhone)
        case .faceTimeVideo: return ("FT Video", .callFaceTimeVideo)
        case .faceTimeAudio: return ("FT Audio", .callFaceTimeAudio)
        }
    }

    private func avatarInitial(for name: String) -> String {
        String(name.prefix(1).uppercased())
    }

    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [.callPhone, .callFaceTimeVideo, .callFaceTimeAudio, .appWarning, .appSuccess]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
