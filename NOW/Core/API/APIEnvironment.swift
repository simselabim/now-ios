import Foundation

struct APIEnvironment: Equatable {
    let baseURL: URL

    static let appDefault = APIEnvironment(baseURL: configuredBaseURL ?? iOSSimulator.baseURL)
    static let iOSSimulator = APIEnvironment(baseURL: URL(string: "http://127.0.0.1:8080")!)
    static let androidEmulatorReference = APIEnvironment(baseURL: URL(string: "http://10.0.2.2:8080")!)

    static func physicalDevice(macLANIP: String, port: Int = 8080) -> APIEnvironment {
        APIEnvironment(baseURL: URL(string: "http://\(macLANIP):\(port)")!)
    }

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
