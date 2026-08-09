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
                            Text("NOW · LA")
                                .font(.subheadline.weight(.heavy))
                                .tracking(1.4)
                                .foregroundStyle(NOWColor.laCoral)
                            Spacer()
                            Text("Echo Park · \(point.profile.distance)")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(NOWColor.laBrown)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(NOWColor.surface)
                                .clipShape(Capsule())
                                .shadow(color: NOWColor.ink.opacity(0.08), radius: 10, x: 0, y: 4)
                        }

                        ZStack(alignment: .bottomLeading) {
                            PhotoSurface(name: NOWPhoto.person, height: 390, blur: 0, cornerRadius: 24)
                            VStack(alignment: .leading, spacing: 7) {
                                Text("\(point.profile.name), \(point.profile.age)")
                                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("\(point.profile.plan.rawValue), vintage stores, sunset from the reservoir.")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.92))
                                    .lineLimit(3)
                            }
                            .padding(18)

                            LoopBadge()
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                                .padding(.trailing, 16)
                                .padding(.bottom, 32)
                        }

                        HStack(spacing: 8) {
                            NOWChip(text: point.profile.plan.rawValue, active: true)
                            NOWChip(text: "Hike")
                            ForEach(point.profile.sharedInterests.prefix(1), id: \.self) { interest in
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
}

private func likeButtonTitle(for profile: UserProfile) -> String {
    let gender = profile.occupation.lowercased()
    if ["female", "woman", "women"].contains(gender) || ["Maya", "Ana", "Lina", "Sofia", "Nora"].contains(profile.name) {
        return "Like her"
    }
    if ["male", "man", "men"].contains(gender) || ["Ren", "Leo", "Noah", "Ethan"].contains(profile.name) {
        return "Like him"
    }
    return "Like \(profile.name)"
}

private struct LoopBadge: View {
    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(NOWColor.laBrown.opacity(0.62))
                    .frame(width: 68, height: 68)
                    .overlay(Circle().stroke(NOWColor.laOrange, lineWidth: 3))
                Image(systemName: "play.fill")
                    .font(.headline.weight(.black))
                    .foregroundStyle(NOWColor.surface)
            }
            Text("10s loop")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(NOWColor.laGold)
        }
    }
}
