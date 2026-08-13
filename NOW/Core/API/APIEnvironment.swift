import Foundation

struct APIEnvironment: Equatable {
    let baseURL: URL

    static let appDefault = APIEnvironment(
        baseURL: configuredBaseURL ?? URL(string: "http://68.183.179.8:8080")!
    )

    func mediaURL(storageKey: String) -> URL? {
        URL(
            string: "\(baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/dev/uploads/\(storageKey)"
        )
    }

    func webSocketURL(path: String) -> URL? {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        components?.path = path
        return components?.url
    }

    private static var configuredBaseURL: URL? {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "NOWAPIBaseURL") as? String,
            !value.isEmpty,
            !value.contains("$(")
        else {
            return nil
        }

        return URL(string: value)
    }
}
