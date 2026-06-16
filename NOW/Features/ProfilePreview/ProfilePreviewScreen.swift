import SwiftUI

struct ProfilePreviewScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if let point = appState.selectedPoint {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Button {
                            appState.closeProfilePreview()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.headline.weight(.black))
                                .foregroundStyle(NOWColor.ink)
                                .frame(width: 42, height: 42)
                                .background(NOWColor.surface)
                                .clipShape(Circle())
                        }
                        Spacer()
                        NOWLogo(compact: true)
                        Spacer()
                        NOWChip(text: point.profile.distance, active: true)
                    }

                    ZStack(alignment: .bottomLeading) {
                        PhotoSurface(name: NOWPhoto.person, height: 430, blur: 0, cornerRadius: 24)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(point.profile.name), \(point.profile.age)")
                                .font(.system(size: 34, weight: .black))
                                .foregroundStyle(.white)
                            Text("\(point.profile.plan.rawValue), small streets, maybe a gallery if the conversation is good.")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(3)
                        }
                        .padding(18)
                    }

                    NOWInfoCard {
                        Text("\"\(point.profile.prompt)\"")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(NOWColor.slate)
                    }

                    HStack(spacing: 8) {
                        NOWChip(text: point.profile.plan.rawValue, active: true)
                        NOWChip(text: point.profile.intent.rawValue)
                        ForEach(point.profile.sharedInterests.prefix(2), id: \.self) { interest in
                            NOWChip(text: interest)
                        }
                    }

                    Text("No contact details in profiles. If it feels right, confirm place and time through NOW.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(NOWColor.inkSoft)

                    HStack(spacing: 12) {
                        Button {
                            appState.notNow(point)
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(ProfileIconButtonStyle())

                        Button(likeButtonTitle(for: point.profile)) {
                            appState.markInterested(point)
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button {
                            appState.block(point)
                        } label: {
                            Image(systemName: "heart.slash")
                        }
                        .buttonStyle(ProfileIconButtonStyle())
                    }
                }
                .padding(22)
            }
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

private struct ProfileIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.black))
            .foregroundStyle(NOWColor.ink)
            .frame(width: 58, height: 52)
            .background(NOWColor.surface.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(NOWColor.line, lineWidth: 1)
            )
    }
}
