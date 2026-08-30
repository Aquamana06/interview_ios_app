import Foundation
import Combine

@MainActor
final class TranscriptionViewModel: ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var progress = 0.0
    @Published private(set) var isRecording = false
    @Published private(set) var isTranscribing = false
    @Published private(set) var isSending = false
    @Published private(set) var elapsedSeconds = 0
    @Published var isShowingError = false
    @Published var errorMessage = ""

    private let modelURL: URL?
    private let recorder = AudioRecorder()
    private let transcriber: WhisperTranscriber?
    private let api: InterviewAPIClient
    private let sessionID: String
    private let language: String
    private var timer: Timer?

    init(api: InterviewAPIClient, sessionID: String, language: String) {
        self.api = api
        self.sessionID = sessionID
        self.language = language
        let url = ModelStore().defaultModelURL()
        modelURL = url
        transcriber = url.map { WhisperTranscriber(modelURL: $0) }
    }

    var hasModel: Bool { modelURL != nil && transcriber != nil }
    var elapsedRecordingTime: String { String(format: "%02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60) }

    func toggleRecording() async {
        if isRecording { await stopRecording() } else { await startRecording() }
    }

    func clearTranscript() { transcript = ""; progress = 0 }

    private func startRecording() async {
        do {
            try await recorder.start()
            elapsedSeconds = 0
            isRecording = true
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.elapsedSeconds += 1 }
            }
        } catch { show(error) }
    }

    private func stopRecording() async {
        timer?.invalidate(); timer = nil
        do {
            let url = try recorder.stop()
            isRecording = false
            try await transcribe(audioURL: url)
            try? FileManager.default.removeItem(at: url)
        } catch {
            isRecording = false
            isTranscribing = false
            isSending = false
            show(error)
        }
    }

    private func transcribe(audioURL: URL) async throws {
        guard let transcriber else { throw TranscriptionError.missingModel }
        isTranscribing = true
        progress = 0
        let text = try await transcriber.transcribe(audioURL: audioURL) { [weak self] value in
            let safeValue = value.isFinite ? min(max(value, 0), 1) : 0
            Task { @MainActor [weak self] in self?.progress = safeValue }
        }
        transcript = text
        progress = 1
        isTranscribing = false
        try await sendTranscript()
    }

    private func sendTranscript() async throws {
        guard !transcript.isEmpty else { throw TranscriptionError.emptyTranscript }
        isSending = true
        defer { isSending = false }
        _ = try await api.sendTranscript(sessionID: sessionID, text: transcript, language: language,
                                         clientMessageID: UUID().uuidString)
    }

    private func show(_ error: Error) {
        errorMessage = error.localizedDescription
        isShowingError = true
    }
}
