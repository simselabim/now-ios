import Foundation
import CoreLocation

enum Plan: String, CaseIterable, Identifiable {
    case coffee = "Coffee"
    case walk = "Walk"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case activity = "Activity"

    var id: String { rawValue }
}

enum Intent: String, CaseIterable, Identifiable {
    case friendly = "Friendly"
    case date = "Date"
    case romantic = "Romantic"
    case openMinded = "Open-minded"

    var id: String { rawValue }
}

enum TimeWindow: String, CaseIterable, Identifiable {
    case now = "Now"
    case lunch = "Lunch"
    case afternoon = "Afternoon"
    case evening = "Evening"

    var id: String { rawValue }
}

enum MapPointState: String {
    case unseen
    case viewed
    case interested
    case hiddenToday
    case blocked
}

enum MatchStatus: String {
    case active
    case met
    case cancelled
    case expired
}

enum MeetingStatus: String, CaseIterable, Identifiable {
    case none = "None"
    case onMyWay = "On my way"
    case arrived = "Arrived"
    case delayed = "Delayed"

    var id: String { rawValue }
}

enum MeetingProposalStatus: String {
    case pending
    case accepted
    case rejected
}

enum MessageSender {
    case me
    case them
}

struct UserProfile: Identifiable, Equatable {
    let id: UUID
    let name: String
    let age: Int
    let distance: String
    let plan: Plan
    let intent: Intent
    let occupation: String
    let languages: [String]
    let interests: [String]
    let sharedInterests: [String]
    let prompt: String
}

struct TodayIntent {
    var plan: Plan
    var intent: Intent
    var timeWindow: TimeWindow
}

struct MapPoint: Identifiable, Equatable {
    let id: UUID
    let profile: UserProfile
    let approximateCoordinate: CLLocationCoordinate2D
    var state: MapPointState
    let isMutualMock: Bool

    static func == (lhs: MapPoint, rhs: MapPoint) -> Bool {
        lhs.id == rhs.id
    }
}

struct Match: Identifiable {
    let id: UUID
    let profile: UserProfile
    var status: MatchStatus
    var myFirstLoopSent: Bool
    var theirFirstLoopReceived: Bool
    var meetingStatus: MeetingStatus
}

struct Message: Identifiable {
    let id: UUID
    let sender: MessageSender
    let text: String
    let createdAt: Date
}

struct MeetingProposal: Identifiable {
    let id: UUID
    let matchId: UUID
    var placeName: String
    var coordinate: CLLocationCoordinate2D
    var time: String
    var status: MeetingProposalStatus
}

struct HistoryItem: Identifiable {
    let id: UUID
    let name: String
    let detail: String
    let status: String
}
