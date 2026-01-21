import Foundation

actor ApiRepository {
    private let session: URLSession
    private let baseURL: URL
    
    init(baseURLString: String = "http://localhost:4003") {
        guard let url = URL(string: baseURLString) else {
            fatalError("Invalid baseURL")
        }
        self.baseURL = url
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = .shared  // Persist auth_token
        self.session = URLSession(configuration: config)
    }
    
    func me() async throws -> AuthUser? {
        guard let url = URL(string: "/api/me", relativeTo: baseURL) else { throw URLError(.badURL) }
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(AuthResponse.self, from: data)
        return response.user
    }
    
    func login(email: String, password: String) async throws -> AuthUser {
        try await request("/api/auth/login", body: LoginRequest(email: email, password: password))
    }
    
    func register(email: String, password: String, name: String) async throws -> AuthUser {
        try await request("/api/auth/register", body: RegisterRequest(email: email, password: password, name: name))
    }
    
    func guest(displayName: String) async throws -> AuthUser {
        try await request("/api/auth/guest-login", body: GuestRequest(displayName: displayName))
    }
    
    func updateMe(displayName: String?, language: String?, preferences: UserPreferences?) async throws {
        let req = UpdateMeRequest(displayName: displayName, language: language, preferences: preferences)
        _ = try await request("/api/me", body: req, as: AuthResponse.self)
    }
    
    func createRoom() async throws -> RoomResponse {
        try await request("/api/rooms", as: RoomResponse.self)
    }
    
    func joinRoom(code: String) async throws -> RoomResponse {
        guard let url = URL(string: "/api/rooms/join/\(code)", relativeTo: baseURL) else {
            throw URLError(.badURL)
        }
        return try await request(url, as: RoomResponse.self)
    }
    
    func getRoom(code: String) async throws -> RoomInfo {
        guard let url = URL(string: "/api/rooms/\(code)", relativeTo: baseURL) else {
            throw URLError(.badURL)
        }
        return try await request(url)
    }
    
    func synthesizeTts(_ request: TtsRequest) async throws -> Data {
        guard let url = URL(string: "/api/tts/synthesize", relativeTo: baseURL) else {
            throw URLError(.badURL)
        }
        return try await request(url, body: request, asData: true)
    }
    
    // Private helpers
    private func request<T: Decodable>(_ path: String, body: Codable? = nil, as: T.Type = AuthUser.self) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw URLError(.badURL) }
        return try await request(url, body: body, as: as)
    }
    
    private func request<T: Decodable>(_ url: URL, body: Codable? = nil, as: T.Type = AuthUser.self) async throws -> T {
        var req = URLRequest(url: url)
        req.httpMethod = body != nil ? "POST" : "GET"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { req.httpBody = try JSONEncoder().encode(body) }
        
        let (data, _) = try await session.data(for: req)
        return try JSONDecoder().decode(as, from: data)
    }
    
    private func request(_ url: URL, body: Codable, asData: Bool) async throws -> Data {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await session.data(for: req)
        return data
    }
}
