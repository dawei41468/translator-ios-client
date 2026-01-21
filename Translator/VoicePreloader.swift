import Foundation
import AVFoundation
import Combine

@MainActor
class VoicePreloader: ObservableObject {
    // ObservableObject conformance
    let objectWillChange = ObservableObjectPublisher()
    private let speechEngineRegistry: SpeechEngineRegistry
    private let ttsCache = TTSCache()
    private var preloadedVoices: Set<String> = []
    private var isPreloading = false

    @Published var preloadProgress: Double = 0.0
    @Published var isPreloadingVoices = false

    init(speechEngineRegistry: SpeechEngineRegistry) {
        self.speechEngineRegistry = speechEngineRegistry
    }

    func preloadVoices(for user: AuthUser?) async {
        guard !isPreloading else { return }
        guard let user = user else { return }

        isPreloading = true
        isPreloadingVoices = true
        preloadProgress = 0.0

        defer {
            isPreloading = false
            isPreloadingVoices = false
        }

        do {
            let ttsEngine = speechEngineRegistry.getTtsEngine(for: user.id)
            guard let ttsEngine = ttsEngine else {
                print("No TTS engine available for preloading")
                return
            }

            let voices = try await ttsEngine.getVoices()

            // Filter voices for user's language and common languages
            let userLanguage = normalizeLanguage(user.language)
            let commonLanguages = ["en", "es", "fr", "de", "zh", "ja", "ko", "ar", "hi", "pt"]

            let voicesToPreload = voices.filter { voice in
                let voiceLang = normalizeLanguage(voice.languageCodes.first ?? "")
                return voiceLang == userLanguage || commonLanguages.contains(voiceLang)
            }.prefix(10) // Limit to 10 voices to avoid excessive preloading

            let totalVoices = voicesToPreload.count
            var completedCount = 0

            for voice in voicesToPreload {
                guard !preloadedVoices.contains(voice.name) else {
                    completedCount += 1
                    preloadProgress = Double(completedCount) / Double(totalVoices)
                    continue
                }

                // Preload a sample phrase for this voice
                let sampleText = getSampleText(for: voice.languageCodes.first ?? "en")
                let language = voice.languageCodes.first ?? "en-US"

                do {
                    let audioData = try await ttsEngine.synthesize(text: sampleText, language: language)
                    ttsCache.setAudio(audioData, for: sampleText, language: language)
                    preloadedVoices.insert(voice.name)
                    print("Preloaded voice: \(voice.name)")
                } catch {
                    print("Failed to preload voice \(voice.name): \(error)")
                }

                completedCount += 1
                preloadProgress = Double(completedCount) / Double(totalVoices)

                // Small delay to avoid overwhelming the API
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }

            print("Voice preloading completed. Preloaded \(preloadedVoices.count) voices.")

        } catch {
            print("Voice preloading failed: \(error)")
        }
    }

    func isVoicePreloaded(_ voiceName: String) -> Bool {
        return preloadedVoices.contains(voiceName)
    }

    func clearPreloadedVoices() {
        preloadedVoices.removeAll()
        preloadProgress = 0.0
    }

    private func normalizeLanguage(_ language: String) -> String {
        return language.split(separator: "-").first?.lowercased() ?? language.lowercased()
    }

    private func getSampleText(for language: String) -> String {
        let lang = normalizeLanguage(language)

        switch lang {
        case "en":
            return "Hello, this is a sample voice."
        case "es":
            return "Hola, esta es una muestra de voz."
        case "fr":
            return "Bonjour, ceci est un exemple de voix."
        case "de":
            return "Hallo, dies ist eine Beispielstimme."
        case "zh":
            return "你好，这是一个语音样本。"
        case "ja":
            return "こんにちは、これは音声サンプルです。"
        case "ko":
            return "안녕하세요, 이것은 음성 샘플입니다."
        case "ar":
            return "مرحبا، هذا نموذج صوتي."
        case "hi":
            return "नमस्ते, यह एक आवाज़ नमूना है।"
        case "pt":
            return "Olá, esta é uma amostra de voz."
        default:
            return "Hello, this is a sample voice."
        }
    }
}