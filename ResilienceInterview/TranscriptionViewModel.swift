import Foundation
import Combine

@MainActor
final class TranscriptionViewModel: ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var progress = 0.0
    @Published private(set) var isRecording = false
    @Published private(set) var isTranscribing = false
    @Published private(set) var isSending = false
    @Published private(set) var messages: [InterviewMessage]
    @Published private(set) var elapsedSeconds = 0
    @Published var isShowingError = false
    @Published var errorMessage = ""

    private let modelURL: URL?
    private let recorder = AudioRecorder()
    private let transcriber: WhisperTranscriber?
    private let api: InterviewAPIClient
    private let sessionID: String
    private let language: String
    private let player = AudioPlayer()
    private var timer: Timer?
    private var isEnded = false

    init(api: InterviewAPIClient, sessionID: String, language: String, initialMessages: [InterviewMessage] = []) {
        self.api = api
        self.sessionID = sessionID
        self.language = language
        messages = initialMessages
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

    func speakInitialMessage() {
        guard let message = messages.last(where: { $0.role == "system" }) else { return }
        player.speak(message.content, language: language)
    }

    func stopSpeaking() { player.stop() }

    func forceEndInterview() {
        isEnded = true
        timer?.invalidate()
        timer = nil
        if isRecording {
            recorder.cancel()
            isRecording = false
        }
        player.stop()
        isTranscribing = false
        isSending = false
    }

    private func startRecording() async {
        guard !isEnded else { return }
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
        guard !isEnded else { return }
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
        guard !isEnded else { return }
        try await sendTranscript()
    }

    private func sendTranscript() async throws {
        guard !isEnded else { return }
        guard !transcript.isEmpty else { throw TranscriptionError.emptyTranscript }
        isSending = true
        defer { isSending = false }
        let result = try await api.sendTranscript(sessionID: sessionID, text: transcript, language: language,
                                                   clientMessageID: UUID().uuidString)
        guard !isEnded else { return }
        messages = result.messages
        if let latest = result.messages.last(where: { $0.role == "system" }) {
            player.speak(latest.content, language: language)
        }
    }

    private func show(_ error: Error) {
        errorMessage = error.localizedDescription
        isShowingError = true
    }
}
