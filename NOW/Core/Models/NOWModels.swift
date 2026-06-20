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

struct MeetingSuggestion {
    let placeName: String
    let coordinate: CLLocationCoordinate2D
    let time: String
    let descriptor: String
}

extension Plan {
    var primaryMeetingSuggestion: MeetingSuggestion {
        switch self {
        case .coffee:
            return MeetingSuggestion(
                placeName: "Cafe Luna",
                coordinate: CLLocationCoordinate2D(latitude: -8.6504, longitude: 115.1387),
                time: "13:30",
                descriptor: "public cafe"
            )
        case .walk:
            return MeetingSuggestion(
                placeName: "City Garden Gate",
                coordinate: CLLocationCoordinate2D(latitude: -8.6521, longitude: 115.1358),
                time: "16:00",
                descriptor: "open public walk"
            )
        case .lunch:
            return MeetingSuggestion(
                placeName: "Market Hall",
                coordinate: CLLocationCoordinate2D(latitude: -8.6494, longitude: 115.1346),
                time: "12:30",
                descriptor: "busy public lunch spot"
            )
        case .dinner:
            return MeetingSuggestion(
                placeName: "Garden Bar",
                coordinate: CLLocationCoordinate2D(latitude: -8.6488, longitude: 115.1411),
                time: "19:00",
                descriptor: "public dinner place"
            )
        case .activity:
            return MeetingSuggestion(
                placeName: "Gallery Courtyard",
                coordinate: CLLocationCoordinate2D(latitude: -8.6530, longitude: 115.1422),
                time: "17:30",
                descriptor: "public activity spot"
            )
        }
    }

    var alternateMeetingSuggestion: MeetingSuggestion {
        switch self {
        case .coffee:
            return MeetingSuggestion(
                placeName: "Park Kiosk",
                coordinate: CLLocationCoordinate2D(latitude: -8.6541, longitude: 115.1395),
                time: "14:15",
                descriptor: "public fallback cafe"
            )
        case .walk:
            return MeetingSuggestion(
                placeName: "Beach Path Entrance",
                coordinate: CLLocationCoordinate2D(latitude: -8.6467, longitude: 115.1369),
                time: "16:30",
                descriptor: "open public route"
            )
        case .lunch:
            return MeetingSuggestion(
                placeName: "Corner Deli",
                coordinate: CLLocationCoordinate2D(latitude: -8.6521, longitude: 115.1358),
                time: "13:15",
                descriptor: "public lunch fallback"
            )
        case .dinner:
            return MeetingSuggestion(
                placeName: "Lantern Terrace",
                coordinate: CLLocationCoordinate2D(latitude: -8.6504, longitude: 115.1387),
                time: "19:30",
                descriptor: "public dinner fallback"
            )
        case .activity:
            return MeetingSuggestion(
                placeName: "Bookshop Steps",
                coordinate: CLLocationCoordinate2D(latitude: -8.6488, longitude: 115.1411),
                time: "18:00",
                descriptor: "public activity fallback"
            )
        }
    }
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

struct DemoAccount: Identifiable, Equatable {
    let email: String
    let displayName: String

    var id: String { email }

    static let all: [DemoAccount] = [
        DemoAccount(email: "demo.ava@example.com", displayName: "Ava"),
        DemoAccount(email: "demo.maya@example.com", displayName: "Maya"),
        DemoAccount(email: "demo.nina@example.com", displayName: "Nina"),
        DemoAccount(email: "demo.ethan@example.com", displayName: "Ethan"),
        DemoAccount(email: "demo.liam@example.com", displayName: "Liam"),
        DemoAccount(email: "demo.sofia@example.com", displayName: "Sofia")
    ]

    static let defaultAccount = all[0]
}

enum MapPointState: String {
    case unseen
    case viewed
    case interested
    case triedBefore
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
