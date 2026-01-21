import SwiftUI

struct ProfileView: View {
    let user: AuthUser
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var displayName: String
    @State private var selectedLanguage: LanguageOption
    @State private var sttEngine: String = ""
    @State private var ttsEngine: String = ""
    @State private var translationEngine: String = ""

    init(user: AuthUser) {
        self.user = user
        _displayName = State(initialValue: user.displayName ?? user.name)
        _selectedLanguage = State(initialValue: LANGUAGES.first { $0.code == user.language } ?? LANGUAGES[0])
        if let prefs = user.preferences {
            _sttEngine = State(initialValue: prefs.sttEngine ?? "")
            _ttsEngine = State(initialValue: prefs.ttsEngine ?? "")
            _translationEngine = State(initialValue: prefs.translationEngine ?? "")
        }
    }

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Display Name", text: $displayName)
                Picker("Language", selection: $selectedLanguage) {
                    ForEach(LANGUAGES) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
            }

            Section("Preferences") {
                TextField("STT Engine", text: $sttEngine)
                TextField("TTS Engine", text: $ttsEngine)
                TextField("Translation Engine", text: $translationEngine)
            }

            Section {
                Button("Save") {
                    Task {
                        do {
                            let prefs = UserPreferences(
                                sttEngine: sttEngine.isEmpty ? nil : sttEngine,
                                ttsEngine: ttsEngine.isEmpty ? nil : ttsEngine,
                                translationEngine: translationEngine.isEmpty ? nil : translationEngine
                            )
                            try await authVM.updateMe(
                                displayName: displayName,
                                language: selectedLanguage.code,
                                preferences: prefs
                            )
                            // Success, currentUser updated
                        } catch {
                            // Ignore cancellation errors (e.g., during logout)
                            if (error as? URLError)?.code != .cancelled {
                                authVM.errorMessage = error.localizedDescription
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            Section {
                Button("Logout", role: .destructive) {
                    authVM.logout()
                }
            }
        }
        .navigationTitle("Profile")
        .alert("Error", isPresented: .constant(authVM.errorMessage != nil), actions: {
            Button("OK") { authVM.errorMessage = nil }
        }, message: {
            Text(authVM.errorMessage ?? "")
        })
    }
}

#Preview {
    NavigationStack {
        ProfileView(user: AuthUser(
            id: "",
            name: "Test",
            email: "",
            displayName: "Test User",
            language: "en",
            isGuest: false,
            preferences: UserPreferences(sttEngine: "google", ttsEngine: "google", translationEngine: "google")
        ))
        .environmentObject(AuthViewModel())
    }
}