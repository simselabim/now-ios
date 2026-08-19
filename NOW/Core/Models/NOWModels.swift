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
    let plans: [Plan]
    let intents: [Intent]
    let occupation: String
    let languages: [String]
    let interests: [String]
    let sharedInterests: [String]
    let prompt: String
    let mainPhotoURL: URL?
    let introLoopURL: URL?

    var plan: Plan { plans.first ?? .activity }
    var intent: Intent { intents.first ?? .friendly }
    var planSummary: String {
        plans.isEmpty ? "Any plan" : plans.map(\.rawValue).joined(separator: ", ")
    }
    var intentSummary: String {
        intents.isEmpty ? "Any connection" : intents.map(\.rawValue).joined(separator: ", ")
    }
}

struct TodayIntent: Equatable {
    var plans: Set<Plan> = []
    var intents: Set<Intent> = []
    var timeWindows: Set<TimeWindow> = []
}

struct MapPoint: Identifiable, Equatable {
    let id: UUID
    let profile: UserProfile
    let approximateCoordinate: CLLocationCoordinate2D
    var state: MapPointState
    let alreadyMatched: Bool
    let lastMatchID: UUID?

    static func == (lhs: MapPoint, rhs: MapPoint) -> Bool {
        lhs.id == rhs.id
            && lhs.profile == rhs.profile
            && lhs.approximateCoordinate.latitude == rhs.approximateCoordinate.latitude
            && lhs.approximateCoordinate.longitude == rhs.approximateCoordinate.longitude
            && lhs.state == rhs.state
            && lhs.alreadyMatched == rhs.alreadyMatched
            && lhs.lastMatchID == rhs.lastMatchID
    }
}

struct Match: Identifiable {
    let id: UUID
    let profile: UserProfile
    var status: MatchStatus
    var myFirstLoopSent: Bool
    var theirFirstLoopReceived: Bool
    var meetingStatus: MeetingStatus
    var hasConfirmedWeMet: Bool = false
    var tomorrowExtension: TomorrowExtension = .none
}

struct Message: Identifiable {
    let id: UUID
    let sender: MessageSender
    let text: String
    let createdAt: Date?
}

enum MessageTimeline {
    static func normalized(_ messages: [Message]) -> [Message] {
        var messagesByID: [UUID: Message] = [:]
        for message in messages {
            messagesByID[message.id] = message
        }

        return messagesByID.values.sorted { lhs, rhs in
            switch (lhs.createdAt, rhs.createdAt) {
            case let (.some(lhsDate), .some(rhsDate)) where lhsDate != rhsDate:
                return lhsDate < rhsDate
            case (.none, .some):
                return false
            case (.some, .none):
                return true
            default:
                return lhs.id.uuidString < rhs.id.uuidString
            }
        }
    }
}

struct MeetingProposal: Identifiable {
    let id: UUID
    let matchId: UUID
    var proposerUserId: UUID?
    let version: Int
    var placeExternalID: String?
    var placeName: String
    var placeCategory: MeetingPlaceCategory
    var placeAddress: String?
    var coordinate: CLLocationCoordinate2D?
    var proposedAt: Date?
    var time: String
    var dateLabel: String
    var status: MeetingProposalStatus

    func isAuthored(by userId: UUID?) -> Bool {
        guard let userId, let proposerUserId else { return false }
        return userId == proposerUserId
    }

    func canBeAccepted(by userId: UUID?) -> Bool {
        guard status == .pending, let userId, let proposerUserId else { return false }
        return userId != proposerUserId
    }
}

struct PartnerMeetingLocation {
    let coordinate: CLLocationCoordinate2D
    let accuracyRadiusM: Int
    let updatedAt: Date?
    let expiresAt: Date?

    func isFresh(at date: Date) -> Bool {
        expiresAt.map { $0 > date } ?? true
    }
}

struct MeetingLocationConfig {
    let accuracyRadiusM: Int
    let updateIntervalSeconds: Int
    let ttlSeconds: Int
}

struct HistoryItem: Identifiable {
    let id: UUID
    let title: String
    let result: String
    let occurredAt: Date?
    let otherDisplayName: String?
    let otherMainPhotoURL: URL?
}
