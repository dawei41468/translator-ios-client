import Combine
import SwiftUI
import KeychainSwift

class AuthViewModel: ObservableObject {
    @Published var currentUser: AuthUser?
    @Published var errorMessage: String?
    @Published var lastError: TranslationError?
    @Published var isLoading = false

    private let repo = ApiRepository()
    private let keychain = KeychainSwift()
    private let tokenKey = "auth_token"
    private let biometricAuth = BiometricAuth() // Biometric authentication (Phase 3)

    private func reportError(_ error: TranslationError, underlyingError: Error? = nil) {
        lastError = error
        errorMessage = error.userMessage

        // Log detailed error for debugging
        let details = underlyingError?.localizedDescription ?? "No additional details"
        print("[\(error.rawValue)] \(error.debugDescription): \(details)")
    }

    private func clearError() {
        lastError = nil
        errorMessage = nil
    }

    func checkAuth() async {
        isLoading = true
        do {
            currentUser = try await repo.me()
            clearError()
        } catch {
            currentUser = nil
            // Ignore cancellation errors from session cleanup
            if (error as? URLError)?.code != .cancelled {
                reportError(.authError, underlyingError: error)
            }
        }
        isLoading = false
    }
    
    func login(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await repo.login(email: email, password: password)
            currentUser = response.user
            keychain.set(response.token, forKey: tokenKey)
            clearError()
        } catch {
            reportError(.authError, underlyingError: error)
            throw error
        }
    }

    func register(email: String, password: String, name: String) async throws {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await repo.register(email: email, password: password, name: name)
            currentUser = response.user
            keychain.set(response.token, forKey: tokenKey)
            clearError()
        } catch {
            reportError(.authError, underlyingError: error)
            throw error
        }
    }

    func guest(displayName: String) async throws {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await repo.guest(displayName: displayName)
            currentUser = response.user
            keychain.set(response.token, forKey: tokenKey)
            clearError()
        } catch {
            reportError(.authError, underlyingError: error)
            throw error
        }
    }

    func updateMe(displayName: String?, language: String?, preferences: UserPreferences?) async throws {
        isLoading = true
        defer { isLoading = false }
        do {
            let request = UpdateMeRequest(displayName: displayName, language: language, preferences: preferences)
            currentUser = try await repo.updateMe(request: request)
            clearError()
        } catch {
            reportError(.clientError, underlyingError: error)
            throw error
        }
    }

    func logout() {
        errorMessage = nil  // Clear first to prevent stale errors
        currentUser = nil
        // Clear token from Keychain
        keychain.delete(tokenKey)
        // Clear cookies to fully logout
        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
    }

    func getAuthToken() -> String? {
        return keychain.get(tokenKey)
    }

    // Biometric authentication methods (Phase 3)
    func canUseBiometrics() -> Bool {
        return biometricAuth.canUseBiometrics()
    }

    func biometricType() -> BiometricAuth.BiometricType {
        return biometricAuth.biometricType()
    }

    func authenticateWithBiometrics() async -> Bool {
        return await biometricAuth.authenticateUser(reason: "Authenticate to access your translator account")
    }
}
