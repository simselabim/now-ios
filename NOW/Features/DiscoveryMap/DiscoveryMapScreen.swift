import SwiftUI

struct DiscoveryMapScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            CityMap(points: appState.visibleMapPoints) { point in
                appState.viewPoint(point)
            }
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                MapHeader(isLoading: appState.isLoading) {
                    appState.goOffline()
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)

                Spacer()

                if let error = appState.errorMessage {
                    Text(error)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(NOWColor.coral)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NOWColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 18)
                        .padding(.bottom, 10)
                }

                MapPersonCard(point: appState.visibleMapPoints.first) {
                    if let point = appState.visibleMapPoints.first {
                        appState.viewPoint(point)
                    }
                }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
            }
        }
    }
}

private struct MapHeader: View {
    let isLoading: Bool
    let goOffline: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
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
    let onTap: (MapPoint) -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                NOWColor.mapMist

                MapGrid()
                    .stroke(NOWColor.mapLine, lineWidth: 1.2)

                Street(width: proxy.size.width * 1.45, height: 34, rotation: -28)
                    .offset(x: -10, y: -80)
                Street(width: proxy.size.width * 1.55, height: 42, rotation: 34)
                    .offset(x: 20, y: 86)
                Street(width: proxy.size.width * 1.25, height: 26, rotation: -62)
                    .offset(x: 44, y: -10)

                placeLabel("Cafe", x: -88, y: -42)
                placeLabel("Park", x: 116, y: 98)

                Circle()
                    .stroke(NOWColor.lime.opacity(0.72), lineWidth: 2)
                    .frame(width: 330, height: 330)
                    .blur(radius: 0.2)

                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    Button {
                        onTap(point)
                    } label: {
                        MapPointView(state: point.state)
                    }
                    .buttonStyle(.plain)
                    .offset(offset(for: index))
                }
            }
        }
    }

    private func placeLabel(_ text: String, x: CGFloat, y: CGFloat) -> some View {
        Text(text)
            .font(.caption2.weight(.black))
            .foregroundStyle(NOWColor.slate)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(NOWColor.surface.opacity(0.92))
            .clipShape(Capsule())
            .offset(x: x, y: y)
    }

    private func offset(for index: Int) -> CGSize {
        let offsets = [
            CGSize(width: -128, height: -92),
            CGSize(width: 118, height: -30),
            CGSize(width: -66, height: 112),
            CGSize(width: 126, height: 148),
            CGSize(width: -18, height: -8)
        ]
        return offsets[index % offsets.count]
    }
}

private struct MapGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 38

        stride(from: rect.minX, through: rect.maxX, by: step).forEach { x in
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }

        stride(from: rect.minY, through: rect.maxY, by: step).forEach { y in
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }

        return path
    }
}

private struct Street: View {
    let width: CGFloat
    let height: CGFloat
    let rotation: Double

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(Color.white.opacity(0.62))
            .frame(width: width, height: height)
            .rotationEffect(.degrees(rotation))
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
