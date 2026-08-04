import SwiftUI

struct AppRouter: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            Group {
                if !appState.didAttemptSessionRestore {
                    ProgressView("Restoring session…")
                        .tint(NOWColor.lime)
                } else if !appState.isAuthenticated {
                    WelcomeScreen()
                } else if appState.showAccount {
                    AccountScreen()
                } else if !appState.isProfileComplete {
                    CreateProfileScreen()
                } else if appState.showHistory {
                    HistoryScreen()
                } else if appState.activeMatch != nil {
                    MatchFlowScreen()
                } else if appState.selectedPoint != nil {
                    ProfilePreviewScreen()
                } else if !appState.isOnline {
                    GoOnlineScreen()
                } else {
                    DiscoveryMapScreen()
                }
            }
            .background(NOWColor.paper.ignoresSafeArea())
            .toolbar {
                if appState.isAuthenticated && !appState.showAccount {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            appState.openAccount()
                        } label: {
                            Label("Account", systemImage: "person.crop.circle")
                        }
                        .tint(NOWColor.ink)
                    }
                }
            }
        }
    }
}

private struct AccountScreen: View {
    @EnvironmentObject private var appState: AppState

    @State private var displayName = ""
    @State private var birthDate = "1995-01-01"
    @State private var gender = ""
    @State private var bio = ""
    @State private var interests = ""
    @State private var hasLoadedForm = false
    @State private var showDeleteConfirmation = false

    private let genderOptions = ["woman", "man", "non-binary"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button {
                        appState.closeAccount()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(NOWColor.ink)

                    Spacer()
                    NOWLogo(compact: true)
                }

                Text("Your account")
                    .font(.largeTitle.weight(.black))

                if let email = appState.currentUserEmail {
                    Text(email)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(NOWColor.inkSoft)
                }

                Group {
                    accountField("Display name", text: $displayName)
                    accountField("Birth date (YYYY-MM-DD)", text: $birthDate)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gender")
                            .font(.caption.weight(.black))
                            .foregroundStyle(NOWColor.inkSoft)
                        Picker("Gender", selection: $gender) {
                            Text("Choose").tag("")
                            ForEach(genderOptions, id: \.self) { option in
                                Text(option.capitalized).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Short bio")
                            .font(.caption.weight(.black))
                            .foregroundStyle(NOWColor.inkSoft)
                        TextField("A few honest words about you", text: $bio, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(14)
                            .background(NOWColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    accountField("Interests (comma separated)", text: $interests)
                }

                if let error = appState.errorMessage {
                    Text(error)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(NOWColor.coral)
                }

                Button(appState.isLoading ? "Saving…" : "Save profile") {
                    appState.saveProfile(
                        displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                        birthDate: birthDate.trimmingCharacters(in: .whitespacesAndNewlines),
                        gender: gender,
                        bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
                        interests: interests
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                    )
                }
                .disabled(!canSave || appState.isLoading)
                .buttonStyle(PrimaryButtonStyle())

                Divider()

                Button("Sign out") {
                    appState.logout()
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Delete account and data") {
                    showDeleteConfirmation = true
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(NOWColor.coral)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .padding(22)
        }
        .background(NOWColor.paper.ignoresSafeArea())
        .onAppear { applyProfileIfNeeded(appState.myProfile) }
        .onChange(of: appState.myProfile) { _, profile in
            applyProfileIfNeeded(profile)
        }
        .alert("Delete your account?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete account", role: .destructive) {
                appState.deleteAccount()
            }
        } message: {
            Text("Your profile, matches, messages, loops, history, and account data will be permanently deleted.")
        }
    }

    private var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && birthDate.count == 10
            && !gender.isEmpty
            && !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func accountField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.black))
                .foregroundStyle(NOWColor.inkSoft)
            TextField(title, text: text)
                .textInputAutocapitalization(title.contains("Birth") ? .never : .sentences)
                .padding(14)
                .background(NOWColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func applyProfileIfNeeded(_ profile: ProfileDTO?) {
        guard !hasLoadedForm, let profile else { return }
        displayName = profile.displayName
        birthDate = profile.birthDate
        gender = profile.gender
        bio = profile.bio
        interests = profile.interests.joined(separator: ", ")
        hasLoadedForm = true
    }
}
