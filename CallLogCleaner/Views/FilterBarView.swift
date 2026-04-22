import SwiftUI

struct FilterBarView: View {
    @Binding var filter: FilterCriteria
    @State private var isExpanded = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Primary row
            HStack(spacing: Spacing.sm) {
                // Search field
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(searchFocused ? .appPrimary : .secondary)
                    TextField("Search by name or number\u{2026}", text: $filter.searchText)
                        .textFieldStyle(.plain)
                        .font(.appBody)
                        .focused($searchFocused)
                    if !filter.searchText.isEmpty {
                        Button { filter.searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .stroke(searchFocused ? Color.appPrimary.opacity(0.5) : Color.primary.opacity(0.08), lineWidth: 1)
                        )
                )
                .frame(minWidth: 200, maxWidth: 300)

                Divider().frame(height: 20)

                // Direction segmented
                Picker("", selection: $filter.direction) {
                    Text("All").tag(FilterCriteria.DirectionFilter.all)
                    Image(systemName: "arrow.down.left").tag(FilterCriteria.DirectionFilter.incoming)
                    Image(systemName: "arrow.up.right").tag(FilterCriteria.DirectionFilter.outgoing)
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
                .help("Filter by direction")

                // Missed toggle
                Toggle(isOn: $filter.showMissedOnly) {
                    HStack(spacing: 3) {
                        Image(systemName: "phone.down.fill").font(.system(size: 10))
                        Text("Missed").font(.appCaption)
                    }
                }
                .toggleStyle(.button)
                .tint(.appDanger)
                .controlSize(.small)

                // More filters toggle
                Button {
                    withAnimation(AppAnimation.spring) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: isExpanded ? "chevron.up" : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 11))
                        Text("More")
                            .font(.appCaption)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs + 2)
                    .background(
                        Capsule()
                            .fill(isExpanded ? Color.appPrimary.opacity(0.12) : Color.clear)
                    )
                    .foregroundColor(isExpanded ? .appPrimary : .secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                // Active filter chips
                if filter.isActive {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.xs) {
                            activeChips
                        }
                    }
                    .frame(maxWidth: 200)

                    Button {
                        withAnimation(AppAnimation.spring) { filter.reset() }
                    } label: {
                        Text("Clear")
                            .font(.appCaption)
                            .foregroundColor(.appDanger)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm + 2)

            // Expanded row
            if isExpanded {
                Divider()
                HStack(spacing: Spacing.lg) {
                    // Date From
                    HStack(spacing: Spacing.xs) {
                        Text("From").font(.appCaption).foregroundColor(.secondary)
                        DatePicker("", selection: Binding(
                            get: { filter.dateFrom ?? Date() },
                            set: { filter.dateFrom = $0 }
                        ), displayedComponents: .date)
                        .labelsHidden().datePickerStyle(.compact).frame(width: 110)
                        if filter.dateFrom != nil {
                            Button { filter.dateFrom = nil } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                            }.buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: Spacing.xs) {
                        Text("To").font(.appCaption).foregroundColor(.secondary)
                        DatePicker("", selection: Binding(
                            get: { filter.dateTo ?? Date() },
                            set: { filter.dateTo = $0 }
                        ), displayedComponents: .date)
                        .labelsHidden().datePickerStyle(.compact).frame(width: 110)
                        if filter.dateTo != nil {
                            Button { filter.dateTo = nil } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                            }.buttonStyle(.plain)
                        }
                    }

                    Divider().frame(height: 20)

                    // Call type chips
                    Text("Type:").font(.appCaption).foregroundColor(.secondary)
                    ForEach(CallType.allCases, id: \.rawValue) { type in
                        callTypeToggle(type)
                    }

                    Spacer()
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
            }
        }
    }

    // MARK: - Active filter chips

    @ViewBuilder
    private var activeChips: some View {
        if !filter.searchText.isEmpty {
            filterChip("\"\(filter.searchText)\"", color: .appPrimary) {
                filter.searchText = ""
            }
        }
        if filter.showMissedOnly {
            filterChip("Missed only", color: .appDanger) {
                filter.showMissedOnly = false
            }
        }
        if filter.direction != .all {
            filterChip(filter.direction.rawValue, color: .appPrimary) {
                filter.direction = .all
            }
        }
        if let from = filter.dateFrom {
            filterChip("From \(shortDate(from))", color: .callFaceTimeAudio) {
                filter.dateFrom = nil
            }
        }
        if let to = filter.dateTo {
            filterChip("To \(shortDate(to))", color: .callFaceTimeAudio) {
                filter.dateTo = nil
            }
        }
    }

    private func filterChip(_ text: String, color: Color, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 3) {
            Text(text).font(.appCaption2)
            Button(action: onRemove) {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
            }.buttonStyle(.plain)
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .cornerRadius(Radius.pill)
    }

    private func callTypeToggle(_ type: CallType) -> some View {
        let isOn = filter.callTypes.contains(type)
        let color = callTypeColor(type)
        return Button {
            if isOn { filter.callTypes.remove(type) } else { filter.callTypes.insert(type) }
        } label: {
            Text(shortTypeName(type))
                .font(.appCaption)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(isOn ? color.opacity(0.15) : Color.clear)
                .foregroundColor(isOn ? color : .secondary)
                .cornerRadius(Radius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .stroke(isOn ? color.opacity(0.4) : Color.primary.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func callTypeColor(_ type: CallType) -> Color {
        switch type {
        case .phone:         return .callPhone
        case .faceTimeVideo: return .callFaceTimeVideo
        case .faceTimeAudio: return .callFaceTimeAudio
        }
    }

    private func shortTypeName(_ type: CallType) -> String {
        switch type {
        case .phone:         return "Phone"
        case .faceTimeVideo: return "FT Video"
        case .faceTimeAudio: return "FT Audio"
        }
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}
