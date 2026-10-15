import AVFoundation
import Observation

/// A voice the phone can read with. Siri's own voices are reserved by Apple, so these are the
/// system voices: Premium and Enhanced ones sound closest to Siri.
struct SpeechVoice: Identifiable, Hashable, Sendable {
    enum Quality: Int, Comparable, Sendable {
        case standard, enhanced, premium

        var label: String {
            switch self {
            case .standard: "Standard"
            case .enhanced: "Enhanced"
            case .premium: "Premium"
            }
        }

        static func < (lhs: Quality, rhs: Quality) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let id: String
    let name: String
    /// "United States", "United Kingdom"...
    let region: String
    let language: String
    let quality: Quality

    /// English (or the phone's language) voices, best first. Built once, since listing voices is slow.
    static let installed: [SpeechVoice] = {
        let language = AVSpeechSynthesisVoice.currentLanguageCode()
        let prefix = String(language.prefix(2))
        return AVSpeechSynthesisVoice.speechVoices()
            // Skip the novelty voices (Bells, Bubbles…) and the robotic Eloquence ones.
            .filter { $0.language.hasPrefix(prefix) && !$0.identifier.contains("speech.synthesis")
                && !$0.identifier.contains("eloquence") }
            .map { voice in
                let quality: Quality = switch voice.quality {
                case .premium: .premium
                case .enhanced: .enhanced
                default: .standard
                }
                let code = voice.language.split(separator: "-").last.map(String.init) ?? ""
                return SpeechVoice(id: voice.identifier, name: voice.name,
                                   region: Locale.current.localizedString(forRegionCode: code) ?? voice.language,
                                   language: voice.language, quality: quality)
            }
            .sorted { lhs, rhs in
                if lhs.quality != rhs.quality { return lhs.quality > rhs.quality }
                if (lhs.language == language) != (rhs.language == language) { return lhs.language == language }
                return lhs.name < rhs.name
            }
    }()

    /// The voice chosen in Settings, or the best one installed.
    static func preferred(_ id: String) -> String? {
        installed.first { $0.id == id }?.id ?? installed.first?.id
    }
}

/// Reads recipe steps aloud with a voice on the phone, so you can cook without looking at
/// (or touching) the screen. Runs on the device: free, offline and instant.
/// One reader is shared by the whole app, so the speech engine starts only once.
@MainActor
@Observable
final class StepReader: NSObject {
    /// How fast to talk, as set in Settings.
    enum Speed: String, CaseIterable, Identifiable {
        case slower = "Slower", normal = "Normal", faster = "Faster"

        var id: String { rawValue }

        fileprivate var rate: Float {
            switch self {
            case .slower: AVSpeechUtteranceDefaultSpeechRate * 0.85
            case .normal: AVSpeechUtteranceDefaultSpeechRate
            case .faster: AVSpeechUtteranceDefaultSpeechRate * 1.12
            }
        }
    }

    /// Settings keys.
    static let voiceKey = "speechVoice", speedKey = "speechSpeed"

    private(set) var isSpeaking = false
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    /// The utterance we're waiting on, so a late "cancelled" from the previous one is ignored.
    @ObservationIgnored private var current: ObjectIdentifier?
    @ObservationIgnored private var sessionActive = false

    override init() {
        super.init()
        synthesizer.delegate = self
        // Listing voices takes a moment; do it now, off the main thread, instead of on the first step.
        Task.detached(priority: .utility) { _ = SpeechVoice.installed }
    }

    /// Stops whatever is playing and reads `text` with the voice and speed from Settings
    /// (or `voiceID`, to preview a voice).
    func read(_ text: String, voiceID: String? = nil) {
        let defaults = UserDefaults.standard
        let speed = defaults.string(forKey: Self.speedKey).flatMap(Speed.init(rawValue:)) ?? .normal
        let voice = (voiceID ?? SpeechVoice.preferred(defaults.string(forKey: Self.voiceKey) ?? ""))
            .flatMap(AVSpeechSynthesisVoice.init(identifier:))

        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        if !sessionActive {
            // Plays even with the silent switch on, and turns music down instead of stopping it.
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try? session.setActive(true)
            sessionActive = true
        }

        let utterance = AVSpeechUtterance(string: Self.speakable(text))
        utterance.voice = voice ?? AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        utterance.rate = speed.rate
        current = ObjectIdentifier(utterance)
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        current = nil
        isSpeaking = false
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
    }

    /// Stops and hands audio back to other apps (music comes back up). Call when leaving cooking mode.
    func finish() {
        stop()
        guard sessionActive else { return }
        sessionActive = false
        Task.detached(priority: .utility) {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    fileprivate func ended(_ utterance: ObjectIdentifier) {
        guard utterance == current else { return }
        current = nil
        isSpeaking = false
    }

    /// Spells out kitchen shorthand so it's read as words: "1½ tbsp" → "1 and a half tablespoons".
    static func speakable(_ text: String) -> String {
        let fractions: [Character: String] = ["½": "a half", "¼": "a quarter", "¾": "three quarters",
                                              "⅓": "a third", "⅔": "two thirds", "⅛": "an eighth"]
        // "1½" → "1 and a half"; a fraction on its own ("½ cup") → "a half".
        var text = text.replacing(#/(\d?)([½¼¾⅓⅔⅛])/#) { match in
            let words = fractions[match.2.first!] ?? ""
            return match.1.isEmpty ? words : "\(match.1) and \(words)"
        }
        let abbreviations: [(Regex<Substring>, String)] = [
            (#/\btbsp\b\.?/#, "tablespoons"), (#/\btsp\b\.?/#, "teaspoons"), (#/\boz\b\.?/#, "ounces"),
            (#/\blbs?\b\.?/#, "pounds"), (#/\bmin\b\.?/#, "minutes"),
            (#/°F/#, " degrees"), (#/°C/#, " degrees Celsius"),
        ]
        for (pattern, words) in abbreviations { text = text.replacing(pattern, with: words) }
        return text
    }
}

extension StepReader: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.ended(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.ended(id) }
    }
}
