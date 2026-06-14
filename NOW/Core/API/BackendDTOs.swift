import Foundation

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
    let createdAt: String
    let updatedAt: String
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
    let plan: PlanDTO
    let intent: IntentDTO
    let timeToday: TimeTodayDTO
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
    let plan: PlanDTO
    let intent: IntentDTO
    let timeToday: TimeTodayDTO
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
    let plan: PlanDTO
    let intent: IntentDTO
    let timeToday: TimeTodayDTO
    let lat: Double
    let lng: Double
    let distanceM: Int
    let state: MapPointStateDTO
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

struct ActiveMatchResponseDTO: Decodable {
    let matchItem: MatchDTO?
}

struct ActiveMatchDetailResponseDTO: Decodable {
    let matchItem: ActiveMatchDetailDTO?
}

struct ActiveMatchDetailDTO: Decodable {
    let matchItem: MatchDTO
    let otherProfile: ProfileDTO
    let loops: [LoopDTO]
    let chatUnlocked: Bool
    let messages: [MessageDTO]
    let latestMeetingProposal: MeetingProposalDTO?
    let latestMeetingStatus: MeetingStatusDTO?
    let flags: ActiveMatchFlagsDTO
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
}

enum MatchStatusDTO: String, Codable {
    case active
    case cancelled
    case completed
    case expired
    case blocked
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
    let placeName: String
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
    let placeName: String
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
}

struct BlockUserRequestDTO: Encodable {
    let reason: String?
}

struct ReportUserRequestDTO: Encodable {
    let reason: String
    let details: String?
    let matchId: UUID?
}

