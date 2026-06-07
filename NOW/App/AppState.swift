import Foundation
import CoreLocation

final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isProfileComplete = false
    @Published var isOnline = false
    @Published var todayIntent = TodayIntent(plan: .coffee, intent: .date, timeWindow: .evening)
    @Published var mapPoints: [MapPoint] = MockData.mapPoints
    @Published var selectedPoint: MapPoint?
    @Published var activeMatch: Match?
    @Published var messages: [Message] = []
    @Published var meetingProposal: MeetingProposal?
    @Published var history: [HistoryItem] = MockData.history
    @Published var showHistory = false

    var visibleMapPoints: [MapPoint] {
        mapPoints.filter { $0.state != .hiddenToday && $0.state != .blocked }
    }

    var chatUnlocked: Bool {
        activeMatch?.myFirstLoopSent == true && activeMatch?.theirFirstLoopReceived == true
    }

    func login() {
        isAuthenticated = true
    }

    func completeProfile() {
        isProfileComplete = true
    }

    func goOnline() {
        showHistory = false
        isOnline = true
    }

    func goOffline() {
        isOnline = false
    }

    func viewPoint(_ point: MapPoint) {
        selectedPoint = point
        updatePoint(point.id, state: point.state == .unseen ? .viewed : point.state)
    }

    func closeProfilePreview() {
        selectedPoint = nil
    }

    func markInterested(_ point: MapPoint) {
        updatePoint(point.id, state: .interested)
        selectedPoint = nil

        if point.isMutualMock {
            activeMatch = Match(
                id: UUID(),
                profile: point.profile,
                status: .active,
                myFirstLoopSent: false,
                theirFirstLoopReceived: false,
                meetingStatus: .none
            )
            isOnline = false
        }
    }

    func notNow(_ point: MapPoint) {
        updatePoint(point.id, state: .hiddenToday)
        selectedPoint = nil
    }

    func block(_ point: MapPoint) {
        updatePoint(point.id, state: .blocked)
        selectedPoint = nil
    }

    func sendFirstLoop() {
        guard var match = activeMatch else { return }
        match.myFirstLoopSent = true
        match.theirFirstLoopReceived = true
        activeMatch = match
    }

    func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard chatUnlocked, !trimmed.isEmpty else { return }

        messages.append(
            Message(id: UUID(), sender: .me, text: trimmed, createdAt: Date())
        )
    }

    func createMeetingProposal() {
        guard let match = activeMatch else { return }
        meetingProposal = MeetingProposal(
            id: UUID(),
            matchId: match.id,
            placeName: "Zest Coffee",
            coordinate: CLLocationCoordinate2D(latitude: -8.6504, longitude: 115.1387),
            time: "18:30",
            status: .pending
        )
    }

    func acceptMeetingProposal() {
        meetingProposal?.status = .accepted
        activeMatch?.meetingStatus = .onMyWay
    }

    func updateMeetingStatus(_ status: MeetingStatus) {
        activeMatch?.meetingStatus = status
    }

    func weMet() {
        guard let match = activeMatch else { return }
        history.insert(
            HistoryItem(
                id: UUID(),
                name: match.profile.name,
                detail: "\(match.profile.plan.rawValue) today",
                status: "Awaiting confirmation"
            ),
            at: 0
        )
        activeMatch = nil
        meetingProposal = nil
        messages = []
        showHistory = true
        isOnline = false
    }

    func cancelMatch() {
        activeMatch = nil
        meetingProposal = nil
        messages = []
        showHistory = false
        isOnline = false
    }

    func closeHistory() {
        showHistory = false
    }

    private func updatePoint(_ id: UUID, state: MapPointState) {
        guard let index = mapPoints.firstIndex(where: { $0.id == id }) else { return }
        mapPoints[index].state = state

        if selectedPoint?.id == id {
            selectedPoint?.state = state
        }
    }
}
