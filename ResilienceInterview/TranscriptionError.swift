import Foundation

enum TranscriptionError: LocalizedError {
    case missingModel, microphonePermissionDenied, recordingFailed, audioConversionFailed
    case emptyTranscript, workerConfigurationMissing
    var errorDescription: String? {
        switch self {
        case .missingModel: return "ggml-small.bin がアプリに含まれていません。"
        case .microphonePermissionDenied: return "文字起こしのためにマイクへのアクセスを許可してください。"
        case .recordingFailed: return "録音を開始または停止できませんでした。"
        case .audioConversionFailed: return "音声を16kHz mono PCMへ変換できませんでした。"
        case .emptyTranscript: return "文字起こし結果が空のため送信できません。"
        case .workerConfigurationMissing: return "WorkerのURL、session ID、Bearer tokenを入力してください。"
        }
    }
}
