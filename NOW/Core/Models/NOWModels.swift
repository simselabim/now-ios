import Foundation
import CoreLocation

enum AppTab: String, CaseIterable, Identifiable {
    case search = "Search"
    case history = "History"
    case account = "Account"
    case now = "NOW"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .search:
            return "location.magnifyingglass"
        case .history:
            return "clock.arrow.circlepath"
        case .account:
            return "person.crop.circle"
        case .now:
            return "sparkles"
        }
    }
}

enum Plan: String, CaseIterable, Identifiable {
    case coffee = "Coffee"
    case walk = "Walk"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case activity = "Activity"

    var id: String { rawValue }

    static let goOnlineOptions: [Plan] = [.lunch, .walk, .activity]

    var goOnlineLabel: String {
        switch self {
        case .lunch:
            return "Food"
        default:
            return rawValue
        }
    }
}

enum Intent: String, CaseIterable, Identifiable {
    case friendly = "Friendly"
    case date = "Date"
    case romantic = "Romantic"
    case openMinded = "Open-minded"

    var id: String { rawValue }

    static let goOnlineOptions: [Intent] = [.friendly, .romantic, .openMinded]
}

enum TimeWindow: String, CaseIterable, Identifiable {
    case now = "Now"
    case lunch = "Lunch"
    case afternoon = "Afternoon"
    case evening = "Evening"

    var id: String { rawValue }

    static let goOnlineOptions: [TimeWindow] = [.now, .lunch, .evening]
}

enum MapPointState: String {
    case unseen
    case viewed
    case interested
    case triedBefore
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

enum TomorrowExtensionStatus: String {
    case none
    case proposed
    case accepted
    case rejected
    case expired
    case cancelled
}

struct TomorrowExtension {
    var status: TomorrowExtensionStatus
    var requestId: UUID?
    var requestedByMe: Bool
    var extendedUntil: String?

    static let none = TomorrowExtension(
        status: .none,
        requestId: nil,
        requestedByMe: false,
        extendedUntil: nil
    )
}

enum MessageSender {
    case me
    case them
}

struct UserProfile: Identifiable, Equatable {
    let id: UUID
    let name: String
    let age: Int?
    let distance: String
    let plan: Plan
    let intent: Intent
    let occupation: String
    let languages: [String]
    let interests: [String]
    let sharedInterests: [String]
    let prompt: String
    let mainPhotoURL: URL?
    let introLoopURL: URL?
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
    var tomorrowExtension: TomorrowExtension = .none
}

struct Message: Identifiable {
    let id: UUID
    let sender: MessageSender
    let text: String
    let createdAt: Date?
}

struct MeetingProposal: Identifiable {
    let id: UUID
    let matchId: UUID
    var proposerUserId: UUID?
    var placeName: String
    var placeAddress: String?
    var coordinate: CLLocationCoordinate2D?
    var proposedAt: Date?
    var time: String
    var dateLabel: String
    var status: MeetingProposalStatus
}

struct HistoryItem: Identifiable {
    let id: UUID
    let title: String
    let result: String
    let occurredAt: Date?
    let otherDisplayName: String?
    let otherMainPhotoURL: URL?
}
