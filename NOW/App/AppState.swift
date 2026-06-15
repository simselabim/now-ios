import Foundation
import CoreLocation

@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isProfileComplete = false
    @Published var isOnline = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var todayIntent = TodayIntent(plan: .coffee, intent: .date, timeWindow: .evening)
    @Published var mapPoints: [MapPoint] = MockData.mapPoints
    @Published var selectedPoint: MapPoint?
    @Published var activeMatch: Match?
    @Published var messages: [Message] = []
    @Published var meetingProposal: MeetingProposal?
    @Published var history: [HistoryItem] = MockData.history
    @Published var showHistory = false

    private let apiClient: NOWAPIClient

    init(apiClient: NOWAPIClient = NOWAPIClient()) {
        self.apiClient = apiClient
    }

    var visibleMapPoints: [MapPoint] {
        mapPoints.filter { $0.state != .hiddenToday && $0.state != .blocked }
    }

    var chatUnlocked: Bool {
        activeMatch?.myFirstLoopSent == true && activeMatch?.theirFirstLoopReceived == true
    }

    func login() {
        Task {
            await demoLoginAndBootstrap()
        }
    }

    func completeProfile() {
        isProfileComplete = true
    }

    func goOnline() {
        Task {
            await goOnlineWithBackend()
        }
    }

    func goOffline() {
        isOnline = false
    }

    func viewPoint(_ point: MapPoint) {
        selectedPoint = point
        updatePoint(point.id, state: point.state == .unseen ? .viewed : point.state)

        Task {
            await openPointWithBackend(point)
        }
    }

    func closeProfilePreview() {
        selectedPoint = nil
    }

    func markInterested(_ point: MapPoint) {
        Task {
            await likePointWithBackend(point)
        }
    }

    func notNow(_ point: MapPoint) {
        Task {
            await passPointWithBackend(point)
        }
    }

    func block(_ point: MapPoint) {
        updatePoint(point.id, state: .blocked)
        selectedPoint = nil
    }

    func sendFirstLoop() {
        guard let match = activeMatch else { return }

        Task {
            await sendMockFirstLoopWithBackend(match)
        }
    }

    func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard chatUnlocked, !trimmed.isEmpty else { return }

        Task {
            await sendMessageWithBackend(trimmed)
        }
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

    private func demoLoginAndBootstrap() async {
        await runLoading {
            _ = try await self.apiClient.login(email: "demo.ava@example.com", password: "password123")
            self.isAuthenticated = true
            try await self.applyBootstrap(self.apiClient.bootstrap())
        }
    }

    private func applyBootstrap(_ bootstrap: BootstrapResponseDTO) async throws {
        isProfileComplete = !(bootstrap.requirements.profileRequired)
        isOnline = false
        activeMatch = bootstrap.activeMatch.map { matchDTO in
            Match(
                id: matchDTO.id,
                profile: mapProfile(bootstrap.profile),
                status: mapMatchStatus(matchDTO.status),
                myFirstLoopSent: false,
                theirFirstLoopReceived: false,
                meetingStatus: .none
            )
        }

        switch bootstrap.nextStep {
        case .discover:
            isProfileComplete = true
            isOnline = false
        case .activeMatch:
            try await loadActiveMatchDetail()
        case .createProfile:
            isProfileComplete = false
        case .updateTodayIntent:
            isProfileComplete = true
            isOnline = false
        case .goOnline:
            isProfileComplete = true
            isOnline = false
        }
    }

    private func goOnlineWithBackend() async {
        let selectedIntent = todayIntent
        await runLoading {
            _ = try await self.apiClient.updateTodayIntent(
                UpdateTodayIntentRequestDTO(
                    plan: self.mapPlan(selectedIntent.plan),
                    intent: self.mapIntent(selectedIntent.intent),
                    timeToday: self.mapTime(selectedIntent.timeWindow)
                )
            )
            _ = try await self.apiClient.goOnline(lat: 40.7410, lng: -73.9897, accuracyM: 25)
            self.showHistory = false
            self.isOnline = true
            try await self.loadDiscoveryMap()
        }
    }

    private func loadDiscoveryMap() async throws {
        let response = try await apiClient.discoverMap()
        mapPoints = response.points.map(mapPoint)
        isOnline = !response.discoveryLocked
    }

    private func openPointWithBackend(_ point: MapPoint) async {
        await runLoading {
            let response = try await self.apiClient.openMapPoint(point.id)
            self.selectedPoint = self.mapPoint(response.point, profile: response.profile)
            self.updatePoint(point.id, state: .viewed)
        }
    }

    private func likePointWithBackend(_ point: MapPoint) async {
        await runLoading {
            let response = try await self.apiClient.likeProfile(point.profile.id)
            self.updatePoint(point.id, state: .interested)
            self.selectedPoint = nil

            if let matchDTO = response.matchItem {
                self.activeMatch = Match(
                    id: matchDTO.id,
                    profile: point.profile,
                    status: self.mapMatchStatus(matchDTO.status),
                    myFirstLoopSent: false,
                    theirFirstLoopReceived: false,
                    meetingStatus: .none
                )
                self.isOnline = false
                try await self.loadActiveMatchDetail()
            }
        }
    }

    private func passPointWithBackend(_ point: MapPoint) async {
        await runLoading {
            _ = try await self.apiClient.passProfile(point.profile.id)
            self.updatePoint(point.id, state: .hiddenToday)
            self.selectedPoint = nil
        }
    }

    private func loadActiveMatchDetail() async throws {
        let response = try await apiClient.activeMatchDetail()
        guard let detail = response.matchItem else {
            activeMatch = nil
            return
        }

        let profile = mapProfile(detail.otherProfile)
        let myLoopSent = detail.loops.contains { $0.userId != detail.matchItem.otherUserId }
        let theirLoopReceived = detail.loops.contains { $0.userId == detail.matchItem.otherUserId }
        activeMatch = Match(
            id: detail.matchItem.id,
            profile: profile,
            status: mapMatchStatus(detail.matchItem.status),
            myFirstLoopSent: myLoopSent,
            theirFirstLoopReceived: theirLoopReceived,
            meetingStatus: detail.latestMeetingStatus.map { mapMeetingStatus($0.status) } ?? .none
        )
        messages = detail.messages.map { message in
            Message(
                id: message.id,
                sender: message.senderUserId == detail.matchItem.otherUserId ? .them : .me,
                text: message.body,
                createdAt: Date()
            )
        }
        if let proposal = detail.latestMeetingProposal {
            meetingProposal = MeetingProposal(
                id: proposal.id,
                matchId: proposal.matchId,
                placeName: proposal.placeName,
                coordinate: CLLocationCoordinate2D(
                    latitude: proposal.placeLat ?? 40.7410,
                    longitude: proposal.placeLng ?? -73.9897
                ),
                time: proposal.proposedTime,
                status: proposal.status == "accepted" ? .accepted : .pending
            )
        }
    }

    private func sendMockFirstLoopWithBackend(_ match: Match) async {
        await runLoading {
            let data = Data("mock-loop".utf8)
            let intent = try await self.apiClient.createUploadIntent(
                kind: .firstLoop,
                contentType: "video/mp4",
                fileSizeBytes: data.count
            )
            _ = try await MediaUploadService().upload(data: data, intent: intent)
            _ = try await self.apiClient.sendFirstLoop(
                matchId: match.id,
                storageKey: intent.storageKey,
                durationMs: 2_900
            )
            try await self.loadActiveMatchDetail()
        }
    }

    private func sendMessageWithBackend(_ text: String) async {
        guard let match = activeMatch else { return }

        await runLoading {
            let response = try await self.apiClient.sendMessage(matchId: match.id, body: text)
            self.messages.append(
                Message(id: response.message.id, sender: .me, text: response.message.body, createdAt: Date())
            )
        }
    }

    private func runLoading(_ operation: @escaping () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        do {
            try await operation()
        } catch {
            errorMessage = String(describing: error)
        }
        isLoading = false
    }

    private func mapPoint(_ dto: MapPointDTO) -> MapPoint {
        mapPoint(dto, profile: nil)
    }

    private func mapPoint(_ dto: MapPointDTO, profile: ProfileDTO?) -> MapPoint {
        MapPoint(
            id: dto.pointId,
            profile: mapProfile(profile, fallback: dto),
            approximateCoordinate: CLLocationCoordinate2D(latitude: dto.lat, longitude: dto.lng),
            state: mapPointState(dto.state),
            isMutualMock: false
        )
    }

    private func mapProfile(_ dto: ProfileDTO?, fallback: MapPointDTO? = nil) -> UserProfile {
        if let dto {
            return UserProfile(
                id: dto.id,
                name: dto.displayName,
                age: age(from: dto.birthDate),
                distance: fallback.map { "\($0.distanceM) m" } ?? "nearby",
                plan: fallback.map { mapPlan($0.plan) } ?? .coffee,
                intent: fallback.map { mapIntent($0.intent) } ?? .date,
                occupation: dto.gender.capitalized,
                languages: [],
                interests: dto.interests,
                sharedInterests: Array(dto.interests.prefix(3)),
                prompt: dto.bio
            )
        }

        return UserProfile(
            id: fallback?.profileId ?? UUID(),
            name: fallback?.displayName ?? "NOW",
            age: 29,
            distance: fallback.map { "\($0.distanceM) m" } ?? "nearby",
            plan: fallback.map { mapPlan($0.plan) } ?? .coffee,
            intent: fallback.map { mapIntent($0.intent) } ?? .date,
            occupation: "Nearby",
            languages: [],
            interests: [],
            sharedInterests: [],
            prompt: "Open to meet today."
        )
    }

    private func mapPointState(_ state: MapPointStateDTO) -> MapPointState {
        switch state {
        case .unseen:
            return .unseen
        case .viewed:
            return .viewed
        case .likedToday:
            return .interested
        case .cancelledMatchBefore:
            return .triedBefore
        }
    }

    private func mapPlan(_ plan: PlanDTO) -> Plan {
        switch plan {
        case .coffee:
            return .coffee
        case .walk:
            return .walk
        case .lunch:
            return .lunch
        case .dinner:
            return .dinner
        case .activity:
            return .activity
        }
    }

    private func mapPlan(_ plan: Plan) -> PlanDTO {
        switch plan {
        case .coffee:
            return .coffee
        case .walk:
            return .walk
        case .lunch:
            return .lunch
        case .dinner:
            return .dinner
        case .activity:
            return .activity
        }
    }

    private func mapIntent(_ intent: IntentDTO) -> Intent {
        switch intent {
        case .friendly:
            return .friendly
        case .date:
            return .date
        case .romantic:
            return .romantic
        case .openMinded:
            return .openMinded
        }
    }

    private func mapIntent(_ intent: Intent) -> IntentDTO {
        switch intent {
        case .friendly:
            return .friendly
        case .date:
            return .date
        case .romantic:
            return .romantic
        case .openMinded:
            return .openMinded
        }
    }

    private func mapTime(_ time: TimeWindow) -> TimeTodayDTO {
        switch time {
        case .now:
            return .now
        case .lunch:
            return .lunch
        case .afternoon:
            return .afternoon
        case .evening:
            return .evening
        }
    }

    private func mapMatchStatus(_ status: MatchStatusDTO) -> MatchStatus {
        switch status {
        case .active:
            return .active
        case .cancelled, .blocked:
            return .cancelled
        case .completed:
            return .met
        case .expired:
            return .expired
        }
    }

    private func mapMeetingStatus(_ status: MeetingStatusValueDTO) -> MeetingStatus {
        switch status {
        case .onMyWay:
            return .onMyWay
        case .arrived:
            return .arrived
        case .delayed:
            return .delayed
        }
    }

    private func age(from birthDate: String) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: birthDate) else {
            return 29
        }
        return Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 29
    }
}
