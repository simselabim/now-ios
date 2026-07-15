@preconcurrency import CoreLocation
import Foundation

struct DeviceLocation {
    let coordinate: CLLocationCoordinate2D
    let accuracyM: Int?
}

enum LocationServiceError: LocalizedError {
    case denied
    case restricted
    case servicesDisabled
    case unavailable
    case timedOut

    var errorDescription: String? {
        switch self {
        case .denied:
            return "Location permission is off. Enable it in Settings to go online."
        case .restricted:
            return "Location is restricted on this device."
        case .servicesDisabled:
            return "Location Services are disabled on this device."
        case .unavailable:
            return "Could not get your current location."
        case .timedOut:
            return "Location took too long. Try again near a window or with Wi-Fi on."
        }
    }
}

@MainActor
final class LocationService: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<DeviceLocation, Error>?
    private var timeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentLocation() async throws -> DeviceLocation {
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationServiceError.servicesDisabled
        }

        if let continuation {
            continuation.resume(throwing: LocationServiceError.unavailable)
            self.continuation = nil
            timeoutTask?.cancel()
            timeoutTask = nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.startTimeout()

            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied:
                finish(.failure(LocationServiceError.denied))
            case .restricted:
                finish(.failure(LocationServiceError.restricted))
            @unknown default:
                finish(.failure(LocationServiceError.unavailable))
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied:
            finish(.failure(LocationServiceError.denied))
        case .restricted:
            finish(.failure(LocationServiceError.restricted))
        case .notDetermined:
            break
        @unknown default:
            finish(.failure(LocationServiceError.unavailable))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            finish(.failure(LocationServiceError.unavailable))
            return
        }

        let accuracy = location.horizontalAccuracy >= 0 ? Int(location.horizontalAccuracy.rounded()) : nil
        finish(.success(DeviceLocation(coordinate: location.coordinate, accuracyM: accuracy)))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError,
           clError.code == .denied {
            finish(.failure(LocationServiceError.denied))
            return
        }

        finish(.failure(LocationServiceError.unavailable))
    }

    private func startTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(12))
            await MainActor.run {
                self?.finish(.failure(LocationServiceError.timedOut))
            }
        }
    }

    private func finish(_ result: Result<DeviceLocation, Error>) {
        guard let continuation else { return }

        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation.resume(with: result)
    }
}
