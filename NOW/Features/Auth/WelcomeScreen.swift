import SwiftUI

struct WelcomeScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var isPhilosophyPresented = false

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
                    Button {
                        isPhilosophyPresented = true
                    } label: {
                        NOWChip(text: "Today", active: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Learn what NOW is about")
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
                        .foregroundStyle(NOWColor.ink)
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

                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .foregroundStyle(NOWColor.ink)
                        .tint(NOWColor.laCoral)
                        .padding(14)
                        .background(NOWColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    SecureField("Password", text: $password)
                        .textContentType(isRegistering ? .newPassword : .password)
                        .foregroundStyle(NOWColor.ink)
                        .tint(NOWColor.laCoral)
                        .padding(14)
                        .background(NOWColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if !password.isEmpty && password.count < 8 {
                        Text("Password must be at least 8 characters.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(NOWColor.coral)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Button(appState.isLoading ? "Connecting..." : (isRegistering ? "Create account" : "Sign in")) {
                    appState.authenticate(
                        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                        password: password,
                        register: isRegistering
                    )
                }
                .disabled(appState.isLoading || !canSubmit)
                .buttonStyle(PrimaryButtonStyle())

                Button(isRegistering ? "Already have an account? Sign in" : "New here? Create account") {
                    isRegistering.toggle()
                    appState.errorMessage = nil
                }
                .font(.footnote.weight(.bold))
                .foregroundStyle(NOWColor.ink)
                .frame(maxWidth: .infinity)

                Text("You will be visible while you are here. Tonight everything resets.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(NOWColor.inkSoft)
                    .padding(.top, 4)
            }
            .padding(22)
        }
        .sheet(isPresented: $isPhilosophyPresented) {
            NOWPhilosophySheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && password.count >= 8
    }
}

private struct NOWPhilosophySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                NOWLogo(compact: true)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(NOWColor.ink)
                        .frame(width: 38, height: 38)
                        .background(NOWColor.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }

            Text("One click.\nOne meeting. Now.")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(NOWColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("NOW is not about endless choices. It is about one real meeting today.")
                .font(.title3.weight(.bold))
                .foregroundStyle(NOWColor.slate)

            Text("Choose someone nearby and make a plan for today — no endless swiping, no weeks of messaging.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NOWColor.inkSoft)

            Spacer(minLength: 0)

            Button("Got it") {
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
        .background(NOWColor.laCream.ignoresSafeArea())
    }
}
