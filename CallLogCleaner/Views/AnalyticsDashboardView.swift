import SwiftUI
import Charts

struct AnalyticsDashboardView: View {
    @ObservedObject var viewModel: AppViewModel

    private var data: AnalyticsData? { viewModel.analyticsData }

    var body: some View {
        ScrollView {
            if let data = data {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    // Time range picker
                    HStack {
                        Text("Analytics")
                            .font(.appTitle.bold())
                        Spacer()
                        Picker("", selection: Binding(
                            get: { viewModel.analyticsTimeRange },
                            set: { viewModel.updateAnalyticsRange($0) }
                        )) {
                            ForEach(TimeRange.allCases) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 340)
                    }
                    .padding(.bottom, Spacing.xs)

                    // Summary stat cards
                    LazyVGrid(columns: [
                        GridItem(.flexible()), GridItem(.flexible()),
                        GridItem(.flexible()), GridItem(.flexible())
                    ], spacing: Spacing.md) {
                        StatCard(
                            title: "Total Calls",
                            value: "\(data.totalCalls)",
                            subtitle: "\(data.incomingCount) in / \(data.outgoingCount) out",
                            icon: "phone.fill",
                            color: .appPrimary
                        )
                        StatCard(
                            title: "Total Duration",
                            value: data.formattedTotalDuration,
                            subtitle: "Avg \(data.formattedAvgDuration)",
                            icon: "clock.fill",
                            color: .callFaceTimeAudio
                        )
                        StatCard(
                            title: "Unique Contacts",
                            value: "\(data.uniqueContacts)",
                            subtitle: nil,
                            icon: "person.2.fill",
                            color: .callFaceTimeVideo
                        )
                        StatCard(
                            title: "Missed Calls",
                            value: "\(data.missedCallCount)",
                            subtitle: String(format: "%.0f%% miss rate", data.missedCallRate * 100),
                            icon: "phone.down.fill",
                            color: .appDanger
                        )
                    }

                    // Call activity over time
                    if !data.dailyCounts.isEmpty {
                        callActivityChart(data.dailyCounts)
                    }

                    // Two-column row
                    HStack(alignment: .top, spacing: Spacing.lg) {
                        if !data.topContacts.isEmpty {
                            topContactsChart(data.topContacts)
                                .frame(maxWidth: .infinity)
                        }
                        if !data.typeDistribution.isEmpty {
                            typeDistributionChart(data.typeDistribution)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    // Heatmap
                    if !data.hourlyCells.isEmpty {
                        heatmapView(data.hourlyCells)
                    }

                    Spacer(minLength: Spacing.xxl)
                }
                .padding(Spacing.xl)
            } else {
                EmptyStateView(
                    icon: "chart.bar.xaxis",
                    title: "No Analytics",
                    message: "Analytics will appear once call records are loaded.",
                    color: .appPrimary
                )
            }
        }
    }

    // MARK: - Call Activity Chart

    private func callActivityChart(_ counts: [DailyCallCount]) -> some View {
        ChartCard(title: "Call Activity", subtitle: "\(viewModel.analyticsTimeRange.rawValue)") {
            Chart(counts) { item in
                AreaMark(
                    x: .value("Date", item.date, unit: .day),
                    y: .value("Calls", item.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.appPrimary.opacity(0.3), Color.appPrimary.opacity(0.03)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", item.date, unit: .day),
                    y: .value("Calls", item.count)
                )
                .foregroundStyle(Color.appPrimary)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: strideCount(for: counts.count))) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                        .foregroundStyle(Color.primary.opacity(0.1))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(.appCaption2)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                        .foregroundStyle(Color.primary.opacity(0.1))
                    AxisValueLabel()
                        .font(.appCaption2)
                }
            }
            .frame(height: 180)
        }
    }

    private func strideCount(for total: Int) -> Int {
        if total <= 14 { return 1 }
        if total <= 45 { return 7 }
        return 14
    }

    // MARK: - Top Contacts Chart

    private func topContactsChart(_ contacts: [ContactCallCount]) -> some View {
        let top = Array(contacts.prefix(8))
        return ChartCard(title: "Top Contacts", subtitle: "By call count") {
            Chart(top) { contact in
                BarMark(
                    x: .value("Calls", contact.count),
                    y: .value("Contact", contact.name)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.appPrimary, Color.appPrimary.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(Radius.xs)
                .annotation(position: .trailing, alignment: .leading) {
                    Text("\(contact.count)")
                        .font(.appCaption2)
                        .foregroundColor(.secondary)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.appCaption2)
                }
            }
            .frame(height: max(180, CGFloat(top.count) * 28))
        }
    }

    // MARK: - Type Distribution

    private func typeDistributionChart(_ distribution: [(label: String, count: Int, color: String)]) -> some View {
        let total = distribution.reduce(0) { $0 + $1.count }
        return ChartCard(title: "Call Types", subtitle: "Distribution") {
            VStack(spacing: Spacing.lg) {
                // Custom donut chart (compatible with macOS 13)
                DonutChartView(segments: distribution.map { (colorForType($0.label), Double($0.count)) })
                    .frame(height: 140)

                // Legend
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(distribution, id: \.label) { item in
                        HStack(spacing: Spacing.sm) {
                            Circle()
                                .fill(colorForType(item.label))
                                .frame(width: 8, height: 8)
                            Text(item.label)
                                .font(.appCaption)
                            Spacer()
                            Text("\(item.count)")
                                .font(.appCaption.weight(.semibold))
                            Text(String(format: "%.0f%%", Double(item.count) / Double(total) * 100))
                                .font(.appCaption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func colorForType(_ label: String) -> Color {
        switch label {
        case "Phone":          return .callPhone
        case "FaceTime Video": return .callFaceTimeVideo
        case "FaceTime Audio": return .callFaceTimeAudio
        default:               return .secondary
        }
    }

    // MARK: - Heatmap

    private func heatmapView(_ cells: [HourlyCell]) -> some View {
        let maxCount = cells.map(\.count).max() ?? 1
        let hours = Array(0..<24)
        let weekdays = [1, 2, 3, 4, 5, 6, 7]
        let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        return ChartCard(title: "Call Heatmap", subtitle: "Calls by hour and day of week") {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Hour labels
                HStack(spacing: 2) {
                    Text("").frame(width: 32)
                    ForEach(hours, id: \.self) { hour in
                        Text(hour % 6 == 0 ? "\(hour)" : "")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Grid
                ForEach(weekdays.indices, id: \.self) { dayIdx in
                    let weekday = weekdays[dayIdx]
                    HStack(spacing: 2) {
                        Text(dayLabels[dayIdx])
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .frame(width: 32, alignment: .leading)
                        ForEach(hours, id: \.self) { hour in
                            let count = cells.first(where: { $0.weekday == weekday && $0.hour == hour })?.count ?? 0
                            let intensity = maxCount > 0 ? Double(count) / Double(maxCount) : 0
                            RoundedRectangle(cornerRadius: 2)
                                .fill(heatColor(intensity: intensity))
                                .frame(maxWidth: .infinity)
                                .frame(height: 16)
                                .help("\(dayLabels[dayIdx]) \(hour):00 — \(count) calls")
                        }
                    }
                }
            }
        }
    }

    private func heatColor(intensity: Double) -> Color {
        if intensity == 0 { return Color.primary.opacity(0.05) }
        return Color.appPrimary.opacity(0.12 + intensity * 0.88)
    }
}
