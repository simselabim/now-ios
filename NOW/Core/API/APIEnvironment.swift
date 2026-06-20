import Foundation

struct APIEnvironment: Equatable {
    let baseURL: URL

    static let appDefault = APIEnvironment(baseURL: configuredBaseURL ?? iOSSimulator.baseURL)
    static let iOSSimulator = APIEnvironment(baseURL: URL(string: "http://127.0.0.1:8080")!)
    static let androidEmulatorReference = APIEnvironment(baseURL: URL(string: "http://10.0.2.2:8080")!)

    static func physicalDevice(macLANIP: String, port: Int = 8080) -> APIEnvironment {
        APIEnvironment(baseURL: URL(string: "http://\(macLANIP):\(port)")!)
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
