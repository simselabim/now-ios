import Foundation

enum APIError: Error, Equatable {
    case invalidURL
    case unauthorized
    case server(statusCode: Int, message: String?)
    case decoding(String)
    case missingToken
    case invalidResponse
}

struct APIErrorResponse: Decodable {
    let error: String
}

