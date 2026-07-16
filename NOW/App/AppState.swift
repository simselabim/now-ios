import Foundation
import CoreLocation

@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isProfileComplete = false
    @Published var isOnline = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedDemoAccount = DemoAccount.defaultAccount
    @Published var todayIntent = TodayIntent(plan: .coffee, intent: .date, timeWindow: .evening)
    @Published var mapPoints: [MapPoint] = MockData.mapPoints
    @Published var currentCoordinate: CLLocationCoordinate2D?
    @Published var currentLocationAccuracyM: Int?
    @Published var selectedPoint: MapPoint?
    @Published var activeMatch: Match?
    @Published var messages: [Message] = []
    @Published var meetingProposal: MeetingProposal?
    @Published var history: [HistoryItem] = MockData.history
    @Published var showHistory = false
    @Published private(set) var currentUserId: UUID?

    private let apiClient: NOWAPIClient
    private let locationService: LocationService

    init(apiClient: NOWAPIClient = NOWAPIClient()) {
        self.apiClient = apiClient
        self.locationService = LocationService()
    }

    var visibleMapPoints: [MapPoint] {
        mapPoints.filter { $0.state != .hiddenToday && $0.state != .blocked }
    }

    var chatUnlocked: Bool {
        activeMatch?.myFirstLoopSent == true && activeMatch?.theirFirstLoopReceived == true
    }

    func login() {
        let account = selectedDemoAccount
        Task {
            await demoLoginAndBootstrap(email: account.email)
        }
    }

    func loginAndOpenMapForTesting() {
        let account = selectedDemoAccount
        Task {
            await demoLoginAndBootstrap(email: account.email)
            await goOnlineWithBackend()
        }
    }

    func openLAStateForTesting(_ state: String) {
        isAuthenticated = true
        isProfileComplete = true
        isOnline = false
        isLoading = false
        errorMessage = nil
        currentUserId = nil
        showHistory = false
        selectedPoint = nil
        activeMatch = nil
        meetingProposal = nil
        messages = []
        mapPoints = MockData.mapPoints

        let point = MockData.mapPoints.first ?? mapPoints[0]
        let match = Match(
            id: UUID(),
            profile: point.profile,
            status: .active,
            myFirstLoopSent: false,
            theirFirstLoopReceived: false,
            meetingStatus: .none
        )

        switch state {
        case "profile":
            selectedPoint = point
            isOnline = true
        case "match":
            activeMatch = match
        case "chat":
            activeMatch = Match(
                id: match.id,
                profile: match.profile,
                status: .active,
                myFirstLoopSent: true,
                theirFirstLoopReceived: true,
                meetingStatus: .none
            )
        case "meeting":
            activeMatch = Match(
                id: match.id,
                profile: match.profile,
                status: .active,
                myFirstLoopSent: true,
                theirFirstLoopReceived: true,
                meetingStatus: .onMyWay
            )
            let suggestion = match.profile.plan.primaryMeetingSuggestion
            meetingProposal = MeetingProposal(
                id: UUID(),
                matchId: match.id,
                proposerUserId: nil,
                placeName: suggestion.placeName,
                coordinate: suggestion.coordinate,
                time: suggestion.time,
                dateLabel: "Today",
                status: .accepted
            )
        default:
            isOnline = true
        }
    }

    func selectDemoAccount(_ account: DemoAccount) {
        selectedDemoAccount = account
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

    func refreshActiveMatch() {
        Task {
            await runLoading {
                try await self.loadActiveMatchDetail()
                if self.activeMatch == nil {
                    try await self.loadDiscoveryMap()
                }
            }
        }
    }

    func goBackForTesting() {
        errorMessage = nil

        if selectedPoint != nil {
            selectedPoint = nil
            isOnline = true
            ensureDemoPointsIfNeeded()
            return
        }

        if showHistory {
            showHistory = false
            isOnline = false
            return
        }

        if meetingProposal?.status == .accepted {
            meetingProposal?.status = .pending
            activeMatch?.meetingStatus = .none
            return
        }

        if meetingProposal != nil {
            meetingProposal = nil
            return
        }

        if chatUnlocked {
            activeMatch?.myFirstLoopSent = false
            activeMatch?.theirFirstLoopReceived = false
            messages = []
            return
        }

        if activeMatch != nil {
            activeMatch = nil
            meetingProposal = nil
            messages = []
            isOnline = true
            ensureDemoPointsIfNeeded()
            return
        }

        if isOnline {
            isOnline = false
            return
        }

        if isAuthenticated {
            isAuthenticated = false
            isProfileComplete = false
            isOnline = false
        }
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

    func requestTomorrowExtension() {
        guard let match = activeMatch else { return }

        Task {
            await runLoading {
                do {
                    let response = try await self.apiClient.requestTomorrowExtension(matchId: match.id)
                    self.applyTomorrowExtensionResponse(response)
                } catch {
                    self.activeMatch?.tomorrowExtension = TomorrowExtension(
                        status: .proposed,
                        requestId: UUID(),
                        requestedByMe: true,
                        extendedUntil: nil
                    )
                    self.errorMessage = "Demo mode: tomorrow request saved locally."
                }
            }
        }
    }

    func acceptTomorrowExtension() {
        guard let requestId = activeMatch?.tomorrowExtension.requestId else { return }

        Task {
            await runLoading {
                do {
                    let response = try await self.apiClient.acceptTomorrowExtension(requestId: requestId)
                    self.applyTomorrowExtensionResponse(response)
                } catch {
                    self.activeMatch?.tomorrowExtension = TomorrowExtension(
                        status: .accepted,
                        requestId: requestId,
                        requestedByMe: false,
                        extendedUntil: "Tomorrow"
                    )
                    self.errorMessage = "Demo mode: match kept for tomorrow locally."
                }
            }
        }
    }

    func rejectTomorrowExtension() {
        guard let requestId = activeMatch?.tomorrowExtension.requestId else { return }

        Task {
            await runLoading {
                do {
                    let response = try await self.apiClient.rejectTomorrowExtension(requestId: requestId)
                    self.applyTomorrowExtensionResponse(response)
                } catch {
                    self.activeMatch?.tomorrowExtension = TomorrowExtension(
                        status: .rejected,
                        requestId: requestId,
                        requestedByMe: false,
                        extendedUntil: nil
                    )
                    self.errorMessage = "Demo mode: tomorrow request declined locally."
                }
            }
        }
    }

    func createMeetingProposal() {
        guard let match = activeMatch else { return }
        let suggestion = match.profile.plan.primaryMeetingSuggestion

        Task {
            await runLoading {
                let scheduledDate = self.scheduledDate(for: suggestion.time)
                do {
                    let proposal = try await self.apiClient.createMeetingProposal(
                        matchId: match.id,
                        request: CreateProposalRequestDTO(
                            placeName: suggestion.placeName,
                            placeLat: suggestion.coordinate.latitude,
                            placeLng: suggestion.coordinate.longitude,
                            proposedTime: self.isoString(from: scheduledDate),
                            format: self.mapMeetingFormat(match.profile.plan),
                            note: nil
                        )
                    )
                    self.meetingProposal = self.mapMeetingProposal(proposal)
                } catch {
                    self.meetingProposal = MeetingProposal(
                        id: UUID(),
                        matchId: match.id,
                        proposerUserId: self.currentUserId,
                        placeName: suggestion.placeName,
                        coordinate: suggestion.coordinate,
                        time: self.displayTime(from: scheduledDate),
                        dateLabel: self.dateLabel(for: scheduledDate),
                        status: .pending
                    )
                    self.errorMessage = "Demo mode: meeting proposal saved locally."
                }
            }
        }
    }

    func acceptMeetingProposal() {
        guard let proposal = meetingProposal else { return }

        if let currentUserId, proposal.proposerUserId == currentUserId {
            errorMessage = "Waiting for the other person to accept."
            return
        }

        Task {
            await runLoading {
                do {
                    let response = try await self.apiClient.acceptMeetingProposal(
                        matchId: proposal.matchId,
                        proposalId: proposal.id
                    )
                    self.meetingProposal = self.mapMeetingProposal(response)
                    self.activeMatch?.meetingStatus = .onMyWay
                } catch {
                    self.meetingProposal?.status = .accepted
                    self.activeMatch?.meetingStatus = .onMyWay
                    self.errorMessage = "Demo mode: meeting accepted locally."
                }
            }
        }
    }

    func suggestAnotherMeetingPlace() {
        guard var proposal = meetingProposal else { return }
        let plan = activeMatch?.profile.plan ?? .coffee
        let nextSuggestion = proposal.placeName == plan.primaryMeetingSuggestion.placeName ? plan.alternateMeetingSuggestion : plan.primaryMeetingSuggestion

        Task {
            await runLoading {
                let scheduledDate = self.scheduledDate(for: nextSuggestion.time)
                do {
                    let response = try await self.apiClient.updateMeetingProposal(
                        matchId: proposal.matchId,
                        proposalId: proposal.id,
                        request: UpdateProposalRequestDTO(
                            placeName: nextSuggestion.placeName,
                            placeLat: nextSuggestion.coordinate.latitude,
                            placeLng: nextSuggestion.coordinate.longitude,
                            proposedTime: self.isoString(from: scheduledDate),
                            format: self.mapMeetingFormat(plan),
                            note: nil
                        )
                    )
                    self.meetingProposal = self.mapMeetingProposal(response)
                } catch {
                    proposal.placeName = nextSuggestion.placeName
                    proposal.coordinate = nextSuggestion.coordinate
                    proposal.time = self.displayTime(from: scheduledDate)
                    proposal.dateLabel = self.dateLabel(for: scheduledDate)
                    proposal.status = .pending
                    self.meetingProposal = proposal
                    self.errorMessage = "Demo mode: alternate place saved locally."
                }
            }
        }
    }

    func declineMeetingPlace() {
        meetingProposal = nil
        messages.append(
            Message(
                id: UUID(),
                sender: .me,
                text: "Let's choose another place.",
                createdAt: Date()
            )
        )
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

    private func ensureDemoPointsIfNeeded() {
        if visibleMapPoints.isEmpty {
            mapPoints = MockData.mapPoints
        }
    }

    private func updatePoint(_ id: UUID, state: MapPointState) {
        guard let index = mapPoints.firstIndex(where: { $0.id == id }) else { return }
        mapPoints[index].state = state

        if selectedPoint?.id == id {
            selectedPoint?.state = state
        }
    }

    private func demoLoginAndBootstrap(email: String) async {
        await runLoading {
            do {
                let auth = try await self.apiClient.login(email: email, password: "password123")
                self.currentUserId = auth.user.id
                self.isAuthenticated = true
                try await self.applyBootstrap(self.apiClient.bootstrap())
            } catch {
                self.isAuthenticated = true
                self.isProfileComplete = true
                self.isOnline = false
                self.activeMatch = nil
                self.selectedPoint = nil
                self.mapPoints = MockData.mapPoints
                self.errorMessage = "Demo mode: local flow is available while API is unavailable."
            }
        }
    }

    private func applyBootstrap(_ bootstrap: BootstrapResponseDTO) async throws {
        currentUserId = bootstrap.user.id
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
        isLoading = true
        errorMessage = nil

        let deviceLocation: DeviceLocation
        do {
            deviceLocation = try await locationService.currentLocation()
            currentCoordinate = deviceLocation.coordinate
            currentLocationAccuracyM = deviceLocation.accuracyM
        } catch {
            isOnline = false
            selectedPoint = nil
            mapPoints = []
            errorMessage = locationMessage(for: error)
            isLoading = false
            return
        }

        do {
            _ = try await apiClient.updateTodayIntent(
                UpdateTodayIntentRequestDTO(
                    plan: mapPlan(selectedIntent.plan),
                    intent: mapIntent(selectedIntent.intent),
                    timeToday: mapTime(selectedIntent.timeWindow)
                )
            )
            _ = try await apiClient.goOnline(
                lat: deviceLocation.coordinate.latitude,
                lng: deviceLocation.coordinate.longitude,
                accuracyM: deviceLocation.accuracyM
            )
            showHistory = false
            isOnline = true
            try await loadDiscoveryMap()
        } catch {
            mapPoints = []
            selectedPoint = nil
            showHistory = false
            isOnline = false
            errorMessage = "Could not sync with the staging API. Check backend URL and connection."
        }

        isLoading = false
    }

    private func loadDiscoveryMap() async throws {
        let response = try await apiClient.discoverMap()
        let mappedPoints = response.points.map(mapPoint)
        mapPoints = mappedPoints
        isOnline = true
        if response.discoveryLocked {
            errorMessage = "Discovery is locked while an active match is open."
        } else if mappedPoints.isEmpty {
            errorMessage = "No live nearby points yet. Keep both phones online and refresh."
        }
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
            do {
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
                } else if point.isMutualMock {
                    self.activeMatch = Match(
                        id: UUID(),
                        profile: point.profile,
                        status: .active,
                        myFirstLoopSent: false,
                        theirFirstLoopReceived: false,
                        meetingStatus: .none
                    )
                    self.isOnline = false
                    self.errorMessage = "Demo mode: local match created."
                } else {
                    self.isOnline = true
                    self.errorMessage = "Liked for today. No match yet."
                }
            } catch {
                self.updatePoint(point.id, state: .interested)
                self.selectedPoint = nil

                if point.isMutualMock {
                    self.activeMatch = Match(
                        id: UUID(),
                        profile: point.profile,
                        status: .active,
                        myFirstLoopSent: false,
                        theirFirstLoopReceived: false,
                        meetingStatus: .none
                    )
                    self.isOnline = false
                    self.errorMessage = "Demo mode: local match created."
                } else {
                    self.isOnline = true
                    self.errorMessage = "Liked for today. No match yet."
                }
            }
        }
    }

    private func passPointWithBackend(_ point: MapPoint) async {
        await runLoading {
            do {
                _ = try await self.apiClient.passProfile(point.profile.id)
            } catch {
                self.errorMessage = "Demo mode: hidden for today locally."
            }
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
            meetingStatus: detail.latestMeetingStatus.map { mapMeetingStatus($0.status) } ?? .none,
            tomorrowExtension: mapTomorrowExtension(
                detail.tomorrowExtension,
                matchItem: detail.matchItem
            )
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
            meetingProposal = mapMeetingProposal(proposal)
        } else {
            meetingProposal = nil
        }
    }

    private func sendMockFirstLoopWithBackend(_ match: Match) async {
        await runLoading {
            do {
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
                self.activeMatch?.myFirstLoopSent = true
                self.activeMatch?.theirFirstLoopReceived = true
            } catch {
                self.activeMatch?.myFirstLoopSent = true
                self.activeMatch?.theirFirstLoopReceived = true
                self.errorMessage = "Demo mode: first loop accepted locally."
            }
        }
    }

    private func sendMessageWithBackend(_ text: String) async {
        guard let match = activeMatch else { return }

        await runLoading {
            do {
                let response = try await self.apiClient.sendMessage(matchId: match.id, body: text)
                self.messages.append(
                    Message(id: response.message.id, sender: .me, text: response.message.body, createdAt: Date())
                )
            } catch {
                self.messages.append(Message(id: UUID(), sender: .me, text: text, createdAt: Date()))
                self.errorMessage = "Demo mode: message saved locally."
            }
        }
    }

    private func applyTomorrowExtensionResponse(_ response: TomorrowExtensionResponseDTO) {
        activeMatch?.tomorrowExtension = mapTomorrowExtension(
            request: response.request,
            matchItem: response.matchItem
        )
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

    private func locationMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }

        return "Location is required to go online."
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

    private func mapMeetingProposal(_ dto: MeetingProposalDTO) -> MeetingProposal {
        let proposedDate = date(from: dto.proposedTime)

        return MeetingProposal(
            id: dto.id,
            matchId: dto.matchId,
            proposerUserId: dto.proposerUserId,
            placeName: dto.placeName,
            coordinate: CLLocationCoordinate2D(
                latitude: dto.placeLat ?? 34.0928,
                longitude: dto.placeLng ?? -118.2773
            ),
            time: proposedDate.map { displayTime(from: $0) } ?? dto.proposedTime,
            dateLabel: proposedDate.map { dateLabel(for: $0) } ?? "Today",
            status: mapMeetingProposalStatus(dto.status)
        )
    }

    private func mapMeetingProposalStatus(_ status: String) -> MeetingProposalStatus {
        switch status {
        case "accepted":
            return .accepted
        case "rejected", "cancelled":
            return .rejected
        default:
            return .pending
        }
    }

    private func mapMeetingFormat(_ plan: Plan) -> MeetingFormatDTO {
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

    private func scheduledDate(for displayTime: String) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let targetDay = activeMatch?.tomorrowExtension.status == .accepted
            ? calendar.date(byAdding: .day, value: 1, to: now) ?? now
            : now
        let parts = displayTime.split(separator: ":")
        let hour = parts.first.flatMap { Int($0) } ?? calendar.component(.hour, from: now)
        let minute = parts.dropFirst().first.flatMap { Int($0) } ?? calendar.component(.minute, from: now)
        var components = calendar.dateComponents([.year, .month, .day], from: targetDay)
        components.hour = hour
        components.minute = minute
        components.second = 0
        let proposed = calendar.date(from: components) ?? now

        if proposed <= now {
            return calendar.date(byAdding: .minute, value: 30, to: now) ?? now
        }

        return proposed
    }

    private func isoString(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private func date(from string: String) -> Date? {
        ISO8601DateFormatter().date(from: string)
    }

    private func displayTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func dateLabel(for date: Date) -> String {
        if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        }
        return "Today"
    }

    private func mapTomorrowExtension(
        _ summary: TomorrowExtensionSummaryDTO?,
        matchItem: MatchDTO
    ) -> TomorrowExtension {
        guard let summary else {
            return TomorrowExtension(
                status: matchItem.extendedUntil == nil ? .none : .accepted,
                requestId: nil,
                requestedByMe: false,
                extendedUntil: matchItem.extendedUntil
            )
        }

        return TomorrowExtension(
            status: mapTomorrowExtensionStatus(summary.status),
            requestId: summary.requestId,
            requestedByMe: summary.requestedByMe,
            extendedUntil: summary.extendedUntil
        )
    }

    private func mapTomorrowExtension(
        request: MatchExtensionRequestDTO,
        matchItem: MatchDTO
    ) -> TomorrowExtension {
        TomorrowExtension(
            status: mapTomorrowExtensionStatus(request.status),
            requestId: request.id,
            requestedByMe: request.requestedByUserId != matchItem.otherUserId,
            extendedUntil: matchItem.extendedUntil
        )
    }

    private func mapTomorrowExtensionStatus(_ status: TomorrowExtensionStatusDTO) -> TomorrowExtensionStatus {
        switch status {
        case .none:
            return .none
        case .proposed:
            return .proposed
        case .accepted:
            return .accepted
        case .rejected:
            return .rejected
        case .expired:
            return .expired
        case .cancelled:
            return .cancelled
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
