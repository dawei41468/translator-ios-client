import Foundation

// MARK: - Auth & User
struct AuthUser: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let displayName: String?
    let language: String
    let isGuest: Bool?
    let preferences: UserPreferences?
    
    var id: String { id } // Identifiable conformance
}

struct UserPreferences: Codable {
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
    
    var id: String { id }
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
    let encoding: String = "LINEAR16"
    let sampleRateHertz: Int = 48000
}

struct TtsRequest: Codable {
    let text: String
    let languageCode: String
    let voiceName: String?
    let ssmlGender: String?  // "FEMALE" etc.
}

// MARK: - Requests/Responses
struct LoginRequest: Codable { let email: String; let password: String }
struct AuthResponse: Codable { let user: AuthUser }

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

// MARK: - Recent Rooms (@AppStorage)
struct RecentRoom: Codable, Identifiable {
    let code: String
    let lastUsedAt: TimeInterval
    
    var id: String { code }
}
