import Foundation

protocol AuthTokenStoring {
    func getAccessToken() async -> String?
    func setAccessToken(_ token: String?) async
    func clear() async
}

actor UserDefaultsAuthTokenStore: AuthTokenStoring {
    private let key = "now.accessToken"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func getAccessToken() async -> String? {
        defaults.string(forKey: key)
    }

    func setAccessToken(_ token: String?) async {
        if let token {
            defaults.set(token, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func clear() async {
        defaults.removeObject(forKey: key)
    }
}

actor InMemoryAuthTokenStore: AuthTokenStoring {
    private var token: String?

    func getAccessToken() async -> String? {
        token
    }

    func setAccessToken(_ token: String?) async {
        self.token = token
    }

    func clear() async {
        token = nil
    }
}

