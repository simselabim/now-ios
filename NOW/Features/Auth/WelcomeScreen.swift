import SwiftUI

struct WelcomeScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        NOWLogo()
                        Text("Eat · Walk ♥ Love")
                            .font(.caption.weight(.black))
                            .foregroundStyle(NOWColor.slate)
                    }
                    Spacer()
                    NOWChip(text: "Today", active: true)
                }

                ZStack(alignment: .bottomLeading) {
                    PhotoSurface(name: NOWPhoto.parkWalkBlur, height: 310, blur: 1.2)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("One person, today.")
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(.white)
                        Text("Find someone nearby for coffee, a walk, dinner, or a small city plan.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.88))
                    }
                    .padding(18)
                }

                NOWInfoCard {
                    Text("What feels right now?")
                        .font(.headline.weight(.black))
                    HStack(spacing: 8) {
                        NOWChip(text: "Coffee", active: true)
                        NOWChip(text: "Walk")
                        NOWChip(text: "Dinner")
                        NOWChip(text: "Just talk")
                    }
                }

                if appState.isLoading {
                    ProgressView()
                        .tint(NOWColor.lime)
                        .frame(maxWidth: .infinity)
                }

                if let error = appState.errorMessage {
                    Text(error)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(NOWColor.coral)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NOWColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button(appState.isLoading ? "Connecting..." : "Demo Login") {
                    appState.login()
                }
                .disabled(appState.isLoading)
                .buttonStyle(PrimaryButtonStyle())

                Text("You will be visible while you are here. Tonight everything resets.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(NOWColor.inkSoft)
                    .padding(.top, 4)
            }
            .padding(22)
        }
    }
}
