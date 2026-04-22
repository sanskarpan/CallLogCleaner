import Foundation
import AppKit

enum ExportFormat: String, CaseIterable, Identifiable {
    case csv  = "CSV"
    case json = "JSON"

    var id: String { rawValue }
    var fileExtension: String { rawValue.lowercased() }
    var mimeType: String {
        switch self {
        case .csv:  return "text/csv"
        case .json: return "application/json"
        }
    }
}

enum ExportError: Error, LocalizedError {
    case noRecords
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .noRecords:  return "No records to export."
        case .writeFailed: return "Failed to write export file."
        }
    }
}

struct ExportOptions {
    var format: ExportFormat = .csv
    var includeAnswered: Bool = true
    var includeMissed: Bool = true
    var dateFrom: Date? = nil
    var dateTo: Date? = nil
}

enum ExportService {

    static func export(records: [CallRecord], options: ExportOptions) async throws -> URL {
        let filtered = applyOptions(records, options: options)
        guard !filtered.isEmpty else { throw ExportError.noRecords }

        let data: Data
        let filename: String
        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
            .replacingOccurrences(of: "/", with: "-")

        switch options.format {
        case .csv:
            data = try buildCSV(records: filtered)
            filename = "CallLog_\(dateStr).csv"
        case .json:
            data = try buildJSON(records: filtered)
            filename = "CallLog_\(dateStr).json"
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: tempURL)
        return tempURL
    }

    static func saveWithPanel(records: [CallRecord], options: ExportOptions) async throws {
        let url = try await export(records: records, options: options)

        await MainActor.run {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = url.lastPathComponent
            panel.allowedContentTypes = [options.format == .csv ? .commaSeparatedText : .json]
            panel.begin { response in
                if response == .OK, let dest = panel.url {
                    try? FileManager.default.copyItem(at: url, to: dest)
                }
            }
        }
    }

    // MARK: - Private

    private static func applyOptions(_ records: [CallRecord], options: ExportOptions) -> [CallRecord] {
        records.filter { record in
            if !options.includeAnswered && record.isAnswered { return false }
            if !options.includeMissed && !record.isAnswered { return false }
            if let from = options.dateFrom, record.date < from { return false }
            if let to = options.dateTo, record.date > to { return false }
            return true
        }
    }

    private static func buildCSV(records: [CallRecord]) throws -> Data {
        var lines = ["Date,Time,Name,Number,Duration,Type,Direction,Answered,Country"]
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        for r in records {
            let fields: [String] = [
                dateFormatter.string(from: r.date),
                timeFormatter.string(from: r.date),
                csvEscape(r.name ?? ""),
                csvEscape(r.address),
                String(format: "%.0f", r.duration),
                r.callType.label,
                r.direction == .outgoing ? "Outgoing" : "Incoming",
                r.isAnswered ? "Yes" : "No",
                r.isoCountryCode ?? ""
            ]
            lines.append(fields.joined(separator: ","))
        }
        let csv = lines.joined(separator: "\n")
        guard let data = csv.data(using: .utf8) else { throw ExportError.writeFailed }
        return data
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private static func buildJSON(records: [CallRecord]) throws -> Data {
        let iso = ISO8601DateFormatter()
        let dicts: [[String: Any]] = records.map { r in
            var d: [String: Any] = [
                "id": r.id,
                "date": iso.string(from: r.date),
                "address": r.address,
                "duration": r.duration,
                "callType": r.callType.label,
                "direction": r.direction == .outgoing ? "outgoing" : "incoming",
                "answered": r.isAnswered
            ]
            if let name = r.name { d["name"] = name }
            if let cc = r.isoCountryCode { d["countryCode"] = cc }
            return d
        }
        return try JSONSerialization.data(withJSONObject: dicts, options: [.prettyPrinted, .sortedKeys])
    }
}
