import Foundation
import Combine
import AVFoundation
import SocketIO

// NSURLError constants for error handling
private let NSURLErrorCancelled = -999
private let NSURLErrorTimedOut = -1001
private let NSURLErrorCannotConnectToHost = -1004
private let NSURLErrorNetworkConnectionLost = -1005
private let NSURLErrorNotConnectedToInternet = -1009

@MainActor
class WebSocketManager: ObservableObject {
    let roomCode: String
    let currentUser: AuthUser?
    let authVM: AuthViewModel
    @Published var isConnected = false
    @Published var messages: [TranslatedMessage] = []
    @Published var participants: [Participant] = []
    @Published var debugInfo = "Disconnected"
    @Published var isRecording = false
    @Published var isSpeaking = false  // VAD: currently detecting speech
    @Published var lastError: TranslationError?

    // Loading states for each pillar
    @Published var isLoadingSTT = false  // Speech-to-Text processing
    @Published var isLoadingMT = false   // Machine Translation processing
    @Published var isLoadingTTS = false  // Text-to-Speech processing

    // Performance metrics (latencies in milliseconds)
    @Published var sttLatency: Double? = nil  // STT processing time
    @Published var mtLatency: Double? = nil   // MT processing time
    @Published var ttsLatency: Double? = nil  // TTS processing time

    // Solo mode state
    @Published var soloMode = false
    @Published var soloTargetLanguage: LanguageOption?
    @Published var isPushToTalkMode = false  // Manual control vs automatic VAD

    // Computed property to check if audio monitoring is active
    var isMonitoring: Bool {
        audioEngine != nil
    }

    private var manager: SocketManager!
    private var socket: SocketIOClient!
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioPlayer: AVAudioPlayer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5

    // Performance timing
    private var sttStartTime: Date?
    private var mtStartTime: Date?
    private var ttsStartTime: Date?

    // Audio chunking (250ms at 48kHz per webapp pillars)
    private var audioBuffer: [Int16] = []
    private let targetChunkSize = Int(48000 * 0.25) // 250ms at 48kHz

    // Audio buffering for network interruptions (Phase 2 - Reliability)
    private var audioSendQueue: [Data] = []
    private let maxAudioBufferSize = 10 * 48000 // 10 seconds at 48kHz
    private var isNetworkInterrupted = false

    // Memory management
    private let maxMessages = 100  // Limit message history to prevent memory issues

    // TTS Caching (Phase 2 - Performance optimization)
    private let ttsCache = TTSCache()

    // Network monitoring (Phase 2 - Reliability)
    private let networkMonitor = NetworkMonitor()

    // VAD Configuration (mobile-optimized per webapp pillars)
    private let vadThreshold: Float = 0.01  // Amplitude threshold for speech detection
    private let silenceTimeout: TimeInterval = 10.0  // Auto-stop after 10s silence
    private let minSpeechDuration: TimeInterval = 0.3  // Minimum speech duration to count
    private var lastSpeechTime: Date?
    private var speechStartTime: Date?
    private var silenceTimer: Timer?
    
    init(currentUser: AuthUser?, roomCode: String, authVM: AuthViewModel) {
        self.currentUser = currentUser
        self.roomCode = roomCode
        self.authVM = authVM

        // Get base URL for Socket.io
        let baseURL = URL(string: "http://localhost:4003")!

        // Socket.io configuration with JWT token for mobile auth
        var config: SocketIOClientConfiguration = [
            .log(true),
            .compress,
            .reconnects(true),
            .reconnectAttempts(5),
            .reconnectWait(2)
        ]

        // Add JWT token to query parameters for mobile authentication
        if let token = authVM.getAuthToken() {
            config.insert(.connectParams(["token": token]))
        }

        self.manager = SocketManager(socketURL: baseURL, config: config)
        self.socket = manager.defaultSocket

        setupEventHandlers()
    }

    private func setupEventHandlers() {
        guard let socket = socket else { return }

        socket.on(clientEvent: .connect) { [weak self] data, ack in
            guard let self = self else { return }
            Task { @MainActor in
                self.isConnected = true
                self.isNetworkInterrupted = false
                self.debugInfo = "Connected to room \(self.roomCode)"
                self.reconnectAttempts = 0
                self.sendJoinRoom()
                // Flush any buffered audio data
                self.flushAudioBuffer()
            }
        }

        socket.on(clientEvent: .disconnect) { [weak self] data, ack in
            guard let self = self else { return }
            Task { @MainActor in
                self.isConnected = false
                self.isNetworkInterrupted = true
                self.debugInfo = "Disconnected - buffering audio"
            }
        }

        socket.on(clientEvent: .reconnect) { [weak self] data, ack in
            guard let self = self else { return }
            let attempt = data.first as? Int ?? 0
            let delay = min(pow(2.0, Double(attempt)), 30.0) // Cap at 30 seconds
            Task { @MainActor in
                self.debugInfo = "Reconnecting in \(Int(delay))s (attempt \(attempt + 1))"
            }
        }

        socket.on("joined-room") { [weak self] data, ack in
            guard let self = self else { return }
            Task { @MainActor in
                self.isConnected = true
                self.debugInfo = "Connected to room \(self.roomCode)"
                self.reconnectAttempts = 0
                if let dict = data.first as? [String: Any],
                   let parts = dict["participants"] as? [[String: Any]] {
                    self.participants = parts.compactMap { Participant(from: $0) }
                }
            }
        }

        socket.on("translated-message") { [weak self] data, ack in
            guard let self = self else { return }
            // Calculate STT latency (from start-speech to translated-message received)
            if let sttStart = self.sttStartTime {
                let sttEndTime = Date()
                let sttLatency = sttEndTime.timeIntervalSince(sttStart) * 1000 // Convert to milliseconds
                Task { @MainActor in
                    self.sttLatency = sttLatency
                    self.sttStartTime = nil // Reset for next speech session
                }
            }

            // MT processing completed (latency tracked as part of STT for now)
            Task { @MainActor in
                self.isLoadingMT = false
                self.mtLatency = self.sttLatency // For now, MT is part of the same pipeline
            }

            if let dict = data.first as? [String: Any],
               var msg = TranslatedMessage(from: dict) {
                msg.isOwn = msg.fromUserId == self.currentUser?.id
                Task { @MainActor in
                    self.messages.append(msg)

                    // Limit message history to prevent memory issues
                    if self.messages.count > self.maxMessages {
                        self.messages.removeFirst(self.messages.count - self.maxMessages)
                    }
                }

                // TTS if target lang matches user lang
                if msg.targetLang == self.currentUser?.language {
                    Task {
                        Task { @MainActor in
                            self.ttsStartTime = Date() // Record TTS start time
                            self.isLoadingTTS = true  // TTS processing started
                        }
                        do {
                            let data = try await self.synthesize(text: msg.translatedText, language: msg.targetLang)
                            self.playAudio(data)
                            // TTS latency calculated in playAudio
                            Task { @MainActor in
                                self.isLoadingTTS = false  // TTS processing completed
                            }
                        } catch {
                            Task { @MainActor in
                                self.isLoadingTTS = false  // TTS processing failed
                                self.ttsStartTime = nil // Reset on error
                            }
                            print("TTS error: \(error)")
                            Task { @MainActor in
                                self.reportError(TranslationError.ttsFailed, underlyingError: error)
                            }
                        }
                    }
                }
            }
        }

        socket.on("participant-joined") { [weak self] data, ack in
            guard let self = self else { return }
            if let dict = data.first as? [String: Any],
               let parts = dict["participants"] as? [[String: Any]] {
                Task { @MainActor in
                    self.participants = parts.compactMap { Participant(from: $0) }
                }
            }
        }

        socket.on("participant-left") { [weak self] data, ack in
            guard let self = self else { return }
            if let dict = data.first as? [String: Any],
               let parts = dict["participants"] as? [[String: Any]] {
                Task { @MainActor in
                    self.participants = parts.compactMap { Participant(from: $0) }
                }
            }
        }
    }

    deinit {
        // Cancel any ongoing operations without capturing self in async context
        socket?.disconnect()
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        audioPlayer?.stop()
        silenceTimer?.invalidate()

        // Remove audio route change observer
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
    }

    // Handle audio route changes (bluetooth, headphones) for background audio (Phase 3)
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        Task { @MainActor in
            switch reason {
            case .newDeviceAvailable:
                debugInfo = "Audio device connected (Bluetooth/Headphones)"
                print("Audio route change: New device available")
            case .oldDeviceUnavailable:
                debugInfo = "Audio device disconnected"
                print("Audio route change: Device unavailable")
            case .categoryChange:
                debugInfo = "Audio category changed"
                print("Audio route change: Category changed")
            default:
                debugInfo = "Audio route changed"
                print("Audio route change: \(reason.rawValue)")
            }
        }
    }
    
    func connect() {
        socket?.connect()
        Task { @MainActor in
            self.debugInfo = "Connecting..."
        }
    }

    
    private func reconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            Task { @MainActor in
                self.debugInfo = "Max reconnect attempts reached"
            }
            return
        }
        reconnectAttempts += 1
        // Enhanced exponential backoff with cap at 30 seconds (Phase 2 - Reliability)
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0)
        Task { @MainActor in
            self.debugInfo = "Reconnecting in \(Int(delay))s (attempt \(reconnectAttempts))"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.connect()
        }
    }
    
    func disconnect() {
        socket?.disconnect()
        stopRecording()  // Ensure cleanup
        cleanup()  // Additional cleanup
        Task { @MainActor in
            self.isConnected = false
            self.debugInfo = "Disconnected"
            self.reconnectAttempts = 0
        }
    }

    private func cleanup() {
        // Clean up audio player
        audioPlayer?.stop()
        audioPlayer = nil

        // Reset all timing variables
        sttStartTime = nil
        mtStartTime = nil
        ttsStartTime = nil

        // Reset latencies
        sttLatency = nil
        mtLatency = nil
        ttsLatency = nil

        // Clear any pending timers
        stopSilenceTimer()
    }


    
    private func sendJoinRoom() {
        let message = ["type": "join-room", "roomCode": roomCode]
        sendJSON(message)
    }
    
    private func sendJSON(_ dict: [String: Any]) {
        socket?.emit("message", dict)
    }

    func sendAudioData(_ data: Data) {
        if isNetworkInterrupted {
            // Buffer audio data during network interruptions
            audioSendQueue.append(data)
            // Limit buffer size to prevent memory issues
            if audioSendQueue.count > maxAudioBufferSize / targetChunkSize {
                audioSendQueue.removeFirst()
            }
            print("Audio buffered during network interruption. Queue size: \(audioSendQueue.count)")
        } else {
            socket?.emit("speech-data", data)
        }
    }

    // Send buffered audio when connection is restored
    private func flushAudioBuffer() {
        guard !audioSendQueue.isEmpty else { return }

        print("Flushing \(audioSendQueue.count) buffered audio chunks")
        for data in audioSendQueue {
            socket?.emit("speech-data", data)
        }
        audioSendQueue.removeAll()
    }

    // VAD: Calculate RMS amplitude from audio buffer
    private func calculateRMSAmplitude(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0.0 }
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0.0

        for i in 0..<frameLength {
            sum += channelData[i] * channelData[i]
        }

        return sqrt(sum / Float(frameLength))
    }

    // VAD: Handle speech detection
    private func handleSpeechDetection(amplitude: Float) {
        let now = Date()
        let isAboveThreshold = amplitude > vadThreshold

        if isAboveThreshold {
            // Speech detected
            lastSpeechTime = now
            if !isSpeaking {
                // Speech started
                speechStartTime = now
                DispatchQueue.main.async {
                    self.isSpeaking = true
                    self.debugInfo = "Speaking... (VAD)"
                }
                print("VAD: Speech started (amp: \(amplitude))")
            }
        } else if isSpeaking {
            // Check if silence timeout exceeded
            if let lastSpeech = lastSpeechTime,
                now.timeIntervalSince(lastSpeech) > silenceTimeout {
                // Silence timeout - stop speaking
                stopSpeaking()
            }
        }
    }

    // VAD: Stop speaking and recording
    private func stopSpeaking() {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.speechStartTime = nil
            self.lastSpeechTime = nil
            self.stopSilenceTimer()

            if !self.isPushToTalkMode {
                // Auto-stop recording in VAD mode
                self.stopRecording()
                self.debugInfo = "Auto-stopped (silence)"
                print("VAD: Auto-stopped due to silence")
            }
        }
    }

    // VAD: Start silence timer for minimum speech duration
    private func startSilenceTimer() {
        stopSilenceTimer()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: minSpeechDuration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            // Schedule on main actor without capturing self in the Task initializer
            DispatchQueue.main.async {
                self.handleSilenceTimeout()
            }
        }
    }

    // VAD: Handle silence timeout
    private func handleSilenceTimeout() {
        if let speechStart = speechStartTime,
            Date().timeIntervalSince(speechStart) >= minSpeechDuration {
            // Minimum speech duration met, start recording
            if !isRecording {
                startRecordingInternal()
            }
        }
    }

    // VAD: Stop silence timer
    private func stopSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = nil
    }

    // Error reporting (webapp-style)
    private func reportError(_ error: TranslationError, underlyingError: Error? = nil) {
        lastError = error

        var errorMessage = error.userMessage
        if let nsError = underlyingError as? NSError {
            errorMessage = "\(error.userMessage) (Code: \(nsError.code))"
        }
        debugInfo = "Error: \(errorMessage)"

        // Log detailed error for debugging
        let details = underlyingError?.localizedDescription ?? "No additional details"
        print("[\(error.rawValue)] \(error.debugDescription): \(details)")

        if let nsError = underlyingError as? NSError {
            print("NSURLError Domain: \(nsError.domain), Code: \(nsError.code)")
        }

        // Send error to server for telemetry (if connected)
        sendClientError(error, details: details)
    }

    private func sendClientError(_ error: TranslationError, details: String) {
        let errorData = [
            "type": "client-error",
            "code": error.rawValue,
            "message": error.debugDescription,
            "details": details,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ] as [String: Any]

        sendJSON(errorData)
    }

    private func clearError() {
        lastError = nil
    }

    func startRecording() {
        if isPushToTalkMode {
            // Push-to-talk: start immediately
            startRecordingInternal()
        } else {
            // VAD mode: start audio engine for monitoring, but don't send speech yet
            startAudioMonitoring()
        }
    }

    // Internal method to actually start recording and sending audio
    private func startRecordingInternal() {
        guard !isRecording else { return }

        if audioEngine == nil {
            // Start audio engine if not already running
            startAudioMonitoring()
        }

        sendStartSpeech()
        DispatchQueue.main.async {
            self.isRecording = true
            self.isLoadingSTT = true  // STT processing started
            self.isLoadingMT = true   // MT processing will start once STT provides text
            self.debugInfo = self.isPushToTalkMode ? "Recording (PTT)" : "Recording (VAD)"
            print("Started recording (mode: \(self.isPushToTalkMode ? "PTT" : "VAD"))")
        }
    }

    // Start audio monitoring (always needed for both VAD and PTT)
    private func startAudioMonitoring() {
        guard audioEngine == nil else { return }

        // Configure audio session for recording with background audio support (Phase 3)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Enable background audio mode for continuous translation
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.duckOthers, .allowBluetooth])
            try audioSession.setActive(true)

            // Handle route changes (bluetooth, headphones) for background audio
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleRouteChange),
                name: AVAudioSession.routeChangeNotification,
                object: nil
            )

            print("Audio session configured with background audio support")
        } catch {
            print("Failed to configure audio session: \(error)")
            reportError(TranslationError.recordingStartFailed, underlyingError: error)
            return
        }

        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode

        // Check if input node is available
        guard let audioInputNode = inputNode else {
            print("No input node available - microphone access may be denied")
            reportError(TranslationError.recordingStartFailed, underlyingError: NSError(domain: "Audio", code: -1, userInfo: [NSLocalizedDescriptionKey: "Microphone not available"]))
            return
        }

        // Start the audio engine first to ensure the input node is properly initialized
        do {
            try audioEngine?.start()
        } catch {
            print("Audio engine start failed: \(error)")
            reportError(TranslationError.recordingStartFailed, underlyingError: error)
            return
        }

        // Now get the format after the engine is started
        let outputFormat = audioInputNode.outputFormat(forBus: 0)

        print("Output format: \(outputFormat)")

        // CRITICAL FIX: Validate the format - ensure we have valid sample rate and channels
        // This prevents the crash: "required condition is false: IsFormatSampleRateAndChannelCountValid(format)"
        guard outputFormat.sampleRate > 0 && outputFormat.channelCount > 0 else {
            print("CRITICAL: Invalid audio format - sampleRate: \(outputFormat.sampleRate), channels: \(outputFormat.channelCount)")
            print("This usually means the microphone is not available or audio session is not properly configured")

            // Clean up and report error
            audioEngine?.stop()
            audioEngine = nil
            self.inputNode = nil

            reportError(TranslationError.recordingStartFailed, underlyingError: NSError(
                domain: "Audio",
                code: -3,
                userInfo: [
                    NSLocalizedDescriptionKey: "Invalid audio format. Please check microphone permissions and ensure no other app is using the microphone.",
                    "sampleRate": outputFormat.sampleRate,
                    "channelCount": outputFormat.channelCount
                ]
            ))
            return
        }

        // Install tap with nil format to get the native format
        audioInputNode.installTap(onBus: 0, bufferSize: 2048, format: nil) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.processAudioBuffer(buffer)
        }

        DispatchQueue.main.async {
            self.clearError()
            self.debugInfo = "Audio monitoring started"
            print("Audio monitoring started with format: \(outputFormat)")
        }
    }

    // Process audio buffer with chunking (250ms intervals per webapp pillars)
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Calculate amplitude for VAD
        let amplitude = self.calculateRMSAmplitude(from: buffer)
        self.handleSpeechDetection(amplitude: amplitude)

        // Only process audio data if actually recording
        if self.isRecording {
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)

            // Convert Float32 samples to Int16 and accumulate in buffer
            for i in 0..<frameLength {
                let sample = Int16(max(-1.0, min(1.0, channelData[i])) * 32767.0)
                audioBuffer.append(sample)
            }

            // Send chunks when we have enough data (250ms worth)
            while audioBuffer.count >= targetChunkSize {
                let chunk = Array(audioBuffer.prefix(Int(targetChunkSize)))
                let data = Data(bytes: chunk, count: chunk.count * 2) // 2 bytes per Int16
                sendAudioData(data)
                audioBuffer.removeFirst(Int(targetChunkSize))
            }
        }
    }

    func stopRecording() {
        if isPushToTalkMode {
            // Push-to-talk: stop everything
            stopRecordingInternal()
        } else {
            // VAD mode: just stop sending audio, keep monitoring
            if isRecording {
                sendJSON(["type": "stop-speech"])
                DispatchQueue.main.async {
                    self.isRecording = false
                    self.isLoadingSTT = false  // STT processing stopped
                    self.isLoadingMT = false   // MT processing stopped
                    self.debugInfo = "Monitoring (VAD)"
                    print("Stopped recording, continuing VAD monitoring")
                }
            }
        }
    }

    // Internal method to completely stop audio monitoring
    private func stopRecordingInternal() {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        audioEngine = nil
        inputNode = nil

        // Clear any remaining audio buffer
        audioBuffer.removeAll()

        sendJSON(["type": "stop-speech"])
        DispatchQueue.main.async {
            self.isRecording = false
            self.isLoadingSTT = false  // STT processing stopped
            self.isLoadingMT = false   // MT processing stopped
            self.isSpeaking = false
            self.speechStartTime = nil
            self.lastSpeechTime = nil
            self.stopSilenceTimer()

            self.debugInfo = "Stopped"
            print("Completely stopped recording and monitoring")
        }
    }

    private func sendStartSpeech() {
        // Record STT start time for latency measurement
        sttStartTime = Date()

        var config: [String: Any] = [
            "type": "start-speech",
            "languageCode": currentUser?.language ?? "en",
            "encoding": "LINEAR16",
            "sampleRateHertz": 48000
        ]

        // Add solo mode parameters if enabled
        if soloMode, let targetLang = soloTargetLanguage?.code {
            config["soloMode"] = true
            config["soloTargetLang"] = targetLang
        }

        sendJSON(config)
    }

    func synthesize(text: String, language: String) async throws -> Data {
        // Check cache first (Phase 2 - Performance optimization)
        if let cachedData = ttsCache.getAudio(for: text, language: language) {
            return cachedData
        }

        // Cache miss - fetch from API
        let repo = ApiRepository()
        let request = TtsRequest(text: text, languageCode: language, voiceName: nil, ssmlGender: nil)
        let data = try await repo.tts(request: request)

        // Cache the result for future use
        ttsCache.setAudio(data, for: text, language: language)

        return data
    }

    func playAudio(_ data: Data) {
        audioPlayer = try? AVAudioPlayer(data: data)

        // Calculate TTS latency (from TTS request start to audio playback start)
        if let ttsStart = ttsStartTime {
            let ttsEndTime = Date()
            ttsLatency = ttsEndTime.timeIntervalSince(ttsStart) * 1000 // Convert to milliseconds
            ttsStartTime = nil // Reset for next TTS request
        }

        audioPlayer?.play()
    }


}

extension Participant {
    init?(from dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let name = dict["name"] as? String,
              let language = dict["language"] as? String else { return nil }
        self.id = id
        self.name = name
        self.language = language
    }
}

extension TranslatedMessage {
    init?(from dict: [String: Any]) {
        guard let original = dict["originalText"] as? String,
              let translated = dict["translatedText"] as? String,
              let source = dict["sourceLang"] as? String,
              let target = dict["targetLang"] as? String,
              let fromId = dict["fromUserId"] as? String,
              let toId = dict["toUserId"] as? String,
              let speaker = dict["speakerName"] as? String else { return nil }
        self.originalText = original
        self.translatedText = translated
        self.sourceLang = source
        self.targetLang = target
        self.fromUserId = fromId
        self.toUserId = toId
        self.speakerName = speaker
        // isOwn can be set later based on current user
    }
}