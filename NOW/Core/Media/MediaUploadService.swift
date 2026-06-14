import Foundation

struct MediaUploadService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func upload(data: Data, intent: UploadIntentResponseDTO) async throws -> DevUploadResponseDTO {
        guard let url = URL(string: intent.uploadUrl) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = intent.method
        for header in intent.headers {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }

        let (responseData, response) = try await session.upload(for: request, from: data)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let message = try? decoder.decode(APIErrorResponse.self, from: responseData).error
            throw APIError.server(statusCode: httpResponse.statusCode, message: message)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(DevUploadResponseDTO.self, from: responseData)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    func download(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode, message: nil)
        }

        return data
    }
}

