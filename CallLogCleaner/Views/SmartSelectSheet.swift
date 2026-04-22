import SwiftUI

struct SmartSelectSheet: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var isPresented: Bool

    @State private var selectedOption: SelectOption = .missedCalls
    @State private var selectedContact: String = ""
    @State private var minDuration: Double = 0
    @State private var maxDuration: Double = 60
    @State private var contactSearch: String = ""

    enum SelectOption: String, CaseIterable {
        case missedCalls   = "All Missed Calls"
        case byContact     = "Calls from Contact"
        case shortCalls    = "Short Calls (< threshold)"
        case duplicates    = "Duplicate Entries"
        case byType        = "By Call Type"
    }

    private var uniqueContacts: [String] {
        let all = Set(viewModel.allRecords.map { $0.displayName })
        return all.sorted().filter {
            contactSearch.isEmpty || $0.localizedCaseInsensitiveContains(contactSearch)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Smart Select")
                        .font(.appTitle2)
                    Text("Select records matching a specific criteria")
                        .font(.appCaption)
                        .foregroundColor(.secondary)
                }
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

            // Options
            HStack(spacing: 0) {
                // Left: option list
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(SelectOption.allCases, id: \.rawValue) { opt in
                        Button {
                            withAnimation(AppAnimation.fast) { selectedOption = opt }
                        } label: {
                            HStack {
                                Text(opt.rawValue)
                                    .font(.appBody)
                                    .foregroundColor(selectedOption == opt ? .white : .primary)
                                Spacer()
                                if selectedOption == opt {
                                    Image(systemName: "chevron.right")
                                        .font(.appCaption2)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm + 2)
                            .background(selectedOption == opt ? Color.appPrimary : Color.clear)
                            .cornerRadius(Radius.sm)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 200)
                .padding(Spacing.md)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Right: configuration
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Group {
                        switch selectedOption {
                        case .missedCalls:
                            missedCallsPanel
                        case .byContact:
                            byContactPanel
                        case .shortCalls:
                            shortCallsPanel
                        case .duplicates:
                            duplicatesPanel
                        case .byType:
                            byTypePanel
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .padding(Spacing.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 300)

            // Footer
            Divider()
            HStack {
                Text("\(viewModel.allRecords.count) total records")
                    .font(.appCaption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.escape)
                Button("Apply Selection") {
                    applySelection()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
            .padding(Spacing.lg)
        }
        .frame(width: 560)
        .background(Color.appBackground)
    }

    // MARK: - Panels

    private var missedCallsPanel: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("Select All Missed Calls", systemImage: "phone.down.fill")
                .font(.appHeadline)
            let count = viewModel.allRecords.filter { !$0.isAnswered }.count
            Text("\(count) missed calls will be selected.")
                .font(.appBody)
                .foregroundColor(.secondary)
        }
    }

    private var byContactPanel: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("Select by Contact", systemImage: "person.crop.circle")
                .font(.appHeadline)
            TextField("Search contacts…", text: $contactSearch)
                .textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(uniqueContacts, id: \.self) { contact in
                        Button {
                            withAnimation(AppAnimation.fast) { selectedContact = contact }
                        } label: {
                            HStack {
                                Text(contact)
                                    .font(.appBody)
                                    .foregroundColor(selectedContact == contact ? .white : .primary)
                                Spacer()
                                if selectedContact == contact {
                                    Image(systemName: "checkmark")
                                        .font(.appCaption)
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs + 2)
                            .background(selectedContact == contact ? Color.appPrimary : Color.clear)
                            .cornerRadius(Radius.xs)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 150)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(Radius.sm)
        }
    }

    private var shortCallsPanel: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("Select Short Calls", systemImage: "timer")
                .font(.appHeadline)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Max duration: \(Int(maxDuration)) seconds")
                    .font(.appBody)
                Slider(value: $maxDuration, in: 5...300, step: 5)
            }
            let count = viewModel.allRecords.filter { $0.duration <= maxDuration }.count
            Text("\(count) calls under \(Int(maxDuration))s will be selected.")
                .font(.appCaption)
                .foregroundColor(.secondary)
        }
    }

    private var duplicatesPanel: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("Select Duplicate Calls", systemImage: "doc.on.doc")
                .font(.appHeadline)
            Text("Selects calls with the same number that occurred within 60 seconds of each other.")
                .font(.appBody)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            let count = findDuplicates().count
            Text("\(count) duplicate records found.")
                .font(.appCaption)
                .foregroundColor(count > 0 ? .appWarning : .secondary)
        }
    }

    private var byTypePanel: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("Select by Call Type", systemImage: "phone.badge.plus")
                .font(.appHeadline)
            ForEach(CallType.allCases, id: \.rawValue) { type in
                let count = viewModel.allRecords.filter { $0.callType == type }.count
                Button {
                    let ids = Set(viewModel.allRecords.filter { $0.callType == type }.map { $0.id })
                    viewModel.selectedIDs.formUnion(ids)
                    isPresented = false
                } label: {
                    HStack {
                        PillBadge(text: type.label, color: callTypeColor(type))
                        Text("\(count) calls")
                            .font(.appCaption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: "plus.circle")
                            .foregroundColor(.appPrimary)
                    }
                    .padding(.vertical, Spacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    private func applySelection() {
        switch selectedOption {
        case .missedCalls:
            let ids = Set(viewModel.allRecords.filter { !$0.isAnswered }.map { $0.id })
            viewModel.selectedIDs.formUnion(ids)
        case .byContact:
            guard !selectedContact.isEmpty else { return }
            let ids = Set(viewModel.allRecords.filter { $0.displayName == selectedContact }.map { $0.id })
            viewModel.selectedIDs.formUnion(ids)
        case .shortCalls:
            let ids = Set(viewModel.allRecords.filter { $0.duration <= maxDuration }.map { $0.id })
            viewModel.selectedIDs.formUnion(ids)
        case .duplicates:
            viewModel.selectedIDs.formUnion(findDuplicates())
        case .byType:
            break // handled inline
        }
    }

    private func findDuplicates() -> Set<Int64> {
        var seen: [String: Date] = [:]
        var dupeIDs: Set<Int64> = []
        let sorted = viewModel.allRecords.sorted { $0.date < $1.date }
        for record in sorted {
            let key = record.address
            if let prev = seen[key], abs(record.date.timeIntervalSince(prev)) < 60 {
                dupeIDs.insert(record.id)
            }
            seen[key] = record.date
        }
        return dupeIDs
    }

    private func callTypeColor(_ type: CallType) -> Color {
        switch type {
        case .phone: return .callPhone
        case .faceTimeVideo: return .callFaceTimeVideo
        case .faceTimeAudio: return .callFaceTimeAudio
        }
    }
}
