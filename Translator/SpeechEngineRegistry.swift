import Foundation
import AVFoundation
import Combine

// MARK: - Engine Protocols

protocol SttEngine {
    func startRecognition(language: String) async throws
    func stopRecognition() async throws
    func processAudioChunk(_ data: Data) async throws
    func isAvailable() -> Bool
    func getName() -> String
}

protocol TtsEngine {
    func synthesize(text: String, language: String) async throws -> Data
    func getVoices() async throws -> [Voice]
    func isAvailable() -> Bool
    func getName() -> String
}

// MARK: - Engine Registry

@MainActor
class SpeechEngineRegistry: ObservableObject {
    // ObservableObject conformance
    let objectWillChange = ObservableObjectPublisher()
    private var sttEngines: [String: SttEngine] = [:]
    private var ttsEngines: [String: TtsEngine] = [:]
    private var userPreferences: [String: String] = [:] // userId -> engineId

    // MARK: - STT Engine Management

    func registerSttEngine(_ id: String, engine: SttEngine) {
        sttEngines[id] = engine
    }

    func unregisterSttEngine(_ id: String) {
        sttEngines.removeValue(forKey: id)
    }

    func getSttEngine(for userId: String? = nil) -> SttEngine? {
        let engineId = userId.flatMap { userPreferences[$0] } ?? "google-cloud"
        return sttEngines[engineId] ?? sttEngines["google-cloud"]
    }

    func getAvailableSttEngines() -> [String: SttEngine] {
        return sttEngines.filter { $0.value.isAvailable() }
    }

    // MARK: - TTS Engine Management

    func registerTtsEngine(_ id: String, engine: TtsEngine) {
        ttsEngines[id] = engine
    }

    func unregisterTtsEngine(_ id: String) {
        ttsEngines.removeValue(forKey: id)
    }

    func getTtsEngine(for userId: String? = nil) -> TtsEngine? {
        let engineId = userId.flatMap { userPreferences[$0] } ?? "google-cloud"
        return ttsEngines[engineId] ?? ttsEngines["google-cloud"]
    }

    func getAvailableTtsEngines() -> [String: TtsEngine] {
        return ttsEngines.filter { $0.value.isAvailable() }
    }

    // MARK: - User Preferences

    func setUserSttPreference(userId: String, engineId: String) {
        userPreferences[userId] = engineId
    }

    func getUserSttPreference(userId: String) -> String? {
        return userPreferences[userId]
    }

    // MARK: - Initialization

    func initializeDefaultEngines(apiRepository: ApiRepository) {
        // Register Google Cloud STT Engine
        let googleSttEngine = GoogleCloudSttEngine(apiRepository: apiRepository)
        registerSttEngine("google-cloud", engine: googleSttEngine)

        // Register Google Cloud TTS Engine
        let googleTtsEngine = GoogleCloudTtsEngine(apiRepository: apiRepository)
        registerTtsEngine("google-cloud", engine: googleTtsEngine)
    }
}

// MARK: - Google Cloud STT Engine Implementation

class GoogleCloudSttEngine: SttEngine {
    private let apiRepository: ApiRepository
    private var isRecognitionActive = false

    init(apiRepository: ApiRepository) {
        self.apiRepository = apiRepository
    }

    func startRecognition(language: String) async throws {
        // This would integrate with the WebSocketManager for actual recognition
        // For now, just mark as active
        isRecognitionActive = true
    }

    func stopRecognition() async throws {
        isRecognitionActive = false
    }

    func processAudioChunk(_ data: Data) async throws {
        guard isRecognitionActive else { return }
        // Audio processing would be handled by WebSocketManager
        // This is just the interface
    }

    func isAvailable() -> Bool {
        return true // Google Cloud is always available in this implementation
    }

    func getName() -> String {
        return "Google Cloud Speech-to-Text"
    }
}

// MARK: - Google Cloud TTS Engine Implementation

class GoogleCloudTtsEngine: TtsEngine {
    private let apiRepository: ApiRepository
    private let ttsCache = TTSCache()

    init(apiRepository: ApiRepository) {
        self.apiRepository = apiRepository
    }

    func synthesize(text: String, language: String) async throws -> Data {
        // Check cache first
        if let cachedData = ttsCache.getAudio(for: text, language: language) {
            return cachedData
        }

        // Synthesize new audio
        let audioData = try await apiRepository.synthesizeSpeech(text: text, language: language)

        // Cache the result
        ttsCache.setAudio(audioData, for: text, language: language)

        return audioData
    }

    func getVoices() async throws -> [Voice] {
        return try await apiRepository.getVoices()
    }

    func isAvailable() -> Bool {
        return true // Google Cloud is always available in this implementation
    }

    func getName() -> String {
        return "Google Cloud Text-to-Speech"
    }
}