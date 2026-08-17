import SwiftUI

struct ProfilePreviewScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if let point = appState.selectedPoint {
            ZStack(alignment: .top) {
                NOWColor.laCream.ignoresSafeArea()
                LATopStripe()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            NOWBackButton {
                                appState.closeProfilePreview()
                            }
                            Text("NOW")
                                .font(.subheadline.weight(.heavy))
                                .tracking(1.4)
                                .foregroundStyle(NOWColor.laCoral)
                            Spacer()
                            Text("Nearby · \(point.profile.distance)")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(NOWColor.laBrown)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(NOWColor.surface)
                                .clipShape(Capsule())
                                .shadow(color: NOWColor.ink.opacity(0.08), radius: 10, x: 0, y: 4)
                        }

                        ZStack(alignment: .bottomLeading) {
                            ProfilePhotoSurface(url: point.profile.mainPhotoURL, height: 390, cornerRadius: 24)
                            VStack(alignment: .leading, spacing: 7) {
                                Text(profileTitle(point.profile))
                                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("\(point.profile.planSummary) · \(point.profile.intentSummary)")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.92))
                                    .lineLimit(3)
                            }
                            .padding(18)
                        }

                        HStack(spacing: 8) {
                            NOWChip(text: point.profile.planSummary, active: true)
                            ForEach(point.profile.sharedInterests.prefix(2), id: \.self) { interest in
                                NOWChip(text: interest)
                            }
                        }

                        Text("\"\(point.profile.prompt)\"")
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(NOWColor.laBrown)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(NOWColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(NOWColor.line.opacity(0.82), lineWidth: 1)
                            )

                        Button("Say hi") {
                            appState.markInterested(point)
                        }
                        .buttonStyle(DangerButtonStyle())
                    }
                    .padding(14)
                    .padding(.top, 24)
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        let isDownwardSwipe = value.translation.height > 100
                            && abs(value.translation.height) > abs(value.translation.width)
                        let isBackSwipe = value.translation.width > 90
                            && abs(value.translation.width) > abs(value.translation.height)
                        if isDownwardSwipe || isBackSwipe {
                            appState.closeProfilePreview()
                        }
                    }
            )
        }
    }

    private func profileTitle(_ profile: UserProfile) -> String {
        guard let age = profile.age else { return profile.name }
        return "\(profile.name), \(age)"
    }

}
