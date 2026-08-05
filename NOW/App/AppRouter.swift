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
                } else if !appState.isProfileComplete {
                    CreateProfileScreen()
                } else if appState.activeMatch != nil {
                    MatchFlowScreen()
                } else if appState.selectedPoint != nil {
                    ProfilePreviewScreen()
                } else {
                    MainAppShell()
                }
            }
            .background(NOWColor.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct MainAppShell: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.selectedAppTab {
            case .search:
                if appState.isOnline {
                    DiscoveryMapScreen()
                } else {
                    GoOnlineScreen()
                }
            case .history:
                HistoryScreen()
            case .account:
                AccountScreen()
            case .now:
                NOWPhilosophyScreen()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            NOWBottomNavigation(
                selection: Binding(
                    get: { appState.selectedAppTab },
                    set: { appState.selectAppTab($0) }
                )
            )
        }
    }
}

private struct NOWBottomNavigation: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 18, weight: .bold))
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selection == tab ? NOWColor.surface : NOWColor.laBrownSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if selection == tab {
                            Capsule()
                                .fill(NOWColor.laBrownSoft)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(6)
        .background(NOWColor.surface.opacity(0.98))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(NOWColor.line.opacity(0.8), lineWidth: 1))
        .shadow(color: NOWColor.ink.opacity(0.16), radius: 18, x: 0, y: 8)
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(NOWColor.laCream.opacity(0.94))
    }
}

private struct NOWPhilosophyScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                NOWLogo()

                Text("One click.\nOne meeting. Now.")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(NOWColor.ink)

                Text("NOW is built for a real plan today, not an endless catalogue of people.")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(NOWColor.slate)

                philosophyCard(
                    icon: "location.fill",
                    title: "Nearby and available",
                    copy: "Search only among people who are online nearby and ready to meet today."
                )
                philosophyCard(
                    icon: "hand.tap.fill",
                    title: "One clear choice",
                    copy: "Open a person, say hi, and give one connection your attention instead of swiping forever."
                )
                philosophyCard(
                    icon: "sunset.fill",
                    title: "Today stays honest",
                    copy: "Your plan, availability, and matches reset with the day. Choose what feels right now."
                )
            }
            .padding(22)
            .padding(.bottom, 16)
        }
        .background(NOWColor.laCream.ignoresSafeArea())
    }

    private func philosophyCard(icon: String, title: String, copy: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3.weight(.black))
                .foregroundStyle(NOWColor.laCoral)
                .frame(width: 42, height: 42)
                .background(NOWColor.laGold.opacity(0.38))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(NOWColor.ink)
                Text(copy)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NOWColor.inkSoft)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NOWColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                    Text("Account")
                        .font(.caption.weight(.black))
                        .foregroundStyle(NOWColor.laCoral)
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
