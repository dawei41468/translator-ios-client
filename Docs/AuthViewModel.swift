import Observation
import SwiftUI

@Observable
class AuthViewModel {
    var currentUser: AuthUser?
    var errorMessage: String?
    var isLoading = false
    
    private let repo = ApiRepository()
    
    func checkAuth() async {
        isLoading = true
        do {
            currentUser = try await repo.me()
        } catch {
            currentUser = nil
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func login(email: String, password: String) async throws -> AuthUser {
        isLoading = true
        defer { isLoading = false }
        return try await repo.login(email: email, password: password)
    }
    
    // Similar for register/guest...
    func guest(displayName: String) async throws -> AuthUser {
        isLoading = true
        defer { isLoading = false }
        return try await repo.guest(displayName: displayName)
    }
}
