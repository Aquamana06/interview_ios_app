import AVFoundation
import Foundation

enum AudioPCMConverter {
    static func pcmFloats(from sourceURL: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: sourceURL)
        guard let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: file.processingFormat, to: outputFormat) else {
            throw TranscriptionError.audioConversionFailed
        }
        let duration = Double(file.length) / file.processingFormat.sampleRate
        let capacity = AVAudioFrameCount(max(1, ceil(duration * outputFormat.sampleRate))) + 1_024
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            throw TranscriptionError.audioConversionFailed
        }
        var supplied = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            if supplied { inputStatus.pointee = .endOfStream; return nil }
            guard let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
                inputStatus.pointee = .noDataNow; return nil
            }
            do {
                try file.read(into: input)
                supplied = true
                inputStatus.pointee = .haveData
                return input
            } catch {
                inputStatus.pointee = .noDataNow
                return nil
            }
        }
        if let conversionError { throw conversionError }
        guard status != .error, let channelData = output.floatChannelData?[0] else {
            throw TranscriptionError.audioConversionFailed
        }
        return Array(UnsafeBufferPointer(start: channelData, count: Int(output.frameLength)))
    }
}
