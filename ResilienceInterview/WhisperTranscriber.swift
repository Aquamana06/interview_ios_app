import Foundation
import SwiftWhisper

@MainActor
final class WhisperTranscriber: NSObject, WhisperDelegate {
    private let whisper: Whisper
    private var progressHandler: ((Double) -> Void)?

    init(modelURL: URL) {
        whisper = Whisper(fromFileURL: modelURL)
        super.init()
        whisper.delegate = self
    }

    func transcribe(audioURL: URL, progress: @escaping (Double) -> Void) async throws -> String {
        let frames = try AudioPCMConverter.pcmFloats(from: audioURL)
        progressHandler = progress
        defer { progressHandler = nil }
        let segments = try await whisper.transcribe(audioFrames: frames)
        return segments.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func whisper(_ aWhisper: Whisper, didUpdateProgress progress: Double) { progressHandler?(progress) }
    func whisper(_ aWhisper: Whisper, didProcessNewSegments segments: [Segment], atIndex index: Int) {}
    func whisper(_ aWhisper: Whisper, didCompleteWithSegments segments: [Segment]) {}
    func whisper(_ aWhisper: Whisper, didErrorWith error: Error) {}
}
