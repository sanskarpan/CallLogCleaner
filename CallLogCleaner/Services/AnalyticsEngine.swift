import Foundation

struct DailyCallCount: Identifiable {
    let id: Date
    let date: Date
    let count: Int
}

struct ContactCallCount: Identifiable {
    var id: String { name }
    let name: String
    let count: Int
    let totalDuration: TimeInterval
}

struct HourlyCell: Identifiable {
    var id: String { "\(weekday)-\(hour)" }
    let weekday: Int  // 1=Sun … 7=Sat
    let hour: Int     // 0–23
    let count: Int
}

struct AnalyticsData {
    let totalCalls: Int
    let totalDuration: TimeInterval
    let uniqueContacts: Int
    let missedCallCount: Int
    let missedCallRate: Double
    let incomingCount: Int
    let outgoingCount: Int
    let avgCallDuration: TimeInterval

    let dailyCounts: [DailyCallCount]
    let topContacts: [ContactCallCount]
    let typeDistribution: [(label: String, count: Int, color: String)]
    let hourlyCells: [HourlyCell]

    var formattedTotalDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    var formattedAvgDuration: String {
        let minutes = Int(avgCallDuration) / 60
        let seconds = Int(avgCallDuration) % 60
        return "\(minutes)m \(seconds)s"
    }
}

enum TimeRange: String, CaseIterable, Identifiable {
    case week    = "7 Days"
    case month   = "30 Days"
    case quarter = "90 Days"
    case all     = "All Time"

    var id: String { rawValue }

    func startDate(from reference: Date = Date()) -> Date? {
        let cal = Calendar.current
        switch self {
        case .week:    return cal.date(byAdding: .day, value: -7, to: reference)
        case .month:   return cal.date(byAdding: .day, value: -30, to: reference)
        case .quarter: return cal.date(byAdding: .day, value: -90, to: reference)
        case .all:     return nil
        }
    }
}

enum AnalyticsEngine {
    static func compute(records: [CallRecord], timeRange: TimeRange = .all) -> AnalyticsData {
        let filtered: [CallRecord]
        if let start = timeRange.startDate() {
            filtered = records.filter { $0.date >= start }
        } else {
            filtered = records
        }

        let total = filtered.count
        let totalDuration = filtered.reduce(0) { $0 + $1.duration }
        let missed = filtered.filter { !$0.isAnswered }.count
        let incoming = filtered.filter { $0.direction == .incoming }.count
        let outgoing = filtered.filter { $0.direction == .outgoing }.count

        let uniqueContacts = Set(filtered.map { $0.displayName }).count

        let avgDuration: TimeInterval
        let answeredCalls = filtered.filter { $0.isAnswered && $0.duration > 0 }
        avgDuration = answeredCalls.isEmpty ? 0 : answeredCalls.reduce(0) { $0 + $1.duration } / Double(answeredCalls.count)

        // Daily counts
        let dailyCounts = computeDailyCounts(filtered, timeRange: timeRange)

        // Top contacts (by call count, max 10)
        let contactGroups = Dictionary(grouping: filtered, by: { $0.displayName })
        let topContacts = contactGroups
            .map { (key, calls) in
                ContactCallCount(
                    name: key,
                    count: calls.count,
                    totalDuration: calls.reduce(0) { $0 + $1.duration }
                )
            }
            .sorted { $0.count > $1.count }
            .prefix(10)
            .map { $0 }

        // Type distribution
        let typeGroups = Dictionary(grouping: filtered, by: { $0.callType })
        let typeDistribution: [(label: String, count: Int, color: String)] = [
            (label: "Phone", count: typeGroups[.phone]?.count ?? 0, color: "blue"),
            (label: "FaceTime Video", count: typeGroups[.faceTimeVideo]?.count ?? 0, color: "purple"),
            (label: "FaceTime Audio", count: typeGroups[.faceTimeAudio]?.count ?? 0, color: "teal"),
        ].filter { $0.count > 0 }

        // Hourly heatmap
        let cal = Calendar.current
        var heatmap: [String: Int] = [:]
        for record in filtered {
            let components = cal.dateComponents([.weekday, .hour], from: record.date)
            let key = "\(components.weekday ?? 1)-\(components.hour ?? 0)"
            heatmap[key, default: 0] += 1
        }
        let hourlyCells = heatmap.map { key, count -> HourlyCell in
            let parts = key.split(separator: "-").compactMap { Int($0) }
            return HourlyCell(weekday: parts[0], hour: parts[1], count: count)
        }

        return AnalyticsData(
            totalCalls: total,
            totalDuration: totalDuration,
            uniqueContacts: uniqueContacts,
            missedCallCount: missed,
            missedCallRate: total > 0 ? Double(missed) / Double(total) : 0,
            incomingCount: incoming,
            outgoingCount: outgoing,
            avgCallDuration: avgDuration,
            dailyCounts: dailyCounts,
            topContacts: Array(topContacts),
            typeDistribution: typeDistribution,
            hourlyCells: hourlyCells
        )
    }

    private static func computeDailyCounts(_ records: [CallRecord], timeRange: TimeRange) -> [DailyCallCount] {
        let cal = Calendar.current
        var counts: [Date: Int] = [:]
        for record in records {
            let day = cal.startOfDay(for: record.date)
            counts[day, default: 0] += 1
        }

        // Fill in zero-count days for the range
        var result: [DailyCallCount] = []
        if let startDate = timeRange.startDate() {
            var current = cal.startOfDay(for: startDate)
            let end = cal.startOfDay(for: Date())
            while current <= end {
                result.append(DailyCallCount(id: current, date: current, count: counts[current] ?? 0))
                current = cal.date(byAdding: .day, value: 1, to: current) ?? current
            }
        } else {
            result = counts.sorted { $0.key < $1.key }
                .map { DailyCallCount(id: $0.key, date: $0.key, count: $0.value) }
        }
        return result
    }
}
