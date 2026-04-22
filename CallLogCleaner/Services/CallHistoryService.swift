import Foundation

// Core Data epoch: Jan 1, 2001
private let coreDataEpochOffset: TimeInterval = 978307200

class CallHistoryService {
    private var db: SQLiteDatabase

    init(dbPath: URL) throws {
        db = try SQLiteDatabase(path: dbPath.path, readonly: false)
    }

    deinit { db.close() }

    func loadAllRecords() throws -> [CallRecord] {
        let rows = try db.query("""
            SELECT Z_PK, ZDATE, ZADDRESS, ZNAME, ZDURATION,
                   ZCALLTYPE, ZORIGINATED, ZANSWERED, ZISO_COUNTRY_CODE
            FROM ZCALLRECORD
            ORDER BY ZDATE DESC
            """)

        return rows.compactMap { row -> CallRecord? in
            guard let pk = row["Z_PK"] as? Int64 else { return nil }

            let cdDate = row["ZDATE"] as? Double ?? 0
            let date = Date(timeIntervalSince1970: cdDate + coreDataEpochOffset)

            let address = row["ZADDRESS"] as? String ?? ""
            let name = row["ZNAME"] as? String
            let duration = row["ZDURATION"] as? Double ?? 0

            let typeRaw = Int(row["ZCALLTYPE"] as? Int64 ?? 1)
            let callType = CallType(rawValue: typeRaw) ?? .phone

            let originated = (row["ZORIGINATED"] as? Int64 ?? 0) == 1
            let direction: CallDirection = originated ? .outgoing : .incoming

            let answered = (row["ZANSWERED"] as? Int64 ?? 0) == 1
            let country = row["ZISO_COUNTRY_CODE"] as? String

            return CallRecord(
                id: pk,
                date: date,
                address: address,
                name: (name?.isEmpty == false) ? name : nil,
                duration: duration,
                callType: callType,
                direction: direction,
                isAnswered: answered,
                isoCountryCode: country
            )
        }
    }

    func deleteRecords(ids: [Int64]) throws {
        guard !ids.isEmpty else { return }
        try db.executeInTransaction {
            // Build IN clause
            let placeholders = ids.map { _ in "?" }.joined(separator: ",")

            // Delete related handles
            try db.execute(
                "DELETE FROM Z_2REMOTEPARTICIPANTHANDLES WHERE Z_2CALLRECORDS IN (\(placeholders))",
                bind: ids.map { $0 as Any }
            )

            // Delete call records
            try db.execute(
                "DELETE FROM ZCALLRECORD WHERE Z_PK IN (\(placeholders))",
                bind: ids.map { $0 as Any }
            )

            // Clean orphaned handles
            try? db.execute("""
                DELETE FROM ZHANDLE WHERE Z_PK NOT IN (
                    SELECT DISTINCT Z_2REMOTEPARTICIPANTHANDLES FROM Z_2REMOTEPARTICIPANTHANDLES
                )
                """)
        }
    }

    func recordCount() throws -> Int {
        let rows = try db.query("SELECT COUNT(*) as cnt FROM ZCALLRECORD")
        return Int(rows.first?["cnt"] as? Int64 ?? 0)
    }
}
