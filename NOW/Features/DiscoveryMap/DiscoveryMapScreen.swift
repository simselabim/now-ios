import MapKit
import SwiftUI

struct DiscoveryMapScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        CityMap(points: appState.visibleMapPoints, userCoordinate: appState.currentCoordinate) { point in
            appState.viewPoint(point)
        }
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .top) {
            MapHeader(isLoading: appState.isLoading, back: {
                appState.goBackForTesting()
            }, refresh: {
                appState.refreshActiveMatch()
            }, goOffline: {
                appState.goOffline()
            })
            .padding(.horizontal, 18)
            .padding(.top, 14)
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 10) {
                if let error = appState.errorMessage {
                    Text(error)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(NOWColor.coral)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NOWColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                MapPersonCard(point: appState.visibleMapPoints.first) {
                    if let point = appState.visibleMapPoints.first {
                        appState.viewPoint(point)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }
}

private struct MapHeader: View {
    let isLoading: Bool
    let back: () -> Void
    let refresh: () -> Void
    let goOffline: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            NOWBackButton(action: back)

            VStack(alignment: .leading, spacing: 4) {
                NOWLogo(compact: true)
                Text(isLoading ? "Syncing nearby" : "Nearby for today")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NOWColor.inkSoft)
            }

            Spacer()

            if isLoading {
                ProgressView()
                    .tint(NOWColor.lime)
                    .padding(10)
                    .background(NOWColor.surface.opacity(0.92))
                    .clipShape(Circle())
            }

            Button {
                refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption.weight(.black))
                    .foregroundStyle(NOWColor.ink)
                    .frame(width: 38, height: 38)
                    .background(NOWColor.surface.opacity(0.92))
                    .clipShape(Circle())
            }

            Button("Off") {
                goOffline()
            }
            .font(.caption.weight(.black))
            .foregroundStyle(NOWColor.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(NOWColor.surface.opacity(0.92))
            .clipShape(Capsule())
        }
    }
}

private struct CityMap: View {
    let points: [MapPoint]
    let userCoordinate: CLLocationCoordinate2D?
    let onTap: (MapPoint) -> Void

    @State private var cameraPosition: MapCameraPosition = .region(.nowFallback)

    var body: some View {
        ZStack {
            Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
                if let userCoordinate {
                    Annotation("You", coordinate: userCoordinate, anchor: .center) {
                        UserLocationMarker()
                    }
                }

                ForEach(points) { point in
                    Annotation(point.profile.name, coordinate: point.approximateCoordinate, anchor: .center) {
                        Button {
                            onTap(point)
                        } label: {
                            MapPointView(state: point.state)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControls {
                MapCompass()
                MapScaleView()
            }

            Circle()
                .stroke(NOWColor.lime.opacity(0.68), lineWidth: 2)
                .frame(width: 330, height: 330)
                .allowsHitTesting(false)

            if points.isEmpty {
                EmptyMapState()
                    .padding(.horizontal, 24)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            updateCamera(animated: false)
        }
        .onChange(of: cameraKey) { _, _ in
            updateCamera(animated: true)
        }
    }

    private var cameraKey: String {
        let pointKey = points
            .map { "\($0.id.uuidString):\(rounded($0.approximateCoordinate.latitude)):\(rounded($0.approximateCoordinate.longitude))" }
            .joined(separator: "|")
        let userKey = userCoordinate.map { "\(rounded($0.latitude)):\(rounded($0.longitude))" } ?? "none"
        return "\(userKey)#\(pointKey)"
    }

    private func rounded(_ value: CLLocationDegrees) -> String {
        String(format: "%.5f", value)
    }

    private func updateCamera(animated: Bool) {
        let nextPosition = MapCameraPosition.region(.fitting(points: points, userCoordinate: userCoordinate))

        if animated {
            withAnimation(.easeInOut(duration: 0.35)) {
                cameraPosition = nextPosition
            }
        } else {
            cameraPosition = nextPosition
        }
    }
}

private extension MKCoordinateRegion {
    static let nowFallback = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7410, longitude: -73.9897),
        span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
    )

    static func fitting(points: [MapPoint], userCoordinate: CLLocationCoordinate2D?) -> MKCoordinateRegion {
        let coordinates = ([userCoordinate].compactMap { $0 }) + points.map(\.approximateCoordinate)

        guard !coordinates.isEmpty else {
            return .nowFallback
        }

        guard coordinates.count > 1 else {
            return MKCoordinateRegion(
                center: coordinates[0],
                span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
            )
        }

        let minLat = coordinates.map(\.latitude).min() ?? coordinates[0].latitude
        let maxLat = coordinates.map(\.latitude).max() ?? coordinates[0].latitude
        let minLng = coordinates.map(\.longitude).min() ?? coordinates[0].longitude
        let maxLng = coordinates.map(\.longitude).max() ?? coordinates[0].longitude

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let latDelta = max(0.01, (maxLat - minLat) * 1.9)
        let lngDelta = max(0.01, (maxLng - minLng) * 1.9)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta)
        )
    }
}

private struct UserLocationMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(NOWColor.ink.opacity(0.18))
                .frame(width: 44, height: 44)
            Circle()
                .fill(NOWColor.ink)
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(NOWColor.surface, lineWidth: 5))
        }
        .shadow(color: NOWColor.ink.opacity(0.18), radius: 10, x: 0, y: 5)
        .accessibilityLabel("Your location")
    }
}

private struct EmptyMapState: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("No one live nearby yet")
                .font(.headline.weight(.black))
                .foregroundStyle(NOWColor.ink)
            Text("You're online. New live points will appear here.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(NOWColor.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .background(NOWColor.surface.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(NOWColor.line.opacity(0.8), lineWidth: 1)
        )
    }
}

private struct MapPointView: View {
    let state: MapPointState

    var body: some View {
        ZStack {
            switch state {
            case .unseen:
                Circle()
                    .fill(NOWColor.lime.opacity(0.34))
                    .frame(width: 54, height: 54)
                Circle()
                    .fill(NOWColor.lime)
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(NOWColor.surface, lineWidth: 6))
            case .viewed:
                Circle()
                    .fill(NOWColor.surface.opacity(0.42))
                    .frame(width: 48, height: 48)
                Circle()
                    .fill(NOWColor.surface)
                    .frame(width: 25, height: 25)
                    .overlay(Circle().stroke(NOWColor.line, lineWidth: 1))
            case .interested:
                Circle()
                    .fill(NOWColor.surface)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(NOWColor.line, lineWidth: 1))
                Image(systemName: "heart.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(NOWColor.lime)
                    .shadow(color: NOWColor.ink.opacity(0.35), radius: 0, x: 0, y: 1)
            case .triedBefore:
                Circle()
                    .fill(NOWColor.lime)
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(NOWColor.surface, lineWidth: 5))
                Circle()
                    .fill(NOWColor.ink)
                    .frame(width: 5, height: 5)
                    .offset(x: 13, y: -11)
            case .hiddenToday, .blocked:
                EmptyView()
            }
        }
        .shadow(color: NOWColor.ink.opacity(0.08), radius: 10, x: 0, y: 6)
    }
}

private struct MapPersonCard: View {
    let point: MapPoint?
    let open: () -> Void

    var body: some View {
        Button {
            open()
        } label: {
            HStack(spacing: 12) {
                BundlePhoto(name: NOWPhoto.person)
                    .frame(width: 78, height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(point?.profile.name ?? "Someone nearby")
                        .font(.title3.weight(.black))
                        .foregroundStyle(NOWColor.ink)
                    Text(cardCopy)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(NOWColor.inkSoft)
                        .lineLimit(2)
                }

                Spacer()

                Text("Open")
                    .font(.caption.weight(.black))
                    .foregroundStyle(NOWColor.ink)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(NOWColor.lime)
                    .clipShape(Capsule())
            }
        }
        .buttonStyle(.plain)
        .padding(12)
        .background(NOWColor.surface.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: NOWColor.ink.opacity(0.12), radius: 22, x: 0, y: 12)
    }

    private var cardCopy: String {
        guard let profile = point?.profile else {
            return "Open to meet today. Tap a live point."
        }
        return "\(profile.plan.rawValue) today · \(profile.distance) · one real plan."
    }
}
