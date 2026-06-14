import SwiftUI

struct DiscoveryMapScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            FakeMap(points: appState.visibleMapPoints) { point in
                appState.viewPoint(point)
            }
            .frame(height: 420)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Ready today nearby")
                            .font(.title3.weight(.bold))
                        Text(appState.isLoading ? "Syncing with NOW..." : "Choose carefully. One live match.")
                            .font(.subheadline)
                            .foregroundStyle(NOWColor.inkSoft)
                    }
                    Spacer()
                    if appState.isLoading {
                        ProgressView()
                            .tint(NOWColor.teal)
                    }
                    Button("Go Offline") {
                        appState.goOffline()
                    }
                    .font(.subheadline.weight(.semibold))
                }

                if let error = appState.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(NOWColor.coral)
                        .padding(10)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Text("Tap a point to open profile. Not Now disappears until tomorrow. Block disappears permanently.")
                    .font(.footnote)
                    .foregroundStyle(NOWColor.inkSoft)
                    .padding(10)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(16)

            Spacer()
        }
    }
}

private struct FakeMap: View {
    let points: [MapPoint]
    let onTap: (MapPoint) -> Void

    var body: some View {
        ZStack {
            NOWColor.tealPale
            Circle()
                .stroke(NOWColor.teal.opacity(0.36), lineWidth: 2)
                .frame(width: 290, height: 290)
            Text("2 km radius")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white)
                .clipShape(Capsule())
                .offset(y: -150)

            Circle()
                .fill(NOWColor.teal)
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(.white, lineWidth: 6))

            ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                Button {
                    onTap(point)
                } label: {
                    Circle()
                        .fill(color(for: point.state))
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(.white, lineWidth: 4))
                }
                .offset(offset(for: index))
            }
        }
    }

    private func color(for state: MapPointState) -> Color {
        switch state {
        case .unseen:
            return NOWColor.teal
        case .viewed:
            return NOWColor.inkSoft
        case .interested:
            return NOWColor.coral
        case .hiddenToday, .blocked:
            return .clear
        }
    }

    private func offset(for index: Int) -> CGSize {
        let offsets = [
            CGSize(width: -112, height: -80),
            CGSize(width: 104, height: -18),
            CGSize(width: -52, height: 112),
            CGSize(width: 118, height: 118)
        ]
        return offsets[index % offsets.count]
    }
}
