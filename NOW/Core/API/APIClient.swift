import Foundation

protocol APIClient {
    func getMe() async throws -> UserProfile
    func updateTodayIntent(_ intent: TodayIntent) async throws
    func discoverMap() async throws -> [MapPoint]
    func likeProfile(_ profileId: UUID) async throws -> Match?
    func passProfile(_ profileId: UUID) async throws
    func getActiveMatch() async throws -> Match?
    func sendMessage(_ text: String, matchId: UUID) async throws -> Message
    func createMeetingProposal(matchId: UUID, proposal: MeetingProposal) async throws -> MeetingProposal
}

struct MockAPIClient: APIClient {
    func getMe() async throws -> UserProfile {
        MockData.maya
    }

    func updateTodayIntent(_ intent: TodayIntent) async throws {}

    func discoverMap() async throws -> [MapPoint] {
        MockData.mapPoints
    }

    func likeProfile(_ profileId: UUID) async throws -> Match? {
        nil
    }

    func passProfile(_ profileId: UUID) async throws {}

    func getActiveMatch() async throws -> Match? {
        nil
    }

    func sendMessage(_ text: String, matchId: UUID) async throws -> Message {
        Message(id: UUID(), sender: .me, text: text, createdAt: Date())
    }

    func createMeetingProposal(matchId: UUID, proposal: MeetingProposal) async throws -> MeetingProposal {
        proposal
    }
}

