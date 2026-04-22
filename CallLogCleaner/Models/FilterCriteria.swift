import Foundation

struct FilterCriteria {
    var searchText: String = ""
    var dateFrom: Date? = nil
    var dateTo: Date? = nil
    var callTypes: Set<CallType> = []
    var direction: DirectionFilter = .all
    var showMissedOnly: Bool = false

    enum DirectionFilter: String, CaseIterable {
        case all = "All"
        case incoming = "Incoming"
        case outgoing = "Outgoing"
    }

    var isActive: Bool {
        !searchText.isEmpty || dateFrom != nil || dateTo != nil
        || !callTypes.isEmpty || direction != .all || showMissedOnly
    }

    func matches(_ record: CallRecord) -> Bool {
        if !searchText.isEmpty {
            let lower = searchText.lowercased()
            let matchesAddress = record.address.lowercased().contains(lower)
            let matchesName = record.name?.lowercased().contains(lower) ?? false
            if !matchesAddress && !matchesName { return false }
        }
        if let from = dateFrom, record.date < from { return false }
        if let to = dateTo, record.date > to { return false }
        if !callTypes.isEmpty && !callTypes.contains(record.callType) { return false }
        switch direction {
        case .incoming: if record.direction != .incoming { return false }
        case .outgoing: if record.direction != .outgoing { return false }
        case .all: break
        }
        if showMissedOnly && record.isAnswered { return false }
        return true
    }

    mutating func reset() {
        searchText = ""
        dateFrom = nil
        dateTo = nil
        callTypes = []
        direction = .all
        showMissedOnly = false
    }
}
