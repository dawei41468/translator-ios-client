import Foundation

class ApiRepository {
    private let session: URLSession
    private let baseURL: URL

    init(baseURLString: String = "http://localhost:4003") {
        guard let url = URL(string: baseURLString) else {
            fatalError("Invalid baseURL")
        }
        self.baseURL = url
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = .shared  // Persist auth_token

        // Certificate pinning for security (Phase 3)
        let certificatePinner = CertificatePinner()
        self.session = URLSession(configuration: config, delegate: certificatePinner, delegateQueue: nil)
    }
    
    private func post<T: Encodable, U: Decodable>(_ path: String, body: T) async throws -> U {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        
        // Debug logging for auth endpoints
        if path.contains("/auth") {
            if let httpResponse = response as? HTTPURLResponse {
                print("🔐 AUTH API Response [\(httpResponse.statusCode)]: \(path)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response body: \(responseString)")
                } else {
                    print("Response body: (empty or binary, length: \(data.count))")
                }
            }
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(U.self, from: data)
    }

    private func put<T: Encodable, U: Decodable>(_ path: String, body: T) async throws -> U {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        let (data, _) = try await session.data(for: request)
        let decoder = JSONDecoder()
        return try decoder.decode(U.self, from: data)
    }

    private func postData(_ path: String, body: some Encodable) async throws -> Data {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        let (data, _) = try await session.data(for: request)
        return data
    }
    
    struct GuestRequest: Encodable {
        let displayName: String
    }

    struct Empty: Codable {}
    
    func me() async throws -> AuthUser? {
        guard let url = URL(string: "/api/me", relativeTo: baseURL) else { throw URLError(.badURL) }
        let (data, _) = try await session.data(from: url)
        let decoder = JSONDecoder()
        if let response = try? decoder.decode(AuthResponse.self, from: data) {
            return response.user
        } else if let user = try? decoder.decode(AuthUser.self, from: data) {
            return user
        } else {
            return nil
        }
    }
    
    func login(email: String, password: String) async throws -> AuthResponse {
        let body = LoginRequest(email: email, password: password)
        let response: AuthResponse = try await post("/api/auth/login", body: body)
        return response
    }

    func register(email: String, password: String, name: String) async throws -> AuthResponse {
        let body = RegisterRequest(email: email, password: password, name: name)
        let response: AuthResponse = try await post("/api/auth/register", body: body)
        return response
    }

    func guest(displayName: String) async throws -> AuthResponse {
        let body = GuestRequest(displayName: displayName)
        let response: AuthResponse = try await post("/api/auth/guest-login", body: body)
        return response
    }

    func updateMe(request: UpdateMeRequest) async throws -> AuthUser {
        let response: AuthResponse = try await put("/api/me", body: request)
        return response.user
    }

    func createRoom() async throws -> RoomResponse {
        let response: RoomResponse = try await post("/api/rooms", body: Empty())
        return response
    }

    func joinRoom(code: String) async throws -> RoomResponse {
        let response: RoomResponse = try await post("/api/rooms/\(code)/join", body: Empty())
        return response
    }

    func tts(request: TtsRequest) async throws -> Data {
        try await postData("/api/tts/synthesize", body: request)
    }

    // Phase 4: Engine registry support methods
    func synthesizeSpeech(text: String, language: String) async throws -> Data {
        let request = TtsRequest(text: text, languageCode: language, voiceName: nil, ssmlGender: nil)
        return try await tts(request: request)
    }

    func getVoices() async throws -> [Voice] {
        guard let url = URL(string: "/api/tts/voices", relativeTo: baseURL) else {
            throw URLError(.badURL)
        }

        let (data, _) = try await session.data(from: url)
        let decoder = JSONDecoder()
        return try decoder.decode([Voice].self, from: data)
    }

    func getAuthToken() -> String? {
        #if DEBUG || targetEnvironment(simulator)
        // Return mock token for testing/simulator, or nil if not authenticated
        return UserDefaults.standard.string(forKey: "mock_auth_token")
        #else
        // Use Keychain in production
        return keychain.get("auth_token")
        #endif
    }
}
