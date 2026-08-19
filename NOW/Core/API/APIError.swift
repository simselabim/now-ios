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

enum APIErrorMessagePresenter {
    static func message(for error: Error) -> String {
        if error is URLError {
            return "Could not connect. Check your internet connection and try again."
        }

        guard let apiError = error as? APIError else {
            return "Something went wrong. Please try again."
        }

        switch apiError {
        case .unauthorized:
            return "Your session expired. Please sign in again."
        case let .server(statusCode, serverMessage):
            if statusCode >= 500 {
                return "The server could not complete the request. Please try again."
            }
            if let message = cleanedServerMessage(serverMessage) {
                return message
            }
            switch statusCode {
            case 404:
                return "This item is no longer available."
            case 409:
                return "This action conflicts with the current state. Refresh and try again."
            case 413:
                return "This file is too large."
            case 422:
                return "Check the information and try again."
            default:
                return "The request could not be completed. Please try again."
            }
        case .invalidURL, .invalidResponse, .decoding, .missingToken:
            return "The request could not be completed. Please try again."
        }
    }

    private static func cleanedServerMessage(_ message: String?) -> String? {
        guard var message = message?.trimmingCharacters(in: .whitespacesAndNewlines),
              !message.isEmpty else {
            return nil
        }

        for prefix in ["conflict:", "validation:", "bad request:"] {
            if message.lowercased().hasPrefix(prefix) {
                message.removeFirst(prefix.count)
                message = message.trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        guard !message.isEmpty else { return nil }

        message.replaceSubrange(message.startIndex...message.startIndex, with: message.prefix(1).uppercased())
        if message.last.map({ !".!?".contains($0) }) == true {
            message.append(".")
        }
        return message
    }
}
