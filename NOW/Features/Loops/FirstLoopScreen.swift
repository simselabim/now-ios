import SwiftUI
import AVKit
import CoreTransferable
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct FirstLoopScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var showVideoCapture = false
    @State private var selectedVideo: PhotosPickerItem?

    var body: some View {
        ZStack {
            LAGradient.match.ignoresSafeArea()
            NOWColor.laEspresso.opacity(0.12).ignoresSafeArea()

            if let match = appState.activeMatch {
                VStack(alignment: .leading, spacing: 18) {
                    Text("You caught\nthe light.")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(NOWColor.laEspresso)
                        .lineSpacing(-4)

                    Text("You and \(match.profile.name) both picked \(match.profile.plan.rawValue.lowercased()) today.\nOne match - make it count before sunset.")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(NOWColor.laEspresso.opacity(0.82))

                    HStack(spacing: -14) {
                        LoopAvatar(imageName: NOWPhoto.streetCoffee, name: "You")
                        ZStack {
                            Circle()
                                .fill(NOWColor.surface)
                                .frame(width: 54, height: 54)
                            Image(systemName: "checkmark")
                                .font(.headline.weight(.black))
                                .foregroundStyle(NOWColor.laCoral)
                        }
                        .zIndex(2)
                        LoopAvatar(imageName: NOWPhoto.person, name: match.profile.name)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)

                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                                .foregroundStyle(NOWColor.surface.opacity(0.82))
                                .frame(width: 66, height: 66)
                            Circle()
                                .fill(NOWColor.laGold)
                                .frame(width: 12, height: 12)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text("Start with a loop")
                                .font(.headline.weight(.heavy))
                                .foregroundStyle(NOWColor.surface)
                            Text("A 10-second video hello - golden hour is your best light.")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(NOWColor.surface.opacity(0.78))
                                .lineLimit(2)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NOWColor.surface.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(NOWColor.surface.opacity(0.22), lineWidth: 1)
                    )

                    if let url = appState.theirFirstLoopURL {
                        LoopVideoPlayer(url: url)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }

                    #if targetEnvironment(simulator)
                    PhotosPicker(selection: $selectedVideo, matching: .videos) {
                        Text(match.myFirstLoopSent ? "Waiting for their loop" : "Choose a test loop")
                    }
                    .disabled(match.myFirstLoopSent)
                    .buttonStyle(LightButtonStyle())
                    #else
                    Button(match.myFirstLoopSent ? "Waiting for their loop" : "Record a loop") {
                        showVideoCapture = true
                    }
                    .disabled(match.myFirstLoopSent)
                    .buttonStyle(LightButtonStyle())
                    #endif

                    if let errorMessage = appState.errorMessage {
                        Text(errorMessage)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(NOWColor.surface)
                            .padding(.horizontal, 4)
                    }

                    Button("Close kindly") {
                        appState.cancelMatch()
                    }
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(NOWColor.surface.opacity(0.74))
                    .frame(maxWidth: .infinity)

                    Spacer()
                }
                .padding(22)
            }
        }
        .sheet(isPresented: $showVideoCapture) {
            VideoCapturePicker { url in
                showVideoCapture = false
                appState.sendFirstLoop(videoURL: url)
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedVideo) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let video = try await item.loadTransferable(type: PickedLoopVideo.self) else {
                        appState.errorMessage = "Could not read the selected video."
                        return
                    }
                    appState.sendFirstLoop(videoURL: video.url)
                } catch {
                    appState.errorMessage = "Could not open the selected video."
                }
                selectedVideo = nil
            }
        }
    }
}

private struct PickedLoopVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let fileExtension = received.file.pathExtension.isEmpty
                ? "mov"
                : received.file.pathExtension
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
            try FileManager.default.copyItem(at: received.file, to: destination)
            return PickedLoopVideo(url: destination)
        }
    }
}

struct LoopVideoPlayer: View {
    @State private var player: AVPlayer

    init(url: URL) {
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player.play()
            }
            .onDisappear {
                player.pause()
            }
    }
}

private struct VideoCapturePicker: UIViewControllerRepresentable {
    let onPicked: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.movie.identifier]
        picker.videoMaximumDuration = 10
        picker.videoQuality = .typeMedium
        picker.allowsEditing = true
        picker.cameraCaptureMode = .video
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onPicked: (URL) -> Void

        init(onPicked: @escaping (URL) -> Void) {
            self.onPicked = onPicked
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let url = info[.mediaURL] as? URL else {
                picker.dismiss(animated: true)
                return
            }
            onPicked(url)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
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

private struct LightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.heavy))
            .foregroundStyle(NOWColor.laEspresso)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(NOWColor.surface.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(Capsule())
    }
}

private struct OutlineLightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(NOWColor.surface)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(NOWColor.surface.opacity(configuration.isPressed ? 0.14 : 0.04))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(NOWColor.surface.opacity(0.58), lineWidth: 1))
    }
}
