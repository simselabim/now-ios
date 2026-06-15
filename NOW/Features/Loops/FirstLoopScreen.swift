import SwiftUI

struct FirstLoopScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let match = appState.activeMatch {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("You matched.")
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(NOWColor.ink)
                        Text("Start with a silent loop. Then chat opens until tonight.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NOWColor.inkSoft)
                    }
                    Spacer()
                    NOWLogo(compact: true)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(NOWColor.ink)

                    HStack(spacing: 34) {
                        LoopAvatar(imageName: NOWPhoto.streetCoffee, name: "You")
                        ZStack {
                            Circle()
                                .fill(NOWColor.lime)
                                .frame(width: 52, height: 52)
                            Image(systemName: "checkmark")
                                .font(.headline.weight(.black))
                                .foregroundStyle(NOWColor.ink)
                        }
                        LoopAvatar(imageName: NOWPhoto.person, name: match.profile.name)
                    }
                }
                .frame(height: 285)

                Text("Both of you chose \(match.profile.plan.rawValue.lowercased()) today. Stay with this one for now.")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(NOWColor.slate)

                Button(match.myFirstLoopSent ? "Waiting for their loop" : "Send silent loop") {
                    appState.sendFirstLoop()
                }
                .disabled(match.myFirstLoopSent)
                .buttonStyle(PrimaryButtonStyle())

                Button("Close kindly") {
                    appState.cancelMatch()
                }
                .buttonStyle(DangerButtonStyle())
            }
            Spacer()
        }
        .padding(22)
    }
}

private struct LoopAvatar: View {
    let imageName: String
    let name: String

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                BundlePhoto(name: imageName)
                    .frame(width: 108, height: 108)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(NOWColor.surface, lineWidth: 5))
                Circle()
                    .fill(NOWColor.lime)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(NOWColor.surface, lineWidth: 3))
            }

            Text(name)
                .font(.caption.weight(.black))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
        }
    }
}
