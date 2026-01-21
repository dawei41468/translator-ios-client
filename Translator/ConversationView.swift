import SwiftUI
import AVFoundation

struct ConversationView: View {
    let roomCode: String
    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var wsManager: WebSocketManager
    
    init(roomCode: String, authVM: AuthViewModel) {
        self.roomCode = roomCode
        _wsManager = StateObject(wrappedValue: WebSocketManager(currentUser: authVM.currentUser, roomCode: roomCode, authVM: authVM))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            RoomHeaderView(participants: wsManager.participants, roomCode: roomCode)
            
            MessageListView(messages: $wsManager.messages)
            
            ControlsView(roomCode: roomCode, messages: $wsManager.messages, wsManager: wsManager, authVM: authVM)
            
            DebugView(
                info: wsManager.debugInfo,
                isConnected: wsManager.isConnected,
                lastError: wsManager.lastError,
                isLoadingSTT: wsManager.isLoadingSTT,
                isLoadingMT: wsManager.isLoadingMT,
                isLoadingTTS: wsManager.isLoadingTTS,
                sttLatency: wsManager.sttLatency,
                mtLatency: wsManager.mtLatency,
                ttsLatency: wsManager.ttsLatency,
                isRecording: wsManager.isRecording,
                isMonitoring: wsManager.isMonitoring,
                messageCount: wsManager.messages.count,
                isPushToTalkMode: wsManager.isPushToTalkMode,
                cacheHitRate: nil, // TODO: Integrate with TTSCache
                availableSttEngines: 1, // Default Google Cloud
                availableTtsEngines: 1, // Default Google Cloud
                preloadedVoicesCount: 0, // TODO: Integrate with VoicePreloader
                isVoicePreloading: false, // TODO: Integrate with VoicePreloader
                voicePreloadProgress: 0.0, // TODO: Integrate with VoicePreloader
                networkType: nil, // TODO: Integrate with NetworkMonitor
                audioBufferSize: 0, // TODO: Add to WebSocketManager
                reconnectionAttempts: 0, // TODO: Add to WebSocketManager
                socketEventCount: 0 // TODO: Add to WebSocketManager
            )
        }
        .navigationTitle("Room \(roomCode)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            wsManager.connect()
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    // Handle permission if needed
                }
            }
        }
        .onDisappear {
            wsManager.disconnect()
        }
    }
}

#Preview {
    NavigationStack {
        ConversationView(roomCode: "ABC123", authVM: AuthViewModel())
            .environmentObject(AuthViewModel())
    }
}