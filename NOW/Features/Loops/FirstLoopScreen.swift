import SwiftUI
@preconcurrency import AVFoundation
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
                        CircularLoopPlayer(
                            url: url,
                            diameter: 180,
                            strokeColor: NOWColor.surface.opacity(0.72),
                            lineWidth: 3
                        )
                        .frame(maxWidth: .infinity)
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
            LoopRecorderScreen { url in
                showVideoCapture = false
                appState.sendFirstLoop(videoURL: url)
            }
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

enum LoopVideoProcessor {
    static let maximumDuration: Double = 10
    private static let renderSize = CGSize(width: 720, height: 1_280)

    static func prepareForUpload(_ inputURL: URL) async throws -> URL {
        let sourceAsset = AVURLAsset(url: inputURL)
        let duration = try await sourceAsset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw LoopVideoProcessingError.invalidDuration
        }

        guard let sourceVideoTrack = try await sourceAsset.loadTracks(withMediaType: .video).first else {
            throw LoopVideoProcessingError.missingVideoTrack
        }

        let clipDuration = CMTime(
            seconds: min(durationSeconds, maximumDuration),
            preferredTimescale: 600
        )
        let timeRange = CMTimeRange(start: .zero, duration: clipDuration)
        let composition = AVMutableComposition()

        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw LoopVideoProcessingError.couldNotCreateComposition
        }
        try compositionVideoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: .zero)

        if let sourceAudioTrack = try await sourceAsset.loadTracks(withMediaType: .audio).first,
           let compositionAudioTrack = composition.addMutableTrack(
               withMediaType: .audio,
               preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try? compositionAudioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: .zero)
        }

        let naturalSize = try await sourceVideoTrack.load(.naturalSize)
        let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
        let sourceRect = CGRect(origin: .zero, size: naturalSize)
            .applying(preferredTransform)
            .standardized
        guard sourceRect.width > 0, sourceRect.height > 0 else {
            throw LoopVideoProcessingError.invalidVideoGeometry
        }

        let scale = max(
            renderSize.width / sourceRect.width,
            renderSize.height / sourceRect.height
        )
        let scaledSize = CGSize(
            width: sourceRect.width * scale,
            height: sourceRect.height * scale
        )
        let centerTranslation = CGAffineTransform(
            translationX: (renderSize.width - scaledSize.width) / 2,
            y: (renderSize.height - scaledSize.height) / 2
        )
        let normalizedTransform = preferredTransform
            .concatenating(
                CGAffineTransform(
                    translationX: -sourceRect.minX,
                    y: -sourceRect.minY
                )
            )
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(centerTranslation)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(
            assetTrack: compositionVideoTrack
        )
        layerInstruction.setTransform(normalizedTransform, at: .zero)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = timeRange
        instruction.layerInstructions = [layerInstruction]

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.instructions = [instruction]

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("now-loop-ready-\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: outputURL)

        guard let exporter = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPreset1280x720
        ) else {
            throw LoopVideoProcessingError.exportUnavailable
        }
        exporter.outputURL = outputURL
        exporter.outputFileType = .mp4
        exporter.shouldOptimizeForNetworkUse = true
        exporter.videoComposition = videoComposition

        try await export(exporter)

        guard let fileSize = try outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              fileSize > 0 else {
            throw LoopVideoProcessingError.emptyOutput
        }

        let outputAsset = AVURLAsset(url: outputURL)
        guard let outputTrack = try await outputAsset.loadTracks(withMediaType: .video).first else {
            throw LoopVideoProcessingError.missingVideoTrack
        }
        let formatDescriptions = try await outputTrack.load(.formatDescriptions)
        guard formatDescriptions.contains(where: {
            CMFormatDescriptionGetMediaSubType($0) == kCMVideoCodecType_H264
        }) else {
            try? FileManager.default.removeItem(at: outputURL)
            throw LoopVideoProcessingError.unsupportedCodec
        }

        return outputURL
    }

    private static func export(_ exporter: AVAssetExportSession) async throws {
        let exporterBox = ExportSessionBox(exporter)
        try await withCheckedThrowingContinuation { continuation in
            exporterBox.session.exportAsynchronously {
                switch exporterBox.session.status {
                case .completed:
                    continuation.resume()
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                default:
                    continuation.resume(
                        throwing: exporterBox.session.error ?? LoopVideoProcessingError.exportFailed
                    )
                }
            }
        }
    }
}

private final class ExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) {
        self.session = session
    }
}

private enum LoopVideoProcessingError: LocalizedError {
    case invalidDuration
    case missingVideoTrack
    case couldNotCreateComposition
    case invalidVideoGeometry
    case exportUnavailable
    case exportFailed
    case emptyOutput
    case unsupportedCodec

    var errorDescription: String? {
        switch self {
        case .invalidDuration:
            return "The video duration is invalid."
        case .missingVideoTrack:
            return "The selected file does not contain video."
        case .couldNotCreateComposition, .exportUnavailable, .exportFailed:
            return "The First Loop could not be prepared."
        case .invalidVideoGeometry:
            return "The video dimensions are invalid."
        case .emptyOutput:
            return "The prepared First Loop is empty."
        case .unsupportedCodec:
            return "The First Loop could not be converted to H.264."
        }
    }
}

struct LoopVideoPlayer: View {
    @StateObject private var model: LoopingVideoPlayerModel
    @State private var isMuted: Bool
    private let togglesAudioOnTap: Bool

    init(url: URL, startsMuted: Bool = false, togglesAudioOnTap: Bool = false) {
        _model = StateObject(wrappedValue: LoopingVideoPlayerModel(url: url))
        _isMuted = State(initialValue: startsMuted)
        self.togglesAudioOnTap = togglesAudioOnTap
    }

    var body: some View {
        LoopPlayerSurface(player: model.player)
            .background(Color.black)
            .onAppear {
                model.setMuted(isMuted)
                model.play()
            }
            .onChange(of: isMuted) { _, newValue in
                model.setMuted(newValue)
            }
            .onDisappear {
                model.stop()
            }
            .onTapGesture {
                guard togglesAudioOnTap else { return }
                isMuted.toggle()
            }
            .overlay(alignment: .bottomTrailing) {
                if togglesAudioOnTap {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.caption.weight(.black))
                        .foregroundStyle(NOWColor.surface)
                        .padding(8)
                        .background(NOWColor.ink.opacity(0.68))
                        .clipShape(Circle())
                        .padding(10)
                        .allowsHitTesting(false)
                }
            }
    }
}

struct CircularLoopPlayer: View {
    let url: URL
    let diameter: CGFloat
    var strokeColor: Color = NOWColor.laOrange
    var lineWidth: CGFloat = 3
    var startsMuted = false
    var togglesAudioOnTap = false

    var body: some View {
        LoopVideoPlayer(url: url, startsMuted: startsMuted, togglesAudioOnTap: togglesAudioOnTap)
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(strokeColor, lineWidth: lineWidth)
            )
            .contentShape(Circle())
    }
}

private final class LoopingVideoPlayerModel: ObservableObject {
    let player: AVQueuePlayer
    private var looper: AVPlayerLooper?

    init(url: URL) {
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.actionAtItemEnd = .none
        self.player = player
        looper = AVPlayerLooper(player: player, templateItem: item)
    }

    func play() {
        player.play()
    }

    func setMuted(_ isMuted: Bool) {
        player.isMuted = isMuted
    }

    func stop() {
        player.pause()
        player.seek(to: .zero)
    }
}

private struct LoopPlayerSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> LoopPlayerView {
        let view = LoopPlayerView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: LoopPlayerView, context: Context) {
        uiView.player = player
    }
}

private final class LoopPlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            playerLayer.videoGravity = .resizeAspectFill
        }
    }
}

private struct LoopRecorderScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = LoopRecorderController()

    let onSend: (URL) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                LAGradient.match.ignoresSafeArea()

                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(recorder.recordedURL == nil ? "Record your loop" : "Your First Loop")
                            .font(.title2.weight(.black))
                            .foregroundStyle(NOWColor.laEspresso)
                        Text("Up to 10 seconds · round · one honest hello")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(NOWColor.laEspresso.opacity(0.72))
                    }

                    ZStack {
                        Circle()
                            .fill(Color.black)

                        if let recordedURL = recorder.recordedURL {
                            LoopVideoPlayer(url: recordedURL)
                                .id(recordedURL)
                        } else {
                            LoopCameraPreview(session: recorder.session)
                        }

                        if recorder.isRecording {
                            VStack {
                                HStack(spacing: 7) {
                                    Circle()
                                        .fill(NOWColor.laCoral)
                                        .frame(width: 9, height: 9)
                                    Text(String(format: "%.1f / 10.0", recorder.elapsed))
                                        .font(.caption.monospacedDigit().weight(.black))
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.black.opacity(0.58))
                                .clipShape(Capsule())
                                .padding(14)

                                Spacer()
                            }
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: 360)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.45), lineWidth: 1)
                    )

                    if let error = recorder.errorMessage {
                        VStack(spacing: 10) {
                            Text(error)
                                .font(.footnote.weight(.bold))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(NOWColor.laEspresso)

                            if recorder.permissionDenied {
                                Button("Open Settings") {
                                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                                    UIApplication.shared.open(url)
                                }
                                .font(.footnote.weight(.black))
                            }
                        }
                    }

                    controls
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NOWColor.laEspresso)
                }
            }
        }
        .interactiveDismissDisabled(recorder.isRecording)
        .onAppear {
            recorder.prepareCamera()
        }
        .onDisappear {
            recorder.stopAndTearDown()
        }
    }

    @ViewBuilder
    private var controls: some View {
        if let recordedURL = recorder.recordedURL {
            HStack(spacing: 12) {
                Button("Retake") {
                    recorder.retake()
                }
                .buttonStyle(OutlineLightButtonStyle())

                Button("Send") {
                    onSend(recordedURL)
                    dismiss()
                }
                .buttonStyle(LightButtonStyle())
            }
        } else {
            Button {
                if recorder.isRecording {
                    recorder.stopRecording()
                } else {
                    recorder.startRecording()
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(NOWColor.surface, lineWidth: 5)
                        .frame(width: 76, height: 76)

                    if recorder.isRecording {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(NOWColor.laCoral)
                            .frame(width: 30, height: 30)
                    } else {
                        Circle()
                            .fill(NOWColor.laCoral)
                            .frame(width: 60, height: 60)
                    }

                    Circle()
                        .trim(from: 0, to: recorder.progress)
                        .stroke(NOWColor.laGold, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 76, height: 76)
                }
            }
            .disabled(!recorder.isReady)
            .buttonStyle(.plain)
            .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Start recording")
        }
    }
}

private final class LoopRecorderController: NSObject, ObservableObject {
    static let maximumDuration: Double = 10

    @Published private(set) var isReady = false
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var recordedURL: URL?
    @Published private(set) var errorMessage: String?
    @Published private(set) var permissionDenied = false

    let session = AVCaptureSession()

    var progress: Double {
        min(elapsed / Self.maximumDuration, 1)
    }

    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "com.sim.now.first-loop-camera")
    private var elapsedTimer: Timer?
    private var configured = false

    func prepareCamera() {
        Task {
            let cameraAllowed = await Self.requestAccess(for: .video)
            let microphoneAllowed = await Self.requestAccess(for: .audio)

            guard cameraAllowed, microphoneAllowed else {
                await MainActor.run {
                    self.permissionDenied = true
                    self.errorMessage = "Camera and microphone access are required to record a First Loop."
                }
                return
            }

            configureAndStartSession()
        }
    }

    func startRecording() {
        guard isReady, !isRecording else { return }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("now-first-loop-\(UUID().uuidString).mov")
        try? FileManager.default.removeItem(at: url)

        if let connection = movieOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }

        movieOutput.maxRecordedDuration = CMTime(seconds: Self.maximumDuration, preferredTimescale: 600)
        recordedURL = nil
        errorMessage = nil
        elapsed = 0
        isRecording = true
        startElapsedTimer()
        movieOutput.startRecording(to: url, recordingDelegate: self)
    }

    func stopRecording() {
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
    }

    func retake() {
        if let recordedURL {
            try? FileManager.default.removeItem(at: recordedURL)
        }
        recordedURL = nil
        elapsed = 0
        errorMessage = nil
        sessionQueue.async { [weak self] in
            guard let self, self.configured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stopAndTearDown() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        if movieOutput.isRecording {
            movieOutput.stopRecording()
        }
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func configureAndStartSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if !self.configured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .hd1280x720

                do {
                    guard let camera = AVCaptureDevice.default(
                        .builtInWideAngleCamera,
                        for: .video,
                        position: .front
                    ) ?? AVCaptureDevice.default(for: .video) else {
                        throw LoopRecorderError.cameraUnavailable
                    }

                    let videoInput = try AVCaptureDeviceInput(device: camera)
                    guard self.session.canAddInput(videoInput) else {
                        throw LoopRecorderError.cameraUnavailable
                    }
                    self.session.addInput(videoInput)

                    guard let microphone = AVCaptureDevice.default(for: .audio) else {
                        throw LoopRecorderError.microphoneUnavailable
                    }
                    let audioInput = try AVCaptureDeviceInput(device: microphone)
                    guard self.session.canAddInput(audioInput) else {
                        throw LoopRecorderError.microphoneUnavailable
                    }
                    self.session.addInput(audioInput)

                    guard self.session.canAddOutput(self.movieOutput) else {
                        throw LoopRecorderError.outputUnavailable
                    }
                    self.session.addOutput(self.movieOutput)
                    self.session.commitConfiguration()
                    self.configured = true
                } catch {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async {
                        self.errorMessage = (error as? LocalizedError)?.errorDescription
                            ?? "Could not start the camera."
                    }
                    return
                }
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }
            DispatchQueue.main.async {
                self.isReady = true
            }
        }
    }

    private func startElapsedTimer() {
        elapsedTimer?.invalidate()
        let startedAt = Date()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            self.elapsed = min(Date().timeIntervalSince(startedAt), Self.maximumDuration)
        }
    }

    private static func requestAccess(for mediaType: AVMediaType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: mediaType) { granted in
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
    }
}

extension LoopRecorderController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        let recordingSucceeded: Bool
        if let error = error as NSError? {
            recordingSucceeded = error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? false
        } else {
            recordingSucceeded = true
        }

        DispatchQueue.main.async {
            self.elapsedTimer?.invalidate()
            self.elapsedTimer = nil
            self.isRecording = false
            self.elapsed = min(self.elapsed, Self.maximumDuration)

            if recordingSucceeded,
               let size = try? outputFileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
               size > 0 {
                self.recordedURL = outputFileURL
                self.errorMessage = nil
                self.sessionQueue.async { [weak self] in
                    guard let self, self.session.isRunning else { return }
                    self.session.stopRunning()
                }
            } else {
                try? FileManager.default.removeItem(at: outputFileURL)
                self.errorMessage = "The loop could not be recorded. Please try again."
            }
        }
    }
}

private struct LoopCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> LoopCameraPreviewView {
        let view = LoopCameraPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: LoopCameraPreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class LoopCameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

private enum LoopRecorderError: LocalizedError {
    case cameraUnavailable
    case microphoneUnavailable
    case outputUnavailable

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "The camera is not available."
        case .microphoneUnavailable:
            return "The microphone is not available."
        case .outputUnavailable:
            return "Video recording is not available."
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
