import MapKit
import SwiftUI

struct DiscoveryMapScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var cameraPosition: MapCameraPosition = .region(.nowFallback)

    var body: some View {
        LiveDiscoveryMap(
            points: appState.visibleMapPoints,
            userCoordinate: appState.currentCoordinate,
            cameraPosition: $cameraPosition
        ) { point in
            appState.viewPoint(point)
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            cameraPosition = .region(.fitting(points: appState.visibleMapPoints, userCoordinate: appState.currentCoordinate))
        }
        .onChange(of: cameraKey) { _, _ in
            withAnimation(.easeInOut(duration: 0.35)) {
                cameraPosition = .region(.fitting(points: appState.visibleMapPoints, userCoordinate: appState.currentCoordinate))
            }
        }
        .overlay(alignment: .top) {
            MapHeader(isLoading: appState.isLoading, back: {
                appState.goBackForTesting()
            }, recenter: {
                recenterOnUser()
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

                LAPill(text: "Golden hour · 1 h 16 m of daylight left", icon: nil)
                    .frame(maxWidth: .infinity, alignment: .leading)

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

    private var cameraKey: String {
        let pointKey = appState.visibleMapPoints
            .map { "\($0.id.uuidString):\(rounded($0.approximateCoordinate.latitude)):\(rounded($0.approximateCoordinate.longitude))" }
            .joined(separator: "|")
        let userKey = appState.currentCoordinate.map { "\(rounded($0.latitude)):\(rounded($0.longitude))" } ?? "none"
        return "\(userKey)#\(pointKey)"
    }

    private func rounded(_ value: CLLocationDegrees) -> String {
        String(format: "%.5f", value)
    }

    private func recenterOnUser() {
        let region: MKCoordinateRegion
        if let currentCoordinate = appState.currentCoordinate {
            region = MKCoordinateRegion(
                center: currentCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
            )
        } else {
            region = .fitting(points: appState.visibleMapPoints, userCoordinate: appState.currentCoordinate)
        }

        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = .region(region)
        }
    }
}

private struct MapHeader: View {
    let isLoading: Bool
    let back: () -> Void
    let recenter: () -> Void
    let refresh: () -> Void
    let goOffline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button(action: back) {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(NOWColor.surface)
                        .frame(width: 42, height: 42)
                        .background(NOWColor.laBrownSoft.opacity(0.92))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                NOWLogo(compact: true)

                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(NOWColor.laOrange)
                        .padding(10)
                        .background(NOWColor.surface.opacity(0.9))
                        .clipShape(Circle())
                }

                Button {
                    recenter()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.caption.weight(.black))
                        .foregroundStyle(NOWColor.laBrown)
                        .frame(width: 42, height: 42)
                        .background(NOWColor.surface.opacity(0.9))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Center on me")

                Button {
                    refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.black))
                        .foregroundStyle(NOWColor.laBrown)
                        .frame(width: 42, height: 42)
                        .background(NOWColor.surface.opacity(0.9))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button("Online") {
                    goOffline()
                }
                .font(.caption.weight(.heavy))
                .foregroundStyle(NOWColor.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(NOWColor.laOrange)
                .clipShape(Capsule())
            }

            LAPill(text: "Canggu · nearby · sunset 18:17", icon: nil)
        }
    }
}

private struct LiveDiscoveryMap: View {
    let points: [MapPoint]
    let userCoordinate: CLLocationCoordinate2D?
    @Binding var cameraPosition: MapCameraPosition
    let onTap: (MapPoint) -> Void

    var body: some View {
        Map(position: $cameraPosition, interactionModes: [.pan, .zoom, .rotate]) {
            if let userCoordinate {
                Annotation("You", coordinate: userCoordinate, anchor: .center) {
                    LAUserLocationMarker()
                }
            }

            ForEach(points) { point in
                Annotation(point.profile.name, coordinate: point.approximateCoordinate, anchor: .center) {
                    Button {
                        onTap(point)
                    } label: {
                        LAMapPersonMarker(point: point)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(point.profile.name), \(point.profile.distance)")
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .tint(NOWColor.lime)
        .overlay(LAGradient.mapWash.blendMode(.multiply).allowsHitTesting(false))
        .overlay {
            Circle()
                .stroke(NOWColor.surface.opacity(0.42), style: StrokeStyle(lineWidth: 2, dash: [7, 7]))
                .frame(width: 330, height: 330)
                .allowsHitTesting(false)
        }
        .overlay {
            if points.isEmpty {
                EmptyMapState()
                    .padding(.horizontal, 24)
                    .allowsHitTesting(false)
            }
        }
    }
}

private extension MKCoordinateRegion {
    static let nowFallback = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -8.6504, longitude: 115.1387),
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
        let latDelta = max(0.01, (maxLat - minLat) * 2.1)
        let lngDelta = max(0.01, (maxLng - minLng) * 2.1)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta)
        )
    }
}

private struct LAUserLocationMarker: View {
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(NOWColor.surface)
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(NOWColor.laCoral, lineWidth: 5))
            Text("You")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(NOWColor.surface)
                .fixedSize()
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(NOWColor.laCoral)
                .clipShape(Capsule())
        }
        .shadow(color: NOWColor.laCoral.opacity(0.35), radius: 14, x: 0, y: 6)
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

private struct LAMapPersonMarker: View {
    let point: MapPoint

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                BundlePhoto(name: markerPhoto)
                    .frame(width: 46, height: 46)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(markerStroke, lineWidth: 3))
                    .shadow(color: NOWColor.ink.opacity(0.22), radius: 10, x: 0, y: 6)

                if point.state == .triedBefore {
                    Circle()
                        .fill(NOWColor.laBrown)
                        .frame(width: 9, height: 9)
                }
            }

            Text("\(point.profile.name) · \(point.profile.plan.rawValue)")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundStyle(labelForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(labelBackground)
                .clipShape(Capsule())
                .shadow(color: NOWColor.ink.opacity(0.12), radius: 8, x: 0, y: 4)
        }
    }

    private var markerPhoto: String {
        switch point.profile.name {
        case "Ethan", "Ren", "Leo":
            return NOWPhoto.streetCoffee
        default:
            return NOWPhoto.person
        }
    }

    private var markerStroke: Color {
        point.state == .viewed ? NOWColor.surface : NOWColor.laOrange
    }

    private var labelBackground: Color {
        point.state == .viewed ? NOWColor.laBrownSoft : NOWColor.laOrange
    }

    private var labelForeground: Color {
        point.state == .viewed ? NOWColor.surface : NOWColor.ink
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
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

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
                    .foregroundStyle(NOWColor.surface)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(LAGradient.sunset)
                    .clipShape(Capsule())
            }
        }
        .buttonStyle(.plain)
        .padding(12)
        .background(NOWColor.surface.opacity(0.98))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: NOWColor.ink.opacity(0.12), radius: 22, x: 0, y: 12)
    }

    private var cardCopy: String {
        guard let profile = point?.profile else {
            return "Open to meet today. Tap a live point."
        }
        return "\(profile.plan.rawValue) in Canggu · \(profile.distance)"
    }
}
