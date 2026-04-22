import Foundation
import SQLite3

// SQLITE_TRANSIENT is a C macro not available in Swift
private let SQLITE_TRANSIENT_FUNC = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum SQLiteError: Error {
    case openFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
    case bindFailed
    case transactionFailed(String)
}

class SQLiteDatabase {
    private var db: OpaquePointer?
    private let path: String

    init(path: String, readonly: Bool = true) throws {
        self.path = path
        let flags = readonly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
        let result = sqlite3_open_v2(path, &db, flags, nil)
        guard result == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw SQLiteError.openFailed(msg)
        }
    }

    deinit { close() }

    func close() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }

    func query(_ sql: String, bind: [Any] = []) throws -> [[String: Any]] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed(lastError())
        }
        defer { sqlite3_finalize(stmt) }

        try bindParameters(stmt: stmt, params: bind)

        var rows: [[String: Any]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: Any] = [:]
            let columnCount = sqlite3_column_count(stmt)
            for i in 0..<columnCount {
                let name = String(cString: sqlite3_column_name(stmt, i))
                row[name] = columnValue(stmt: stmt, index: i)
            }
            rows.append(row)
        }
        return rows
    }

    func execute(_ sql: String, bind: [Any] = []) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed(lastError())
        }
        defer { sqlite3_finalize(stmt) }
        try bindParameters(stmt: stmt, params: bind)
        let result = sqlite3_step(stmt)
        guard result == SQLITE_DONE || result == SQLITE_ROW else {
            throw SQLiteError.stepFailed(lastError())
        }
    }

    func executeInTransaction(_ block: () throws -> Void) throws {
        try execute("BEGIN TRANSACTION")
        do {
            try block()
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    // MARK: - Private Helpers

    private func bindParameters(stmt: OpaquePointer?, params: [Any]) throws {
        for (i, param) in params.enumerated() {
            let idx = Int32(i + 1)
            let result: Int32
            switch param {
            case let v as Int:
                result = sqlite3_bind_int64(stmt, idx, Int64(v))
            case let v as Int64:
                result = sqlite3_bind_int64(stmt, idx, v)
            case let v as Double:
                result = sqlite3_bind_double(stmt, idx, v)
            case let v as String:
                result = sqlite3_bind_text(stmt, idx, v, -1, SQLITE_TRANSIENT_FUNC)
            case let v as Data:
                result = v.withUnsafeBytes { ptr in
                    sqlite3_bind_blob(stmt, idx, ptr.baseAddress, Int32(v.count), SQLITE_TRANSIENT_FUNC)
                }
            case is NSNull:
                result = sqlite3_bind_null(stmt, idx)
            default:
                result = sqlite3_bind_null(stmt, idx)
            }
            guard result == SQLITE_OK else { throw SQLiteError.bindFailed }
        }
    }

    private func columnValue(stmt: OpaquePointer?, index: Int32) -> Any {
        switch sqlite3_column_type(stmt, index) {
        case SQLITE_INTEGER:
            return sqlite3_column_int64(stmt, index)
        case SQLITE_FLOAT:
            return sqlite3_column_double(stmt, index)
        case SQLITE_TEXT:
            return String(cString: sqlite3_column_text(stmt, index))
        case SQLITE_BLOB:
            if let ptr = sqlite3_column_blob(stmt, index) {
                let count = Int(sqlite3_column_bytes(stmt, index))
                return Data(bytes: ptr, count: count)
            }
            return Data()
        case SQLITE_NULL:
            return NSNull()
        default:
            return NSNull()
        }
    }

    private func lastError() -> String {
        return String(cString: sqlite3_errmsg(db))
    }
}
