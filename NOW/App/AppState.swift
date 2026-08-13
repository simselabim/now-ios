import Foundation
import CoreLocation
import AVFoundation

@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isProfileComplete = false
    @Published var isOnline = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedDemoAccount = DemoAccount.defaultAccount
    @Published var todayIntent = TodayIntent(plan: .coffee, intent: .date, timeWindow: .evening)
    @Published var mapPoints: [MapPoint] = []
    @Published var currentCoordinate: CLLocationCoordinate2D?
    @Published var currentLocationAccuracyM: Int?
    @Published var selectedPoint: MapPoint?
    @Published var activeMatch: Match?
    @Published var isViewingActiveMatchMap = false
    @Published private(set) var myFirstLoopURL: URL?
    @Published private(set) var theirFirstLoopURL: URL?
    @Published var messages: [Message] = []
    @Published var meetingProposal: MeetingProposal?
    @Published var history: [HistoryItem] = []
    @Published var selectedAppTab: AppTab = .search
    @Published private(set) var currentUserId: UUID?
    @Published private(set) var currentUserEmail: String?
    @Published private(set) var myProfile: ProfileDTO?
    @Published private(set) var didAttemptSessionRestore = false

    private let apiClient: NOWAPIClient
    private let locationService: LocationService
    private var cachedLoopFiles: [String: URL] = [:]
    private var loopDownloadTasks: [String: Task<URL?, Never>] = [:]
    private var realtimeConnectionTask: Task<Void, Never>?
    private var realtimeConnectionID: UUID?
    private var processedRealtimeEventIds: Set<UUID> = []
    private var processedRealtimeEventOrder: [UUID] = []
    private var lastRealtimeVersion: UInt64?
    private var profilePreviewRequestID: UUID?

    init(apiClient: NOWAPIClient = NOWAPIClient()) {
        self.apiClient = apiClient
        self.locationService = LocationService()
    }

    var visibleMapPoints: [MapPoint] {
        mapPoints.filter { $0.state != .blocked }
    }

    var showHistory: Bool {
        get { selectedAppTab == .history }
        set {
            if newValue {
                selectedAppTab = .history
            } else if selectedAppTab == .history {
                selectedAppTab = .search
            }
        }
    }

    var showAccount: Bool {
        get { selectedAppTab == .account }
        set {
            if newValue {
                selectedAppTab = .account
            } else if selectedAppTab == .account {
                selectedAppTab = .search
            }
        }
    }

    var chatUnlocked: Bool {
        activeMatch?.myFirstLoopSent == true && activeMatch?.theirFirstLoopReceived == true
    }

    var activeMatchMapPoints: [MapPoint] {
        guard let activeMatch else { return visibleMapPoints }

        if visibleMapPoints.contains(where: { $0.profile.id == activeMatch.profile.id }) {
            return visibleMapPoints
        }

        let matchPoint = MapPoint(
            id: activeMatch.profile.id,
            profile: activeMatch.profile,
            approximateCoordinate: meetingProposal?.coordinate ?? currentCoordinate ?? CLLocationCoordinate2D(latitude: -8.667630, longitude: 115.139708),
            state: .interested,
            isMutualMock: true
        )

        return [matchPoint] + visibleMapPoints
    }

    func login() {
        let account = selectedDemoAccount
        Task {
            await demoLoginAndBootstrap(email: account.email)
        }
    }

    func authenticate(email: String, password: String, register: Bool) {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            do {
                let auth = try await (register
                    ? self.apiClient.register(email: email, password: password)
                    : self.apiClient.login(email: email, password: password))
                self.currentUserId = auth.user.id
                self.currentUserEmail = auth.user.email
                self.isAuthenticated = true
                try await self.applyBootstrap(self.apiClient.bootstrap())
            } catch APIError.unauthorized {
                await apiClient.logout()
                resetAuthenticatedState()
                errorMessage = "Email or password is incorrect."
            } catch {
                errorMessage = authenticationErrorMessage(error, registering: register)
            }
        }
    }

    func restoreSession() async {
        guard !didAttemptSessionRestore else { return }
        defer { didAttemptSessionRestore = true }

        guard await apiClient.hasStoredSession() else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let me = try await apiClient.me()
            currentUserId = me.user.id
            currentUserEmail = me.user.email
            isAuthenticated = true
            try await applyBootstrap(apiClient.bootstrap())
        } catch {
            await apiClient.logout()
            resetAuthenticatedState()
        }
    }

    func logout() {
        Task {
            await apiClient.logout()
            resetAuthenticatedState()
        }
    }

    func openAccount() {
        selectAppTab(.account)
    }

    func closeAccount() {
        selectAppTab(.search)
    }

    func selectAppTab(_ tab: AppTab) {
        errorMessage = nil
        isViewingActiveMatchMap = false
        selectedAppTab = tab

        if tab == .account {
            Task { await loadMyProfile() }
        }
    }

    func loadMyProfile() async {
        await runLoading {
            self.myProfile = try await self.apiClient.myProfile().profile
        }
    }

    func saveProfile(
        displayName: String,
        birthDate: String,
        gender: String,
        bio: String,
        interests: [String]
    ) {
        Task {
            await runLoading {
                let profile = try await self.apiClient.updateProfile(
                    UpdateProfileRequestDTO(
                        displayName: displayName,
                        birthDate: birthDate,
                        gender: gender,
                        bio: bio,
                        interests: interests
                    )
                )
                self.myProfile = profile
                self.isProfileComplete = profile.isPublishable
            }
        }
    }

    func createProfile(
        displayName: String,
        birthDate: String,
        gender: String,
        bio: String,
        photoData: Data
    ) {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            do {
                myProfile = try await apiClient.updateProfile(
                    UpdateProfileRequestDTO(
                        displayName: displayName,
                        birthDate: birthDate,
                        gender: gender,
                        bio: bio,
                        interests: []
                    )
                )

                let upload = try await uploadMainProfilePhoto(photoData)
                isProfileComplete = upload.isProfilePublishable
                if !upload.isProfilePublishable {
                    errorMessage = "Add a name, birth date, gender, bio, and one photo to continue."
                }
            } catch APIError.unauthorized {
                await apiClient.logout()
                resetAuthenticatedState()
                errorMessage = "Your session expired. Please sign in again."
            } catch {
                errorMessage = profileCreationErrorMessage(error)
            }
        }
    }

    func updateProfilePhoto(photoData: Data) {
        Task {
            await runLoading {
                _ = try await self.uploadMainProfilePhoto(photoData)
            }
        }
    }

    func deleteAccount() {
        Task {
            await runLoading {
                let response = try await self.apiClient.deleteAccount()
                guard response.deleted else {
                    throw APIError.invalidResponse
                }
                self.resetAuthenticatedState()
            }
        }
    }

    func loginAndOpenMapForTesting() {
        let account = selectedDemoAccount
        Task {
            await demoLoginAndBootstrap(email: account.email)
            openLAStateForTesting("map")
        }
    }

    func loginAndGoOnlineForTesting() {
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

    func runServerSync() async {
        defer { stopRealtimeConnection() }

        while !Task.isCancelled {
            if isAuthenticated, isProfileComplete, currentUserId != nil {
                startRealtimeConnectionIfNeeded()
            } else {
                stopRealtimeConnection()
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }

    func applicationDidBecomeActive() {
        guard isAuthenticated, isProfileComplete, currentUserId != nil else { return }

        stopRealtimeConnection()
        Task {
            do {
                try await reconcileAfterRealtimeConnect()
            } catch {
                // The reconnecting WebSocket will deliver an authoritative snapshot.
            }
            startRealtimeConnectionIfNeeded()
        }
    }

    func goBackForTesting() {
        errorMessage = nil

        if isViewingActiveMatchMap {
            isViewingActiveMatchMap = false
            return
        }

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
            isViewingActiveMatchMap = false
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
        if isViewingActiveMatchMap {
            guard point.profile.id == activeMatch?.profile.id else {
                errorMessage = "Map is read-only while this match is active."
                return
            }

            returnToActiveMatch()
            return
        }

        selectedPoint = point
        updatePoint(point.id, state: point.state == .unseen ? .viewed : point.state)

        let requestID = UUID()
        profilePreviewRequestID = requestID

        Task {
            await openPointWithBackend(point, requestID: requestID)
        }
    }

    func closeProfilePreview() {
        profilePreviewRequestID = nil
        selectedPoint = nil
    }

    func showActiveMatchMap() {
        guard activeMatch != nil else { return }
        errorMessage = "Map is read-only while this match is active."
        selectedPoint = nil
        selectedAppTab = .search
        isViewingActiveMatchMap = true
        ensureDemoPointsIfNeeded()
    }

    func returnToActiveMatch() {
        guard activeMatch != nil else {
            isViewingActiveMatchMap = false
            return
        }

        errorMessage = nil
        selectedPoint = nil
        isViewingActiveMatchMap = false
    }

    func markInterested(_ point: MapPoint) {
        Task {
            await likePointWithBackend(point)
        }
    }

    func block(_ point: MapPoint) {
        updatePoint(point.id, state: .blocked)
        selectedPoint = nil
    }

    func sendFirstLoop(videoURL: URL) {
        guard let match = activeMatch else { return }

        Task {
            await sendFirstLoopWithBackend(match, videoURL: videoURL)
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
        guard let match = activeMatch, status != .none else { return }

        Task {
            await runLoading {
                do {
                    let response = try await self.apiClient.updateMeetingStatus(
                        matchId: match.id,
                        status: self.mapMeetingStatus(status)
                    )
                    self.activeMatch?.meetingStatus = self.mapMeetingStatus(response.status)
                } catch {
                    self.activeMatch?.meetingStatus = status
                    self.errorMessage = "Demo mode: meeting status saved locally."
                }
            }
        }
    }

    func weMet() {
        guard let match = activeMatch else { return }

        Task {
            await runLoading {
                do {
                    let response = try await self.apiClient.weMet(matchId: match.id)
                    self.finishWeMetFlow(match: match, completed: response.completed)
                } catch {
                    self.finishWeMetFlow(match: match, completed: false)
                    self.errorMessage = "Demo mode: We Met saved locally."
                }
            }
        }
    }

    func cancelMatch() {
        guard let match = activeMatch else { return }

        // UI preview states do not have a server-backed user or match.
        guard currentUserId != nil else {
            clearActiveMatchState()
            selectedPoint = nil
            showHistory = false
            isOnline = true
            ensureDemoPointsIfNeeded()
            return
        }

        Task {
            await runLoading {
                _ = try await self.apiClient.cancelMatch(matchId: match.id)
                self.clearActiveMatchState()
                self.selectedPoint = nil
                self.showHistory = false
                self.isOnline = true
                try await self.loadDiscoveryMap()
            }
        }
    }

    func closeHistory() {
        selectAppTab(.search)
    }

    private func ensureDemoPointsIfNeeded() {
        if visibleMapPoints.isEmpty {
            mapPoints = MockData.mapPoints
        }
    }

    private func uploadMainProfilePhoto(_ photoData: Data) async throws -> UploadPhotoResponseDTO {
        let uploadIntent = try await apiClient.createUploadIntent(
            kind: .profilePhoto,
            contentType: "image/jpeg",
            fileSizeBytes: photoData.count
        )
        _ = try await MediaUploadService().upload(data: photoData, intent: uploadIntent)
        let upload = try await apiClient.uploadPhoto(
            storageKey: uploadIntent.storageKey,
            position: 1,
            isMain: true
        )
        myProfile = try await apiClient.myProfile().profile
        isProfileComplete = upload.isProfilePublishable
        return upload
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
                self.currentUserEmail = auth.user.email
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
        currentUserEmail = bootstrap.user.email
        myProfile = bootstrap.profile
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
        #if DEBUG
        deviceLocation = DeviceLocation(
            coordinate: CLLocationCoordinate2D(latitude: -8.667630, longitude: 115.139708),
            accuracyM: 25
        )
        currentCoordinate = deviceLocation.coordinate
        currentLocationAccuracyM = deviceLocation.accuracyM
        #else
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
        #endif

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
        let response = try await apiClient.discoverMap(radiusM: 50_000)
        let mappedPoints = response.points.map(mapPoint)
        mapPoints = mappedPoints
        isOnline = true
        if response.discoveryLocked {
            errorMessage = "Discovery is locked while an active match is open."
        } else if mappedPoints.isEmpty {
            errorMessage = "No live nearby points yet. Keep both phones online and refresh."
        } else {
            errorMessage = nil
        }
    }

    private func openPointWithBackend(_ point: MapPoint, requestID: UUID) async {
        await runLoading {
            let response = try await self.apiClient.openMapPoint(point.id)
            guard self.profilePreviewRequestID == requestID,
                  self.selectedPoint?.id == point.id else {
                return
            }

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

    private func loadActiveMatchDetail() async throws {
        let response = try await apiClient.activeMatchDetail()
        await applyActiveMatchDetail(response)
    }

    private func applyActiveMatchDetail(_ response: ActiveMatchDetailResponseDTO) async {
        guard let detail = response.matchItem else {
            clearActiveMatchState()
            return
        }

        let profile = mapProfile(detail.otherProfile)
        let myLoop = detail.loops.first { $0.userId != detail.matchItem.otherUserId }
        let theirLoop = detail.loops.first { $0.userId == detail.matchItem.otherUserId }
        let myLoopSent = myLoop != nil
        let theirLoopReceived = theirLoop != nil
        myFirstLoopURL = await playbackURL(for: myLoop)
        theirFirstLoopURL = await playbackURL(for: theirLoop)
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
        selectedPoint = nil
        isOnline = false
        errorMessage = nil
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

    private func clearActiveMatchState() {
        activeMatch = nil
        isViewingActiveMatchMap = false
        myFirstLoopURL = nil
        theirFirstLoopURL = nil
        clearLoopMediaCache()
        meetingProposal = nil
        messages = []
    }

    private func startRealtimeConnectionIfNeeded() {
        guard realtimeConnectionTask == nil,
              isAuthenticated,
              isProfileComplete,
              currentUserId != nil else {
            return
        }

        let connectionID = UUID()
        realtimeConnectionID = connectionID
        realtimeConnectionTask = Task { [weak self] in
            guard let self else { return }
            await self.consumeRealtimeEvents(connectionID: connectionID)
        }
    }

    private func stopRealtimeConnection() {
        realtimeConnectionTask?.cancel()
        realtimeConnectionTask = nil
        realtimeConnectionID = nil
        resetRealtimeOrdering()
    }

    private func consumeRealtimeEvents(connectionID: UUID) async {
        var retryDelaySeconds = 1.0

        while !Task.isCancelled, isAuthenticated, isProfileComplete, currentUserId != nil {
            do {
                resetRealtimeOrdering()
                let events = try await apiClient.realtimeEvents()
                retryDelaySeconds = 1
                try await reconcileAfterRealtimeConnect()
                for try await event in events {
                    guard !Task.isCancelled, isAuthenticated else { break }
                    await applyRealtimeEvent(event)
                }
            } catch {
                // Reconnect below while preserving the last usable screen.
            }

            guard !Task.isCancelled, isAuthenticated else { break }
            try? await Task.sleep(for: .seconds(retryDelaySeconds))
            retryDelaySeconds = min(retryDelaySeconds * 2, 30)
        }

        if realtimeConnectionID == connectionID {
            realtimeConnectionTask = nil
            realtimeConnectionID = nil
        }
    }

    private func applyRealtimeEvent(_ event: RealtimeEventDTO) async {
        guard shouldApplyRealtimeEvent(event) else { return }

        switch event.type {
        case .snapshot, .matchCreated, .matchUpdated, .firstLoopReceived,
             .messageCreated, .meetingStatusUpdated:
            guard let detail = event.detail else { return }
            await applyActiveMatchDetail(detail)
        case .discoveryChanged:
            if activeMatch == nil, isOnline, selectedPoint == nil {
                try? await loadDiscoveryMap()
            }
        case .matchClosed:
            let keepHistoryVisible = showHistory
            clearActiveMatchState()
            if !keepHistoryVisible {
                isOnline = true
                try? await loadDiscoveryMap()
            }
        case .error:
            errorMessage = event.message ?? "Realtime sync failed. Reconnecting…"
        }
    }

    private func shouldApplyRealtimeEvent(_ event: RealtimeEventDTO) -> Bool {
        guard !processedRealtimeEventIds.contains(event.eventId) else { return false }
        if event.type != .snapshot,
           let lastRealtimeVersion,
           event.version <= lastRealtimeVersion {
            return false
        }

        processedRealtimeEventIds.insert(event.eventId)
        processedRealtimeEventOrder.append(event.eventId)
        if processedRealtimeEventOrder.count > 256 {
            let expired = processedRealtimeEventOrder.removeFirst()
            processedRealtimeEventIds.remove(expired)
        }
        lastRealtimeVersion = event.version
        return true
    }

    private func resetRealtimeOrdering() {
        processedRealtimeEventIds.removeAll(keepingCapacity: true)
        processedRealtimeEventOrder.removeAll(keepingCapacity: true)
        lastRealtimeVersion = nil
    }

    private func reconcileAfterRealtimeConnect() async throws {
        let hadActiveMatch = activeMatch != nil
        try await loadActiveMatchDetail()
        guard activeMatch == nil else { return }

        if hadActiveMatch {
            isOnline = true
        }
        if isOnline, selectedPoint == nil {
            try await loadDiscoveryMap()
        }
    }

    private func refreshActiveMatchInBackground(matchId: UUID) {
        Task { [weak self] in
            guard let self else { return }

            do {
                let response = try await self.apiClient.activeMatchDetail()
                guard self.isAuthenticated, self.activeMatch?.id == matchId else { return }
                await self.applyActiveMatchDetail(response)
            } catch {
                // The realtime reconnect snapshot remains the fallback for transient failures.
            }
        }
    }

    private func playbackURL(for loop: LoopDTO?) async -> URL? {
        guard let loop else { return nil }
        if let cachedURL = cachedLoopFiles[loop.storageKey],
           FileManager.default.fileExists(atPath: cachedURL.path) {
            return cachedURL
        }
        cachedLoopFiles[loop.storageKey] = nil

        if let downloadTask = loopDownloadTasks[loop.storageKey] {
            return await downloadTask.value
        }

        guard let remoteURL = APIEnvironment.appDefault.mediaURL(storageKey: loop.storageKey) else {
            return nil
        }

        let downloadTask = Task<URL?, Never> {
            do {
                let data = try await MediaUploadService().download(from: remoteURL.absoluteString)
                let fileExtension = remoteURL.pathExtension.isEmpty ? "mp4" : remoteURL.pathExtension
                let localURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("now-loop-\(loop.id.uuidString).\(fileExtension)")
                try data.write(to: localURL, options: .atomic)
                return localURL
            } catch {
                return nil
            }
        }
        loopDownloadTasks[loop.storageKey] = downloadTask

        let localURL = await downloadTask.value
        loopDownloadTasks[loop.storageKey] = nil
        if let localURL {
            cachedLoopFiles[loop.storageKey] = localURL
        }
        return localURL
    }

    private func cacheLocalLoopFile(_ sourceURL: URL, for loop: LoopDTO) -> URL? {
        let fileExtension = sourceURL.pathExtension.isEmpty ? "mp4" : sourceURL.pathExtension
        let localURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("now-loop-\(loop.id.uuidString).\(fileExtension)")

        do {
            if sourceURL.standardizedFileURL != localURL.standardizedFileURL {
                try? FileManager.default.removeItem(at: localURL)
                try FileManager.default.copyItem(at: sourceURL, to: localURL)
            }
            cachedLoopFiles[loop.storageKey] = localURL
            return localURL
        } catch {
            return nil
        }
    }

    private func clearLoopMediaCache() {
        loopDownloadTasks.values.forEach { $0.cancel() }
        loopDownloadTasks = [:]
        cachedLoopFiles = [:]
    }

    private func sendFirstLoopWithBackend(_ match: Match, videoURL: URL) async {
        await runLoading {
            var stage = "preparing the video"
            var uploadURL = videoURL
            do {
                uploadURL = try await LoopVideoProcessor.prepareForUpload(videoURL)
                defer {
                    if uploadURL != videoURL {
                        try? FileManager.default.removeItem(at: uploadURL)
                    }
                }

                stage = "reading the prepared video"
                let asset = AVURLAsset(url: uploadURL)
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)
                guard durationSeconds.isFinite, durationSeconds > 0, durationSeconds <= 10.5 else {
                    self.errorMessage = "Your First Loop must be 10 seconds or shorter."
                    return
                }

                let fileSize = try uploadURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
                guard let fileSize, fileSize > 0 else {
                    self.errorMessage = "The selected First Loop file is empty."
                    return
                }
                guard fileSize <= 25 * 1024 * 1024 else {
                    self.errorMessage = "This video is too large. Record a shorter First Loop."
                    return
                }
                stage = "requesting an upload"
                let intent = try await self.apiClient.createUploadIntent(
                    kind: .firstLoop,
                    contentType: "video/mp4",
                    fileSizeBytes: fileSize
                )
                stage = "uploading the video"
                _ = try await MediaUploadService().upload(fileURL: uploadURL, intent: intent)
                stage = "attaching the video to the match"
                let response = try await self.apiClient.sendFirstLoop(
                    matchId: match.id,
                    storageKey: intent.storageKey,
                    durationMs: Int(durationSeconds * 1_000)
                )

                guard self.activeMatch?.id == match.id else { return }

                let localPlaybackURL = self.cacheLocalLoopFile(
                    uploadURL,
                    for: response.loopItem
                ) ?? videoURL
                self.cachedLoopFiles[response.loopItem.storageKey] = localPlaybackURL
                self.myFirstLoopURL = localPlaybackURL
                self.activeMatch?.myFirstLoopSent = true
                if response.chatUnlocked {
                    self.activeMatch?.theirFirstLoopReceived = true
                    if self.theirFirstLoopURL == nil {
                        self.refreshActiveMatchInBackground(matchId: match.id)
                    }
                }
            } catch {
                self.errorMessage = "First Loop failed while \(stage): \(self.uploadErrorDetail(error))"
            }
        }
    }

    private func uploadErrorDetail(_ error: Error) -> String {
        if case let APIError.server(statusCode, message) = error {
            return message ?? "server returned HTTP \(statusCode)"
        }
        if let apiError = error as? APIError {
            return String(describing: apiError)
        }
        return (error as NSError).localizedDescription
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
                self.errorMessage = "Message was not sent. Please try again."
            }
        }
    }

    private func finishWeMetFlow(match: Match, completed: Bool) {
        history.insert(
            HistoryItem(
                id: UUID(),
                name: match.profile.name,
                detail: "\(match.profile.plan.rawValue) \(meetingProposal?.dateLabel.lowercased() ?? "today")",
                status: completed ? "Completed" : "Awaiting confirmation"
            ),
            at: 0
        )
        activeMatch = nil
        isViewingActiveMatchMap = false
        meetingProposal = nil
        messages = []
        showHistory = true
        isOnline = false
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
        } catch APIError.unauthorized {
            await apiClient.logout()
            resetAuthenticatedState()
            errorMessage = "Your session expired. Please sign in again."
        } catch {
            errorMessage = String(describing: error)
        }
        isLoading = false
    }

    private func resetAuthenticatedState() {
        stopRealtimeConnection()
        errorMessage = nil
        isAuthenticated = false
        isProfileComplete = false
        isOnline = false
        currentUserId = nil
        currentUserEmail = nil
        myProfile = nil
        selectedPoint = nil
        activeMatch = nil
        meetingProposal = nil
        messages = []
        showHistory = false
        showAccount = false
        selectedAppTab = .search
        myFirstLoopURL = nil
        theirFirstLoopURL = nil
        clearLoopMediaCache()
    }

    private func authenticationErrorMessage(_ error: Error, registering: Bool) -> String {
        if case let APIError.server(statusCode, message) = error {
            let serverMessage = message?.lowercased() ?? ""

            if statusCode == 422, serverMessage.contains("password") {
                return "Password must be at least 8 characters."
            }
            if statusCode == 409 || serverMessage.contains("already exists") {
                return "An account with this email already exists. Sign in instead."
            }
            if statusCode == 422 {
                return "Check the email and password, then try again."
            }
        }

        if error is URLError {
            return "Could not connect to the server. Check your internet connection."
        }

        return registering
            ? "Could not create the account. Please try again."
            : "Could not sign in. Please try again."
    }

    private func profileCreationErrorMessage(_ error: Error) -> String {
        if case let APIError.server(statusCode, _) = error {
            if statusCode == 413 {
                return "This photo is too large. Choose another photo."
            }
            if statusCode == 422 {
                return "Check the profile fields and photo, then try again."
            }
        }

        if error is URLError {
            return "Could not connect to the server. Check your internet connection."
        }

        return "Could not create your profile. Please try again."
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
                prompt: dto.bio,
                mainPhotoURL: mainPhotoURL(from: dto.photos),
                introLoopURL: dto.introLoop.flatMap { APIEnvironment.appDefault.mediaURL(storageKey: $0.storageKey) }
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
            prompt: "Open to meet today.",
            mainPhotoURL: fallback?.mainPhotoStorageKey.flatMap(APIEnvironment.appDefault.mediaURL),
            introLoopURL: nil
        )
    }

    private func mainPhotoURL(from photos: [PhotoDTO]) -> URL? {
        let photo = photos.first(where: \.isMain) ?? photos.sorted { $0.position < $1.position }.first
        guard let photo else { return nil }
        return APIEnvironment.appDefault.mediaURL(storageKey: photo.storageKey)
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

    private func mapMeetingStatus(_ status: MeetingStatus) -> MeetingStatusValueDTO {
        switch status {
        case .onMyWay:
            return .onMyWay
        case .arrived:
            return .arrived
        case .delayed:
            return .delayed
        case .none:
            return .onMyWay
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
