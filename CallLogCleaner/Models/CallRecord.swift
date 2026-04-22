import Foundation

struct CallRecord: Identifiable, Equatable {
    let id: Int64
    let date: Date
    let address: String
    let name: String?
    let duration: TimeInterval
    let callType: CallType
    let direction: CallDirection
    let isAnswered: Bool
    let isoCountryCode: String?
    var isSelected: Bool = false

    static func == (lhs: CallRecord, rhs: CallRecord) -> Bool {
        lhs.id == rhs.id
    }

    var formattedDuration: String {
        if duration < 1 { return "—" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var displayName: String {
        name?.isEmpty == false ? name! : address
    }
}

enum CallType: Int, CaseIterable {
    case phone = 1
    case faceTimeVideo = 8
    case faceTimeAudio = 16

    var label: String {
        switch self {
        case .phone: return "Phone"
        case .faceTimeVideo: return "FaceTime Video"
        case .faceTimeAudio: return "FaceTime Audio"
        }
    }
}

enum CallDirection: Equatable {
    case incoming
    case outgoing
}
