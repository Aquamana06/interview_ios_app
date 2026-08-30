import AVFoundation
import Foundation

@MainActor
final class AudioRecorder: NSObject {
    private var recorder: AVAudioRecorder?
    private var currentURL: URL?

    func start() async throws {
        guard await requestPermission() else { throw TranscriptionError.microphonePermissionDenied }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.allowBluetoothHFP])
        try session.setActive(true)
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("answer-(UUID().uuidString).wav")
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false]
        let value = try AVAudioRecorder(url: url, settings: settings)
        guard value.record() else { throw TranscriptionError.recordingFailed }
        recorder = value
        currentURL = url
    }

    func stop() throws -> URL {
        guard let recorder, let currentURL else { throw TranscriptionError.recordingFailed }
        recorder.stop()
        self.recorder = nil
        self.currentURL = nil
        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return currentURL
    }

    func cancel() {
        recorder?.stop()
        recorder = nil
        if let currentURL {
            try? FileManager.default.removeItem(at: currentURL)
        }
        self.currentURL = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in continuation.resume(returning: granted) }
        }
    }
}
