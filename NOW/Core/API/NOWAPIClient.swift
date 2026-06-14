import Foundation

final class NOWAPIClient {
    private let environment: APIEnvironment
    private let session: URLSession
    private let tokenStore: AuthTokenStoring
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        environment: APIEnvironment = .iOSSimulator,
        session: URLSession = .shared,
        tokenStore: AuthTokenStoring = UserDefaultsAuthTokenStore()
    ) {
        self.environment = environment
        self.session = session
        self.tokenStore = tokenStore

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    @discardableResult
    func register(email: String, password: String) async throws -> AuthResponseDTO {
        let response: AuthResponseDTO = try await send(
            path: "/auth/register",
            method: "POST",
            body: AuthRequest(email: email, password: password),
            requiresAuth: false
        )
        await tokenStore.setAccessToken(response.accessToken)
        return response
    }

    @discardableResult
    func login(email: String, password: String) async throws -> AuthResponseDTO {
        let response: AuthResponseDTO = try await send(
            path: "/auth/login",
            method: "POST",
            body: AuthRequest(email: email, password: password),
            requiresAuth: false
        )
        await tokenStore.setAccessToken(response.accessToken)
        return response
    }

    func logout() async {
        await tokenStore.clear()
    }

    func me() async throws -> MeResponseDTO {
        try await send(path: "/me")
    }

    func bootstrap() async throws -> BootstrapResponseDTO {
        try await send(path: "/app/bootstrap")
    }

    func myProfile() async throws -> MyProfileResponseDTO {
        try await send(path: "/profiles/me")
    }

    func updateProfile(_ request: UpdateProfileRequestDTO) async throws -> ProfileDTO {
        try await send(path: "/profiles/me", method: "PUT", body: request)
    }

    func uploadPhoto(storageKey: String, position: Int, isMain: Bool) async throws -> UploadPhotoResponseDTO {
        try await send(
            path: "/profiles/me/photos",
            method: "POST",
            body: UploadPhotoRequestDTO(storageKey: storageKey, position: position, isMain: isMain)
        )
    }

    func createUploadIntent(
        kind: UploadKindDTO,
        contentType: String,
        fileSizeBytes: Int
    ) async throws -> UploadIntentResponseDTO {
        try await send(
            path: "/media/upload-intent",
            method: "POST",
            body: CreateUploadIntentRequestDTO(
                kind: kind,
                contentType: contentType,
                fileSizeBytes: fileSizeBytes
            )
        )
    }

    func updateTodayIntent(_ request: UpdateTodayIntentRequestDTO) async throws -> TodayIntentDTO {
        try await send(path: "/today-intent", method: "PUT", body: request)
    }

    func goOnline(lat: Double, lng: Double, accuracyM: Int?) async throws -> OnlineResponseDTO {
        try await send(
            path: "/online",
            method: "POST",
            body: GoOnlineRequestDTO(lat: lat, lng: lng, accuracyM: accuracyM)
        )
    }

    func discoverMap(radiusM: Int = 2_000) async throws -> DiscoverMapResponseDTO {
        try await send(path: "/discover/map?radius_m=\(radiusM)")
    }

    func openMapPoint(_ pointId: UUID) async throws -> MapPointProfileResponseDTO {
        try await send(path: "/discover/points/\(pointId.uuidString)")
    }

    func likeProfile(_ profileId: UUID) async throws -> LikeProfileResponseDTO {
        try await send(path: "/discover/profiles/\(profileId.uuidString)/like", method: "POST")
    }

    func passProfile(_ profileId: UUID) async throws -> ProfileInteractionResponseDTO {
        try await send(path: "/discover/profiles/\(profileId.uuidString)/pass", method: "POST")
    }

    func activeMatch() async throws -> ActiveMatchResponseDTO {
        try await send(path: "/matches/active")
    }

    func activeMatchDetail() async throws -> ActiveMatchDetailResponseDTO {
        try await send(path: "/matches/active/detail")
    }

    func sendFirstLoop(matchId: UUID, storageKey: String, durationMs: Int) async throws -> UploadFirstLoopResponseDTO {
        try await send(
            path: "/matches/\(matchId.uuidString)/loops",
            method: "POST",
            body: UploadFirstLoopRequestDTO(storageKey: storageKey, durationMs: durationMs)
        )
    }

    func messages(matchId: UUID) async throws -> MessagesResponseDTO {
        try await send(path: "/matches/\(matchId.uuidString)/messages")
    }

    func sendMessage(matchId: UUID, body: String) async throws -> SendMessageResponseDTO {
        try await send(
            path: "/matches/\(matchId.uuidString)/messages",
            method: "POST",
            body: SendMessageRequestDTO(body: body)
        )
    }

    func createMeetingProposal(matchId: UUID, request: CreateProposalRequestDTO) async throws -> MeetingProposalDTO {
        try await send(
            path: "/matches/\(matchId.uuidString)/meeting-proposals",
            method: "POST",
            body: request
        )
    }

    func acceptMeetingProposal(matchId: UUID, proposalId: UUID) async throws -> MeetingProposalDTO {
        try await send(
            path: "/matches/\(matchId.uuidString)/meeting-proposals/\(proposalId.uuidString)/accept",
            method: "POST"
        )
    }

    func updateMeetingStatus(matchId: UUID, status: MeetingStatusValueDTO) async throws -> MeetingStatusDTO {
        try await send(
            path: "/matches/\(matchId.uuidString)/meeting-status",
            method: "POST",
            body: UpdateMeetingStatusRequestDTO(status: status)
        )
    }

    func weMet(matchId: UUID) async throws -> WeMetResponseDTO {
        try await send(path: "/matches/\(matchId.uuidString)/we-met", method: "POST")
    }

    func history() async throws -> HistoryResponseDTO {
        try await send(path: "/history")
    }

    private func send<Response: Decodable>(
        path: String,
        method: String = "GET",
        requiresAuth: Bool = true
    ) async throws -> Response {
        let emptyBody: EmptyRequest? = nil
        return try await send(path: path, method: method, body: emptyBody, requiresAuth: requiresAuth)
    }

    private func send<RequestBody: Encodable, Response: Decodable>(
        path: String,
        method: String = "GET",
        body: RequestBody?,
        requiresAuth: Bool = true
    ) async throws -> Response {
        var request = try await makeRequest(path: path, method: method, requiresAuth: requiresAuth)
        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    private func makeRequest(path: String, method: String, requiresAuth: Bool) async throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: environment.baseURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if requiresAuth {
            guard let token = await tokenStore.getAccessToken() else {
                throw APIError.missingToken
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = try? decoder.decode(APIErrorResponse.self, from: data).error
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.server(statusCode: httpResponse.statusCode, message: message)
        }
    }
}

private struct EmptyRequest: Encodable {}

