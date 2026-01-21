import SwiftUI
import UIKit

struct ControlsView: View {
    let roomCode: String
    @Binding var messages: [TranslatedMessage]
    @StateObject var wsManager: WebSocketManager
    @ObservedObject var authVM: AuthViewModel
    @State private var selectedLanguage: LanguageOption = LANGUAGES[0]
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseTimer: Timer?
    @State private var feedbackGenerator: UIImpactFeedbackGenerator? = {
        #if targetEnvironment(simulator)
        return nil // Disable haptics in simulator to avoid pattern library errors
        #else
        return UIImpactFeedbackGenerator(style: .medium)
        #endif
    }()
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Picker("Language", selection: $selectedLanguage) {
                    ForEach(LANGUAGES) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedLanguage) { _, newValue in
                    wsManager.soloTargetLanguage = newValue
                    // Update user language preference
                    Task {
                        do {
                            try await authVM.updateMe(displayName: nil, language: newValue.code, preferences: nil)
                        } catch {
                            print("Failed to update user language: \(error)")
                            // Error is already reported by AuthViewModel
                        }
                    }
                }

                Toggle("Solo Mode", isOn: $wsManager.soloMode)

                Toggle("Push-to-Talk", isOn: $wsManager.isPushToTalkMode)
            }

            HStack(spacing: 16) {
                // Pillar loading indicators
                HStack(spacing: 8) {
                    if wsManager.isLoadingSTT {
                        HStack(spacing: 2) {
                            ProgressView()
                                .scaleEffect(0.5)
                            Text("STT")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                    if wsManager.isLoadingMT {
                        HStack(spacing: 2) {
                            ProgressView()
                                .scaleEffect(0.5)
                            Text("MT")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    if wsManager.isLoadingTTS {
                        HStack(spacing: 2) {
                            ProgressView()
                                .scaleEffect(0.5)
                            Text("TTS")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                }

                Spacer()

                // Recording status indicator
                if wsManager.isSpeaking && !wsManager.isPushToTalkMode {
                    Text("🎤 Speaking...")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else if wsManager.isRecording {
                    Text(wsManager.isPushToTalkMode ? "🎙️ Recording (PTT)" : "🎙️ Recording (VAD)")
                        .foregroundStyle(.red)
                        .font(.caption)
                } else if !wsManager.isPushToTalkMode {
                    Text("👂 Listening (VAD)")
                        .foregroundStyle(.blue)
                        .font(.caption)
                }

                ZStack {
                    // Invisible button for tap-to-toggle in VAD mode
                    if !wsManager.isPushToTalkMode {
                        Button(action: {
                            // VAD mode: toggle monitoring
                            if wsManager.isMonitoring {
                                wsManager.stopRecording()  // This stops monitoring in VAD mode
                                stopPulsing()
                                pulseScale = 1.0
                            } else {
                                wsManager.startRecording()  // This starts monitoring
                            }
                        }) {
                            Color.clear
                                .frame(width: 60, height: 60)
                        }
                        .buttonStyle(.plain)
                    }

                    // Main mic button with gesture support
                    Image(systemName: getMicIcon())
                        .font(.largeTitle)
                        .foregroundStyle(getMicColor())
                        .scaleEffect(pulseScale)
                        .simultaneousGesture(
                            wsManager.isPushToTalkMode ?
                            LongPressGesture(minimumDuration: 0.05)
                                .onChanged { isPressing in
                                    if isPressing {
                                        if !wsManager.isRecording {
                                            feedbackGenerator?.impactOccurred() // Haptic feedback (Phase 3)
                                            wsManager.startRecording()
                                            startPulsing()
                                        }
                                    } else {
                                        if wsManager.isRecording {
                                            feedbackGenerator?.impactOccurred() // Haptic feedback (Phase 3)
                                            wsManager.stopRecording()
                                            stopPulsing()
                                            pulseScale = 1.0
                                        }
                                    }
                                } : nil
                        )
                }
                .frame(width: 60, height: 60)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .onAppear {
            // Initialize selected language to user's language
            if let userLang = wsManager.currentUser?.language,
               let langOption = LANGUAGES.first(where: { $0.code == userLang }) {
                selectedLanguage = langOption
                wsManager.soloTargetLanguage = langOption
            }
        }
    }

    private func getMicIcon() -> String {
        if wsManager.isPushToTalkMode {
            return wsManager.isRecording ? "stop.circle.fill" : "mic.circle.fill"
        } else {
            // VAD mode
            if wsManager.isMonitoring {
                return wsManager.isRecording ? "mic.circle.fill" : "ear.fill"
            } else {
                return "ear"
            }
        }
    }

    private func getMicColor() -> Color {
        if wsManager.isPushToTalkMode {
            return wsManager.isRecording ? .red : .blue
        } else {
            // VAD mode
            if wsManager.isRecording {
                return .red
            } else if wsManager.isMonitoring {
                return .orange  // Monitoring but not recording
            } else {
                return .blue
            }
        }
    }
    
    private func startPulsing() {
        pulseTimer?.invalidate()
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                pulseScale = pulseScale == 1.0 ? 1.1 : 1.0
            }
        }
    }
    
    private func stopPulsing() {
        pulseTimer?.invalidate()
        pulseTimer = nil
    }
}

#Preview {
    let authVM = AuthViewModel()
    let wsManager = WebSocketManager(currentUser: nil, roomCode: "ABC123", authVM: authVM)
    ControlsView(roomCode: "ABC123", messages: .constant([]), wsManager: wsManager, authVM: authVM)
}