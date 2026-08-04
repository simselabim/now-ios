import PhotosUI
import SwiftUI
import UIKit

struct CreateProfileScreen: View {
    @EnvironmentObject private var appState: AppState

    @State private var displayName = ""
    @State private var birthDate = Calendar.current.date(
        from: DateComponents(year: 1995, month: 1, day: 1)
    ) ?? Date()
    @State private var gender = ""
    @State private var bio = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoPreview: UIImage?
    @State private var photoError: String?

    private let genderOptions = ["woman", "man", "non-binary"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Create profile")
                    .font(.largeTitle.weight(.black))

                Text("The essentials only. You can add more from your account later.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NOWColor.inkSoft)

                photoPicker

                profileField("Display name", text: $displayName, prompt: "How people will see you")

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Birth date")
                    DatePicker(
                        "Birth date",
                        selection: $birthDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NOWColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Gender")
                    Picker("Gender", selection: $gender) {
                        Text("Choose").tag("")
                        ForEach(genderOptions, id: \.self) { option in
                            Text(option.capitalized).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Short bio")
                    TextField("A few honest words about you", text: $bio, axis: .vertical)
                        .lineLimit(3...5)
                        .padding(14)
                        .background(NOWColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Text("Maximum 600 characters")
                        .font(.caption)
                        .foregroundStyle(NOWColor.inkSoft)
                }

                if let error = photoError ?? appState.errorMessage {
                    Text(error)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(NOWColor.coral)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NOWColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button(appState.isLoading ? "Creating profile…" : "Create profile") {
                    guard let photoData else { return }
                    appState.createProfile(
                        displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                        birthDate: formattedBirthDate,
                        gender: gender,
                        bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
                        photoData: photoData
                    )
                }
                .disabled(!canSubmit || appState.isLoading)
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(22)
            .padding(.bottom, 24)
        }
        .background(NOWColor.paper.ignoresSafeArea())
        .onChange(of: selectedPhotoItem) { _, item in
            loadPhoto(item)
        }
    }

    private var photoPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Main photo")
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(NOWColor.surface)
                        .frame(height: 210)

                    if let photoPreview {
                        Image(uiImage: photoPreview)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 210)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(alignment: .bottomTrailing) {
                                Label("Change", systemImage: "photo")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(NOWColor.ink)
                                    .background(NOWColor.surface.opacity(0.92))
                                    .clipShape(Capsule())
                                    .padding(12)
                            }
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "person.crop.square.badge.plus")
                                .font(.system(size: 36, weight: .semibold))
                            Text("Choose one clear photo")
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(NOWColor.inkSoft)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var canSubmit: Bool {
        photoData != nil
            && !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !gender.isEmpty
            && !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && bio.count <= 600
    }

    private var formattedBirthDate: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: birthDate)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.black))
            .foregroundStyle(NOWColor.inkSoft)
    }

    private func profileField(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(title)
            TextField(prompt, text: text)
                .padding(14)
                .background(NOWColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        photoError = nil

        Task {
            do {
                guard let originalData = try await item.loadTransferable(type: Data.self),
                      let prepared = preparePhoto(originalData) else {
                    photoError = "Could not read this photo. Choose another one."
                    return
                }
                photoData = prepared.data
                photoPreview = prepared.image
            } catch {
                photoError = "Could not open this photo. Choose another one."
            }
        }
    }

    private func preparePhoto(_ data: Data) -> (data: Data, image: UIImage)? {
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
