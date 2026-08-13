import PhotosUI
import SwiftUI
import UIKit

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
                } else if appState.activeMatch != nil && appState.isViewingActiveMatchMap {
                    DiscoveryMapScreen()
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
    @State private var birthDate = ""
    @State private var gender = ""
    @State private var bio = ""
    @State private var interests = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoPreview: UIImage?
    @State private var photoError: String?
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
                    .foregroundStyle(NOWColor.ink)

                if let email = appState.currentUserEmail {
                    Text(email)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(NOWColor.inkSoft)
                }

                profilePhotoEditor

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
                            .foregroundStyle(NOWColor.ink)
                            .tint(NOWColor.laCoral)
                            .padding(14)
                            .background(NOWColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    accountField("Interests (comma separated)", text: $interests)
                }

                if let error = photoError ?? appState.errorMessage {
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
        .onChange(of: selectedPhotoItem) { _, item in
            loadProfilePhoto(item)
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

    private var profilePhotoEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Main photo")
                .font(.caption.weight(.black))
                .foregroundStyle(NOWColor.inkSoft)

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    AccountProfilePhoto(url: currentProfilePhotoURL, preview: photoPreview)
                        .frame(maxWidth: .infinity)
                        .frame(height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    Label(currentProfilePhotoURL == nil && photoPreview == nil ? "Add photo" : "Change", systemImage: "photo")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(NOWColor.ink)
                        .background(NOWColor.surface.opacity(0.92))
                        .clipShape(Capsule())
                        .padding(12)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var currentProfilePhotoURL: URL? {
        guard let photos = appState.myProfile?.photos else { return nil }
        let photo = photos.first(where: \.isMain) ?? photos.sorted { $0.position < $1.position }.first
        guard let photo else { return nil }
        return APIEnvironment.appDefault.mediaURL(storageKey: photo.storageKey)
    }

    private func accountField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.black))
                .foregroundStyle(NOWColor.inkSoft)
            TextField(title, text: text)
                .textInputAutocapitalization(title.contains("Birth") ? .never : .sentences)
                .foregroundStyle(NOWColor.ink)
                .tint(NOWColor.laCoral)
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

    private func loadProfilePhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        photoError = nil

        Task {
            do {
                guard let originalData = try await item.loadTransferable(type: Data.self),
                      let prepared = prepareAccountPhoto(originalData) else {
                    photoError = "Could not read this photo. Choose another one."
                    return
                }
                photoPreview = prepared.image
                appState.updateProfilePhoto(photoData: prepared.data)
            } catch {
                photoError = "Could not open this photo. Choose another one."
            }
        }
    }

    private func prepareAccountPhoto(_ data: Data) -> (data: Data, image: UIImage)? {
        guard let image = UIImage(data: data) else { return nil }
        let maxDimension: CGFloat = 1_600
        let largestSide = max(image.size.width, image.size.height)
        let scale = min(1, maxDimension / largestSide)
        let targetSize = CGSize(
            width: max(1, image.size.width * scale),
            height: max(1, image.size.height * scale)
        )
        let rendered = UIGraphicsImageRenderer(size: targetSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let jpeg = rendered.jpegData(compressionQuality: 0.82) else { return nil }
        return (jpeg, rendered)
    }
}

private struct AccountProfilePhoto: View {
    let url: URL?
    let preview: UIImage?

    var body: some View {
        if let preview {
            Image(uiImage: preview)
                .resizable()
                .scaledToFill()
        } else if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure, .empty:
                    photoPlaceholder
                @unknown default:
                    photoPlaceholder
                }
            }
        } else {
            photoPlaceholder
        }
    }

    private var photoPlaceholder: some View {
        ZStack {
            NOWColor.surface
            Image(systemName: "person.crop.square")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(NOWColor.inkSoft)
        }
    }
}
