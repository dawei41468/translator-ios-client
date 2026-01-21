import SwiftUI

struct DebugView: View {
    let info: String
    let isConnected: Bool
    let lastError: TranslationError?
    let isLoadingSTT: Bool
    let isLoadingMT: Bool
    let isLoadingTTS: Bool
    let sttLatency: Double?
    let mtLatency: Double?
    let ttsLatency: Double?
    let isRecording: Bool
    let isMonitoring: Bool
    let messageCount: Int
    let isPushToTalkMode: Bool

    // Enhanced metrics (Phase 4)
    let cacheHitRate: Double?
    let availableSttEngines: Int
    let availableTtsEngines: Int
    let preloadedVoicesCount: Int
    let isVoicePreloading: Bool
    let voicePreloadProgress: Double
    let networkType: String?
    let audioBufferSize: Int
    let reconnectionAttempts: Int
    let socketEventCount: Int

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Circle()
                    .fill(isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text(info)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            // Pillar status indicators
            HStack(spacing: 12) {
                pillarStatus("STT", isActive: isLoadingSTT, color: .blue)
                pillarStatus("MT", isActive: isLoadingMT, color: .orange)
                pillarStatus("TTS", isActive: isLoadingTTS, color: .green)
                Spacer()
            }

            // Performance metrics
            HStack(spacing: 12) {
                if let latency = sttLatency {
                    latencyDisplay("STT", latency: latency, color: .blue)
                }
                if let latency = mtLatency {
                    latencyDisplay("MT", latency: latency, color: .orange)
                }
                if let latency = ttsLatency {
                    latencyDisplay("TTS", latency: latency, color: .green)
                }
                Spacer()
            }

            // Enhanced status information
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    statusIndicator("Mode", value: isPushToTalkMode ? "PTT" : "VAD", color: isPushToTalkMode ? .purple : .blue)
                    statusIndicator("Audio", value: isRecording ? "REC" : (isMonitoring ? "MON" : "OFF"), color: isRecording ? .red : (isMonitoring ? .orange : .gray))
                    statusIndicator("Msgs", value: "\(messageCount)", color: .secondary)
                    Spacer()
                }

                // Engine status (Phase 4)
                HStack(spacing: 8) {
                    statusIndicator("STT Engines", value: "\(availableSttEngines)", color: availableSttEngines > 0 ? .green : .red)
                    statusIndicator("TTS Engines", value: "\(availableTtsEngines)", color: availableTtsEngines > 0 ? .green : .red)
                    if let cacheHitRate = cacheHitRate {
                        statusIndicator("Cache Hit", value: String(format: "%.1f%%", cacheHitRate * 100), color: cacheHitRate > 0.5 ? .green : .orange)
                    }
                    Spacer()
                }

                // Voice and network status (Phase 4)
                HStack(spacing: 8) {
                    if isVoicePreloading {
                        statusIndicator("Preloading", value: String(format: "%.0f%%", voicePreloadProgress * 100), color: .blue)
                    } else {
                        statusIndicator("Voices", value: "\(preloadedVoicesCount)", color: preloadedVoicesCount > 0 ? .green : .gray)
                    }
                    if let networkType = networkType {
                        statusIndicator("Network", value: networkType, color: .blue)
                    }
                    statusIndicator("Buffer", value: "\(audioBufferSize)", color: audioBufferSize > 0 ? .orange : .gray)
                    Spacer()
                }

                // Connection metrics (Phase 4)
                HStack(spacing: 8) {
                    statusIndicator("Reconnects", value: "\(reconnectionAttempts)", color: reconnectionAttempts > 0 ? .orange : .green)
                    statusIndicator("Events", value: "\(socketEventCount)", color: .secondary)
                    Spacer()
                }
            }

            if let error = lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)

                    Text(error.userMessage)
                        .font(.caption2)
                        .foregroundStyle(.orange)

                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
    }

    private func pillarStatus(_ name: String, isActive: Bool, color: Color) -> some View {
        HStack(spacing: 2) {
            Circle()
                .fill(isActive ? color : Color.gray.opacity(0.3))
                .frame(width: 6, height: 6)
            Text(name)
                .font(.caption2)
                .foregroundStyle(isActive ? color : .secondary)
        }
    }

    private func latencyDisplay(_ name: String, latency: Double, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(name)
                .font(.caption2)
                .foregroundStyle(color)
            Text(String(format: "%.0fms", latency))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func statusIndicator(_ label: String, value: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2)
                .foregroundStyle(color)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(color.opacity(0.1))
                .cornerRadius(4)
        }
    }
}

#Preview {
    VStack {
        DebugView(
            info: "Connected to room ABC123",
            isConnected: true,
            lastError: nil,
            isLoadingSTT: true,
            isLoadingMT: false,
            isLoadingTTS: false,
            sttLatency: 1200,
            mtLatency: nil,
            ttsLatency: nil,
            isRecording: true,
            isMonitoring: true,
            messageCount: 5,
            isPushToTalkMode: false,
            cacheHitRate: 0.75,
            availableSttEngines: 1,
            availableTtsEngines: 1,
            preloadedVoicesCount: 3,
            isVoicePreloading: false,
            voicePreloadProgress: 0.0,
            networkType: "WiFi",
            audioBufferSize: 2,
            reconnectionAttempts: 0,
            socketEventCount: 45
        )
        DebugView(
            info: "Connection lost",
            isConnected: false,
            lastError: .networkError,
            isLoadingSTT: false,
            isLoadingMT: false,
            isLoadingTTS: false,
            sttLatency: nil,
            mtLatency: nil,
            ttsLatency: nil,
            isRecording: false,
            isMonitoring: false,
            messageCount: 0,
            isPushToTalkMode: true,
            cacheHitRate: nil,
            availableSttEngines: 0,
            availableTtsEngines: 0,
            preloadedVoicesCount: 0,
            isVoicePreloading: false,
            voicePreloadProgress: 0.0,
            networkType: nil,
            audioBufferSize: 0,
            reconnectionAttempts: 2,
            socketEventCount: 0
        )
        DebugView(
            info: "Processing with enhanced metrics",
            isConnected: true,
            lastError: nil,
            isLoadingSTT: true,
            isLoadingMT: true,
            isLoadingTTS: true,
            sttLatency: 850,
            mtLatency: 850,
            ttsLatency: 300,
            isRecording: true,
            isMonitoring: true,
            messageCount: 12,
            isPushToTalkMode: false,
            cacheHitRate: 0.85,
            availableSttEngines: 1,
            availableTtsEngines: 1,
            preloadedVoicesCount: 8,
            isVoicePreloading: true,
            voicePreloadProgress: 0.6,
            networkType: "Cellular",
            audioBufferSize: 5,
            reconnectionAttempts: 1,
            socketEventCount: 127
        )
    }
}