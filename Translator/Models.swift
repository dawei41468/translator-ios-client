import Foundation

// MARK: - Auth & User
struct AuthUser: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let email: String
    let displayName: String?
    let language: String
    let isGuest: Bool?
    let preferences: UserPreferences?
}

struct UserPreferences: Codable, Equatable {
    let sttEngine: String?
    let ttsEngine: String?
    let translationEngine: String?
}

// MARK: - Rooms & Participants
struct RoomInfo: Codable {
    let id: String
    let code: String
    let participants: [Participant]
}

struct Participant: Codable, Identifiable {
    let id: String
    let name: String
    let language: String
}

// MARK: - Messages (Web/Android + isOwn for UI)
struct TranslatedMessage: Codable, Identifiable {
    let originalText: String
    let translatedText: String
    let sourceLang: String
    let targetLang: String
    let fromUserId: String
    let toUserId: String
    let speakerName: String
    
    // UI helpers (not Codable)
    var id: UUID = UUID()
    var isOwn: Bool = false
}

// MARK: - Speech & TTS (48kHz fixed, web pillars)
struct SpeechConfig: Codable {
    let languageCode: String  // BCP47 "en-US"
    var soloMode: Bool = false
    var soloTargetLang: String?
    var encoding: String = "LINEAR16"
    var sampleRateHertz: Int = 48000
}

struct TtsRequest: Codable {
    let text: String
    let languageCode: String
    let voiceName: String?
    let ssmlGender: String?  // "FEMALE" etc.
}

struct Voice: Codable, Identifiable {
    let name: String
    let languageCodes: [String]
    let ssmlGender: String
    let naturalSampleRateHertz: Int?

    var id: String { name }
}

// MARK: - Requests/Responses
struct LoginRequest: Codable { let email: String; let password: String }
struct AuthResponse: Codable {
    let user: AuthUser
    let token: String
}

struct RegisterRequest: Codable { let email: String; let password: String; let name: String }
struct GuestRequest: Codable { let displayName: String }

struct UpdateMeRequest: Codable {
    let displayName: String?
    let language: String?
    let preferences: UserPreferences?
}

struct RoomResponse: Codable {
    let roomId: String
    let roomCode: String
    let alreadyJoined: Bool?
}

// MARK: - Error Categories (webapp-style)
enum TranslationError: String, Error {
    case sttStreamError = "STT_STREAM_ERROR"
    case ttsFailed = "TTS_FAILED"
    case vadError = "VAD_ERROR"
    case recordingStartFailed = "RECORDING_START_FAILED"
    case clientError = "CLIENT_ERROR"
    case networkError = "NETWORK_ERROR"
    case authError = "AUTH_ERROR"
    case roomError = "ROOM_ERROR"

    var userMessage: String {
        switch self {
        case .sttStreamError:
            return "Speech recognition failed. Please try again."
        case .ttsFailed:
            return "Text-to-speech failed. Audio may not play."
        case .vadError:
            return "Voice detection error. Try push-to-talk mode."
        case .recordingStartFailed:
            return "Microphone access denied. Please check permissions."
        case .clientError:
            return "An unexpected error occurred. Please restart the app."
        case .networkError:
            return "Network connection lost. Please check your internet."
        case .authError:
            return "Authentication failed. Please log in again."
        case .roomError:
            return "Room connection failed. Please try joining again."
        }
    }

    var debugDescription: String {
        switch self {
        case .sttStreamError:
            return "Speech-to-text streaming failed"
        case .ttsFailed:
            return "Text-to-speech synthesis failed"
        case .vadError:
            return "Voice activity detection failed"
        case .recordingStartFailed:
            return "Audio recording initialization failed"
        case .clientError:
            return "General client-side error"
        case .networkError:
            return "Network connectivity issue"
        case .authError:
            return "Authentication/authorization failure"
        case .roomError:
            return "Room management error"
        }
    }
}

// MARK: - Recent Rooms (@AppStorage)
struct RecentRoom: Codable, Identifiable {
    let code: String
    var lastUsedAt: TimeInterval

    var id: String { code }
}

