import Foundation

@propertyWrapper
struct ArrayOrSingle<Value: Codable & Equatable>: Codable, Equatable {
    var wrappedValue: [Value]

    init(wrappedValue: [Value]) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let values = try? container.decode([Value].self) {
            wrappedValue = values
        } else {
            wrappedValue = [try container.decode(Value.self)]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

struct AuthRequest: Encodable {
    let email: String
    let password: String
}

struct AuthResponseDTO: Decodable {
    let accessToken: String
    let tokenType: String
    let user: UserDTO
}

struct MeResponseDTO: Decodable {
    let user: UserDTO
}

struct DeleteAccountResponseDTO: Decodable {
    let deleted: Bool
}

struct UserDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let email: String
    let status: String
    let createdAt: String
}

struct BootstrapResponseDTO: Decodable {
    let user: UserDTO
    let profile: ProfileDTO?
    let todayIntent: TodayIntentDTO?
    let onlineSession: OnlineSessionDTO?
    let activeMatch: MatchDTO?
    let requirements: BootstrapRequirementsDTO
    let discoveryLocked: Bool
    let nextStep: BootstrapNextStepDTO
}

struct BootstrapRequirementsDTO: Decodable, Equatable {
    let profileRequired: Bool
    let intentRequired: Bool
    let onlineRequired: Bool
    let activeMatchRequired: Bool
}

enum BootstrapNextStepDTO: String, Decodable {
    case createProfile = "create_profile"
    case updateTodayIntent = "update_today_intent"
    case goOnline = "go_online"
    case activeMatch = "active_match"
    case discover
}

struct UpdateProfileRequestDTO: Encodable {
    let displayName: String
    let birthDate: String
    let gender: String
    let bio: String
    let interests: [String]
}

struct MyProfileResponseDTO: Decodable {
    let profile: ProfileDTO?
}

struct PublicProfileResponseDTO: Decodable {
    let profile: ProfileDTO
}

struct ProfileDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let displayName: String
    let birthDate: String
    let gender: String
    let bio: String
    let interests: [String]
    let isPublishable: Bool
    let publishedAt: String?
    let photos: [PhotoDTO]
    let introLoop: IntroLoopDTO?
    let createdAt: String
    let updatedAt: String
}

struct IntroLoopDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let storageKey: String
    let durationMs: Int
    let createdAt: String
}

struct UploadPhotoRequestDTO: Encodable {
    let storageKey: String
    let position: Int
    let isMain: Bool
}

struct UploadPhotoResponseDTO: Decodable {
    let photo: PhotoDTO
    let isProfilePublishable: Bool
}

struct UploadIntroLoopRequestDTO: Encodable {
    let storageKey: String
    let durationMs: Int
}

struct UploadIntroLoopResponseDTO: Decodable {
    let introLoop: IntroLoopDTO
}

struct PhotoDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let storageKey: String
    let position: Int
    let isMain: Bool
    let createdAt: String
}

struct CreateUploadIntentRequestDTO: Encodable {
    let kind: UploadKindDTO
    let contentType: String
    let fileSizeBytes: Int
}

enum UploadKindDTO: String, Codable {
    case profilePhoto = "profile_photo"
    case firstLoop = "first_loop"
}

struct UploadIntentResponseDTO: Decodable, Equatable {
    let storageKey: String
    let uploadUrl: String
    let method: String
    let headers: [UploadHeaderDTO]
    let expiresAt: String
}

struct UploadHeaderDTO: Codable, Equatable {
    let name: String
    let value: String
}

struct DevUploadResponseDTO: Decodable, Equatable {
    let storageKey: String
    let sizeBytes: Int
    let contentType: String
}

struct UpdateTodayIntentRequestDTO: Encodable {
    let plans: [PlanDTO]
    let intents: [IntentDTO]
    let timesToday: [TimeTodayDTO]
}

enum PlanDTO: String, Codable, CaseIterable {
    case coffee
    case walk
    case lunch
    case dinner
    case activity
}

enum IntentDTO: String, Codable, CaseIterable {
    case friendly
    case date
    case romantic
    case openMinded = "open-minded"
}

enum TimeTodayDTO: String, Codable, CaseIterable {
    case now
    case lunch
    case afternoon
    case evening
}

struct TodayIntentMeResponseDTO: Decodable {
    let todayIntent: TodayIntentDTO?
}

struct TodayIntentDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let intentDate: String
    @ArrayOrSingle var plans: [PlanDTO]
    @ArrayOrSingle var intents: [IntentDTO]
    @ArrayOrSingle var timesToday: [TimeTodayDTO]
    let createdAt: String
    let updatedAt: String
}

struct GoOnlineRequestDTO: Encodable {
    let lat: Double
    let lng: Double
    let accuracyM: Int?
}

struct OnlineResponseDTO: Decodable {
    let session: OnlineSessionDTO
    let todayIntent: TodayIntentDTO
}

struct OfflineResponseDTO: Decodable {
    let status: String
    let closedSessions: UInt64
}

struct OnlineSessionDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let intentId: UUID
    let sessionDate: String
    let status: String
    let startedAt: String
    let endedAt: String?
}

struct DiscoverMapResponseDTO: Decodable {
    let radiusM: Int
    let discoveryLocked: Bool
    let points: [MapPointDTO]
}

struct MapPointProfileResponseDTO: Decodable {
    let point: MapPointDTO
    let profile: ProfileDTO
}

struct MapPointDTO: Codable, Identifiable, Equatable {
    var id: UUID { pointId }

    let pointId: UUID
    let profileId: UUID
    let userId: UUID
    let displayName: String
    let mainPhotoStorageKey: String?
    @ArrayOrSingle var plans: [PlanDTO]
    @ArrayOrSingle var intents: [IntentDTO]
    @ArrayOrSingle var timesToday: [TimeTodayDTO]
    let lat: Double
    let lng: Double
    let distanceM: Int
    let state: MapPointStateDTO
    let alreadyMatched: Bool
    let lastMatchId: UUID?
    let lastSeenAt: String
}

enum MapPointStateDTO: String, Codable {
    case unseen
    case viewed
    case likedToday = "liked_today"
    case cancelledMatchBefore = "cancelled_match_before"
}

struct ProfileInteractionResponseDTO: Decodable {
    let profileId: UUID
    let state: MapPointStateDTO
}

struct LikeProfileResponseDTO: Decodable {
    let profileId: UUID
    let state: MapPointStateDTO
    let matchCreated: Bool
    let matchItem: MatchDTO?
}

struct MeetingPlaceRequestDTO: Encodable {
    let externalId: String
    let name: String
    let category: MeetingPlaceCategory
    let address: String
    let lat: Double
    let lng: Double

    init(place: MeetingPlace) {
        externalId = place.externalID
        name = place.name
        category = place.category
        address = place.address
        lat = place.coordinate.latitude
        lng = place.coordinate.longitude
    }
}

struct LikeProfileRequestDTO: Encodable {
    let meetingPlace: MeetingPlaceRequestDTO?
}

struct ActiveMatchResponseDTO: Decodable {
    let matchItem: MatchDTO?
}

struct ReopenMatchResponseDTO: Decodable {
    let matchItem: MatchDTO
    let reopened: Bool
}

struct ActiveMatchDetailResponseDTO: Decodable {
    let matchItem: ActiveMatchDetailDTO?
}

struct RealtimeEventDTO: Decodable {
    let eventId: UUID
    let version: UInt64
    let type: RealtimeEventTypeDTO
    let matchId: UUID?
    let detail: ActiveMatchDetailResponseDTO?
    let message: String?
}

enum RealtimeEventTypeDTO: String, Decodable {
    case snapshot
    case matchCreated = "match_created"
    case matchUpdated = "match_updated"
    case firstLoopReceived = "first_loop_received"
    case messageCreated = "message_created"
    case meetingStatusUpdated = "meeting_status_updated"
    case meetingLocationUpdated = "meeting_location_updated"
    case discoveryChanged = "discovery_changed"
    case matchClosed = "match_closed"
    case error
}

struct ActiveMatchDetailDTO: Decodable {
    let matchItem: MatchDTO
    let otherProfile: ProfileDTO
    let otherTodayIntent: TodayIntentDTO?
    let loops: [LoopDTO]
    let chatUnlocked: Bool
    let messages: [MessageDTO]
    let latestMeetingProposal: MeetingProposalDTO?
    let latestMeetingStatus: MeetingStatusDTO?
    let otherMeetingLocation: PartnerMeetingLocationDTO?
    let meetingLocationConfig: MeetingLocationConfigDTO?
    let tomorrowExtension: TomorrowExtensionSummaryDTO?
    let flags: ActiveMatchFlagsDTO
}

struct UpdateMeetingLocationRequestDTO: Encodable {
    let lat: Double
    let lng: Double
    let accuracyM: Int?
}

struct MeetingLocationUpdateResponseDTO: Decodable {
    let accepted: Bool
    let expiresAt: String
}

struct PartnerMeetingLocationDTO: Decodable {
    let lat: Double
    let lng: Double
    let accuracyRadiusM: Int
    let updatedAt: String
    let expiresAt: String
}

struct MeetingLocationConfigDTO: Decodable {
    let accuracyRadiusM: Int
    let updateIntervalSeconds: Int
    let ttlSeconds: Int
}

struct ActiveMatchFlagsDTO: Decodable, Equatable {
    let canSendMessage: Bool
    let canCreateProposal: Bool
    let canConfirmWeMet: Bool
}

struct MatchDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let userAId: UUID
    let userBId: UUID
    let otherUserId: UUID
    let matchDate: String
    let status: MatchStatusDTO
    let createdAt: String
    let closedAt: String?
    let extendedUntil: String?
    let extensionAcceptedAt: String?
}

enum MatchStatusDTO: String, Codable {
    case active
    case cancelled
    case completed
    case expired
    case blocked
}

struct TomorrowExtensionSummaryDTO: Codable, Equatable {
    let status: TomorrowExtensionStatusDTO
    let requestId: UUID?
    let requestedByMe: Bool
    let extendedUntil: String?
}

struct TomorrowExtensionResponseDTO: Decodable {
    let request: MatchExtensionRequestDTO
    let matchItem: MatchDTO
}

struct MatchExtensionRequestDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let matchId: UUID
    let requestedByUserId: UUID
    let requestedForDate: String
    let status: TomorrowExtensionStatusDTO
    let expiresAt: String
    let createdAt: String
    let respondedAt: String?
    let respondedByUserId: UUID?
}

enum TomorrowExtensionStatusDTO: String, Codable {
    case none
    case proposed
    case accepted
    case rejected
    case expired
    case cancelled
}

struct CancelMatchRequestDTO: Encodable {
    let reason: CancelReasonDTO
    let note: String?
}

enum CancelReasonDTO: String, Codable, CaseIterable {
    case changedMind = "changed_mind"
    case notResponding = "not_responding"
    case timeNoLongerWorks = "time_no_longer_works"
    case differentThings = "different_things"
    case uncomfortable
    case other
}

struct UploadFirstLoopRequestDTO: Encodable {
    let storageKey: String
    let durationMs: Int
}

struct UploadFirstLoopResponseDTO: Decodable {
    let loopItem: LoopDTO
    let chatUnlocked: Bool
}

struct MatchLoopsResponseDTO: Decodable {
    let loops: [LoopDTO]
    let chatUnlocked: Bool
}

struct LoopDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let matchId: UUID
    let userId: UUID
    let storageKey: String
    let durationMs: Int
    let createdAt: String
}

struct SendMessageRequestDTO: Encodable {
    let body: String
}

struct MessagesResponseDTO: Decodable {
    let chatUnlocked: Bool
    let messages: [MessageDTO]
}

struct SendMessageResponseDTO: Decodable {
    let message: MessageDTO
}

struct MessageDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let matchId: UUID
    let senderUserId: UUID
    let body: String
    let moderationStatus: String
    let createdAt: String
}

struct CreateProposalRequestDTO: Encodable {
    let placeExternalId: String
    let placeName: String
    let placeCategory: MeetingPlaceCategory
    let placeAddress: String
    let placeLat: Double?
    let placeLng: Double?
    let proposedTime: String
    let format: MeetingFormatDTO
    let note: String?
}

typealias UpdateProposalRequestDTO = CreateProposalRequestDTO

enum MeetingFormatDTO: String, Codable, CaseIterable {
    case coffee
    case walk
    case lunch
    case dinner
    case activity
}

struct MeetingProposalDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let matchId: UUID
    let proposerUserId: UUID
    let version: Int
    let placeExternalId: String?
    let placeName: String
    let placeCategory: MeetingPlaceCategory?
    let placeAddress: String?
    let placeLat: Double?
    let placeLng: Double?
    let proposedTime: String
    let format: MeetingFormatDTO
    let note: String?
    let status: String
    let createdAt: String
    let updatedAt: String
}

struct UpdateMeetingStatusRequestDTO: Encodable {
    let status: MeetingStatusValueDTO
}

enum MeetingStatusValueDTO: String, Codable, CaseIterable {
    case onMyWay = "on_my_way"
    case arrived
    case delayed
}

struct MeetingStatusDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let matchId: UUID
    let userId: UUID
    let status: MeetingStatusValueDTO
    let createdAt: String
}

struct WeMetResponseDTO: Decodable {
    let matchItem: MatchDTO
    let completed: Bool
}

struct HistoryResponseDTO: Decodable {
    let items: [HistoryItemDTO]
}

struct HistoryItemDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let matchId: UUID
    let result: String
    let title: String
    let occurredAt: String
    let otherDisplayName: String?
    let otherMainPhotoStorageKey: String?
}

struct LocationPayloadDTO: Codable, Equatable {
    let lat: Double
    let lng: Double
    let accuracyM: Int?
}

struct CreateSafetyEventRequestDTO: Encodable {
    let eventType: String
    let payload: LocationPayloadDTO?
}

struct EmergencyRequestDTO: Encodable {
    let payload: LocationPayloadDTO?
}

struct SafetyEventResponseDTO: Decodable {
    let id: UUID
    let matchId: UUID
    let userId: UUID
    let eventType: String
    let createdAt: String
}

struct BlockUserRequestDTO: Encodable {
    let reason: String?
}

struct ReportUserRequestDTO: Encodable {
    let reason: String
    let details: String?
    let matchId: UUID?
}
