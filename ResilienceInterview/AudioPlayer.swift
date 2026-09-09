@preconcurrency import AVFoundation
import Combine

@MainActor
final class AudioPlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    @Published private(set) var isSpeaking = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, language: String, onProgress: ((String) -> Void)? = nil) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language == "ja" ? "ja-JP" : language == "de" ? "de-DE" : "en-US")
        utterance.rate = 0.46
        utterance.pitchMultiplier = 1.18
        utterance.volume = 0.92
        speechProgressHandler = onProgress
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        speechProgressHandler = nil
    }

    private var speechProgressHandler: ((String) -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           willSpeakRangeOfSpeechString characterRange: NSRange,
                           utterance: AVSpeechUtterance) {
        let endOffset = min(characterRange.location + characterRange.length, utterance.speechString.utf16.count)
        let endIndex = String.Index(utf16Offset: endOffset, in: utterance.speechString)
        speechProgressHandler?(String(utterance.speechString[..<endIndex]))
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
        speechProgressHandler?(utterance.speechString)
        speechProgressHandler = nil
    }
}
