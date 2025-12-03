//
//  AppCoordinator.swift
//  WhisperType
//
//  Central coordinator that manages the app lifecycle and orchestrates
//  the main workflow: hotkey → record → transcribe → inject text.
//

import Foundation
import SwiftUI
import AppKit

// MARK: - App State

enum AppState: Equatable {
    case idle
    case loading(message: String)
    case ready
    case recording
    case processing
    case error(message: String)
    
    var statusText: String {
        switch self {
        case .idle:
            return "Idle"
        case .loading(let message):
            return message
        case .ready:
            return "Ready"
        case .recording:
            return "Recording..."
        case .processing:
            return "Processing..."
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}

// MARK: - Notification Message

struct NotificationMessage: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let type: NotificationType
    let timestamp: Date
    
    enum NotificationType {
        case info
        case success
        case warning
        case error
        
        var iconName: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }
    }
    
    static func == (lhs: NotificationMessage, rhs: NotificationMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - App Coordinator

@MainActor
class AppCoordinator: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = AppCoordinator()
    
    // MARK: - Published Properties
    
    @Published private(set) var state: AppState = .idle
    @Published private(set) var isRecording = false
    @Published private(set) var isProcessing = false
    @Published private(set) var notification: NotificationMessage?
    @Published private(set) var lastTranscription: String?
    
    // MARK: - Managers (lazily initialized)
    
    private(set) var modelManager: ModelManager!
    private(set) var hotkeyManager: HotkeyManager!
    private(set) var audioRecorder: AudioRecorder!
    private(set) var whisperWrapper: WhisperWrapper!
    private(set) var textInjector: TextInjector!
    private(set) var settings: AppSettings!
    
    // MARK: - Audio Feedback
    
    private var recordStartSound: NSSound?
    private var recordStopSound: NSSound?
    private var successSound: NSSound?
    private var errorSound: NSSound?
    
    // MARK: - Recording Overlay
    
    private var recordingOverlay: RecordingOverlayWindow?
    private var audioLevelUpdateTimer: Timer?
    
    // MARK: - Notification Auto-Dismiss Timer
    
    private var notificationDismissTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    private init() {
        print("AppCoordinator: Initializing...")
    }
    
    // MARK: - Lifecycle
    
    /// Start the app coordinator and initialize all managers
    func start() async {
        print("AppCoordinator: Starting app components...")
        state = .loading(message: "Initializing...")
        
        // Initialize managers (singletons)
        initializeManagers()
        
        // Set up audio feedback sounds
        setupAudioFeedback()
        
        // Set up recording overlay
        setupRecordingOverlay()
        
        // Set up hotkey callbacks
        setupHotkeyManager()
        
        // Set up notifications
        setupNotifications()
        
        // Load the active model in background
        await loadActiveModelInBackground()
        
        print("AppCoordinator: All components started")
    }
    
    /// Clean up resources when app terminates
    func cleanup() {
        print("AppCoordinator: Cleaning up...")
        
        // Cancel any recording in progress
        if isRecording {
            audioRecorder.cancelRecording()
        }
        
        // Clean up recording overlay
        hideRecordingOverlay()
        recordingOverlay?.cleanup()
        recordingOverlay = nil
        
        // Unregister hotkeys
        hotkeyManager.unregisterHotkey()
        
        // Unload whisper model to free memory
        whisperWrapper.unloadModel()
        
        print("AppCoordinator: Cleanup complete")
    }
    
    // MARK: - Manager Initialization
    
    private func initializeManagers() {
        print("AppCoordinator: Initializing managers...")
        
        settings = AppSettings.shared
        modelManager = ModelManager.shared
        hotkeyManager = HotkeyManager.shared
        audioRecorder = AudioRecorder.shared
        whisperWrapper = WhisperWrapper.shared
        textInjector = TextInjector.shared
        
        print("AppCoordinator: Managers initialized")
    }
    
    // MARK: - Audio Feedback Setup
    
    private func setupAudioFeedback() {
        // Use system sounds for audio feedback
        // These are reliable system sounds that exist on all macOS versions
        recordStartSound = NSSound(named: "Tink")
        recordStopSound = NSSound(named: "Pop")
        successSound = NSSound(named: "Glass")
        errorSound = NSSound(named: "Basso")
        
        print("AppCoordinator: Audio feedback initialized")
    }
    
    /// Play sound for recording start
    private func playRecordStartSound() {
        guard settings.playAudioFeedback else { return }
        recordStartSound?.play()
    }
    
    /// Play sound for recording stop
    private func playRecordStopSound() {
        guard settings.playAudioFeedback else { return }
        recordStopSound?.play()
    }
    
    /// Play sound for successful transcription
    private func playSuccessSound() {
        guard settings.playAudioFeedback else { return }
        successSound?.play()
    }
    
    /// Play sound for error
    private func playErrorSound() {
        guard settings.playAudioFeedback else { return }
        errorSound?.play()
    }
    
    // MARK: - Recording Overlay Setup
    
    private func setupRecordingOverlay() {
        recordingOverlay = RecordingOverlayWindow()
        print("AppCoordinator: Recording overlay initialized")
    }
    
    /// Show the recording overlay and start audio level updates
    private func showRecordingOverlay() {
        recordingOverlay?.show()
        startAudioLevelUpdates()
    }
    
    /// Hide the recording overlay and stop audio level updates
    private func hideRecordingOverlay() {
        stopAudioLevelUpdates()
        recordingOverlay?.hide()
    }
    
    /// Start timer to update audio level for waveform visualization
    private func startAudioLevelUpdates() {
        // Update at ~25Hz to match AudioRecorder's level update rate
        audioLevelUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.recordingOverlay?.updateAudioLevel(self.audioRecorder.audioLevel)
            }
        }
    }
    
    /// Stop the audio level update timer
    private func stopAudioLevelUpdates() {
        audioLevelUpdateTimer?.invalidate()
        audioLevelUpdateTimer = nil
    }
    
    // MARK: - Hotkey Setup
    
    private func setupHotkeyManager() {
        print("AppCoordinator: Setting up HotkeyManager...")
        
        // Set callback for when recording is toggled via hotkey
        hotkeyManager.onRecordingToggle = { [weak self] shouldRecord in
            Task { @MainActor in
                if shouldRecord {
                    await self?.startRecording()
                } else {
                    await self?.stopRecordingAndTranscribe()
                }
            }
        }
        
        // Register the hotkey
        hotkeyManager.registerHotkey()
        hotkeyManager.printStatus()
    }
    
    // MARK: - Notifications Setup
    
    private func setupNotifications() {
        // Listen for model changes
        NotificationCenter.default.addObserver(
            forName: .activeModelChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let model = notification.object as? WhisperModelType {
                    await self?.handleModelChanged(model)
                }
            }
        }
        
        // Listen for recording events (for UI updates)
        NotificationCenter.default.addObserver(
            forName: .recordingStarted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isRecording = true
                self?.state = .recording
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .recordingStopped,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isRecording = false
            }
        }
    }
    
    // MARK: - Model Loading
    
    private func loadActiveModelInBackground() async {
        guard let activeModel = modelManager.activeModel else {
            state = .error(message: "No model selected")
            showNotification("No model selected. Please download a model in Settings.", type: .warning)
            return
        }
        
        guard modelManager.isModelDownloaded(activeModel) else {
            state = .error(message: "Model not downloaded")
            showNotification("Model '\(activeModel.displayName)' not downloaded. Please download in Settings.", type: .warning)
            return
        }
        
        state = .loading(message: "Loading \(activeModel.displayName)...")
        
        do {
            try await whisperWrapper.loadModel(activeModel)
            state = .ready
            showNotification("Model '\(activeModel.displayName)' loaded successfully", type: .success)
        } catch {
            state = .error(message: "Failed to load model")
            showNotification("Failed to load model: \(error.localizedDescription)", type: .error)
            playErrorSound()
        }
    }
    
    private func handleModelChanged(_ model: WhisperModelType) async {
        print("AppCoordinator: Model changed to \(model.rawValue)")
        
        // Don't reload if recording or processing
        guard !isRecording && !isProcessing else {
            showNotification("Cannot switch models while recording or processing", type: .warning)
            return
        }
        
        await loadActiveModelInBackground()
    }
    
    // MARK: - Main Workflow (9.2)
    
    /// Start recording audio from microphone
    func startRecording() async {
        // Prevent starting if not ready
        guard state.isReady || state == .idle else {
            if case .loading = state {
                showNotification("Please wait for model to load", type: .info)
            } else if case .error = state {
                showNotification("Please fix errors before recording", type: .warning)
            }
            return
        }
        
        // Prevent double-start
        guard !isRecording && !isProcessing else {
            print("AppCoordinator: Already recording or processing, ignoring start request")
            return
        }
        
        // Check if model is loaded
        guard whisperWrapper.isModelLoaded else {
            showNotification("No model loaded. Please select a model in Settings.", type: .warning)
            playErrorSound()
            return
        }
        
        // Check microphone permission
        if !audioRecorder.checkMicrophonePermission() {
            showNotification("Microphone permission required", type: .error)
            playErrorSound()
            // Request permission
            do {
                try await audioRecorder.requestMicrophonePermissionIfNeeded()
                // Permission granted, continue with recording below
            } catch {
                handleError(error, context: "Microphone permission")
                return
            }
        }
        
        print("AppCoordinator: 🎤 Starting recording...")
        
        do {
            // Start recording first - this is the actual async operation
            try await audioRecorder.startRecording()
            
            // Only after recording has successfully started:
            isRecording = true
            state = .recording
            playRecordStartSound()
            showRecordingOverlay()
            
            print("AppCoordinator: 🎤 Recording started successfully")
        } catch {
            handleError(error, context: "Starting recording")
        }
    }
    
    /// Stop recording and begin transcription
    func stopRecordingAndTranscribe() async {
        guard isRecording else {
            print("AppCoordinator: Not currently recording, ignoring stop request")
            return
        }
        
        print("AppCoordinator: ⏹️ Stopping recording and starting transcription...")
        
        playRecordStopSound()
        hideRecordingOverlay()
        isRecording = false
        isProcessing = true
        state = .processing
        
        do {
            // Step 1: Stop recording and get audio data
            let audioSamples = try await audioRecorder.stopRecording()
            
            // Step 2: Transcribe audio
            let transcription = try await transcribeAudio(audioSamples)
            
            // Step 3: Inject text at cursor
            try await injectTranscription(transcription)
            
            // Success!
            lastTranscription = transcription
            isProcessing = false
            state = .ready
            playSuccessSound()
            hotkeyManager.transcriptionDidComplete()
            
            print("AppCoordinator: ✅ Workflow complete: \"\(transcription.prefix(50))...\"")
            
        } catch {
            isProcessing = false
            state = .ready
            hotkeyManager.transcriptionDidComplete()
            handleError(error, context: "Transcription workflow")
        }
    }
    
    /// Cancel recording without transcribing
    func cancelRecording() {
        guard isRecording else { return }
        
        print("AppCoordinator: ❌ Cancelling recording...")
        hideRecordingOverlay()
        audioRecorder.cancelRecording()
        isRecording = false
        state = .ready
        // No toast notification - the overlay disappearing is sufficient feedback
    }
    
    /// Toggle recording on/off (for toggle mode)
    func toggleRecording() async {
        if isRecording {
            await stopRecordingAndTranscribe()
        } else {
            await startRecording()
        }
    }
    
    // MARK: - Transcription
    
    private func transcribeAudio(_ samples: [Float]) async throws -> String {
        print("AppCoordinator: Transcribing \(samples.count) samples...")
        
        // Get language setting (could be user preference in future)
        let language = "en"
        
        // Transcribe using Whisper
        let transcription = try await whisperWrapper.transcribe(
            samples: samples,
            language: language
        )
        
        // Validate transcription
        let trimmedTranscription = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTranscription.isEmpty else {
            throw TranscriptionError.emptyResult
        }
        
        return trimmedTranscription
    }
    
    // MARK: - Text Injection
    
    private func injectTranscription(_ text: String) async throws {
        print("AppCoordinator: Injecting text: \"\(text.prefix(30))...\"")
        
        // Check accessibility permission
        guard textInjector.hasAccessibilityPermission else {
            _ = textInjector.checkAndRequestPermission()
            throw TextInjectionError.accessibilityNotGranted
        }
        
        // Inject the text
        try await textInjector.injectText(text, method: .auto)
    }
    
    // MARK: - Error Handling (9.3)
    
    /// Handle errors with user-facing notifications
    func handleError(_ error: Error, context: String) {
        print("AppCoordinator: ❌ Error in \(context): \(error.localizedDescription)")
        
        playErrorSound()
        
        // Determine error message and type
        let message: String
        let type: NotificationMessage.NotificationType
        
        switch error {
        case let audioError as AudioRecorderError:
            message = handleAudioRecorderError(audioError)
            type = .error
            
        case let whisperError as WhisperError:
            message = handleWhisperError(whisperError)
            type = .error
            
        case let injectionError as TextInjectionError:
            message = handleTextInjectionError(injectionError)
            type = .error
            
        case let transcriptionError as TranscriptionError:
            message = handleTranscriptionError(transcriptionError)
            type = .warning
            
        default:
            message = error.localizedDescription
            type = .error
        }
        
        showNotification(message, type: type)
    }
    
    private func handleAudioRecorderError(_ error: AudioRecorderError) -> String {
        switch error {
        case .microphonePermissionDenied:
            return "Microphone permission denied. Open System Settings to grant access."
        case .microphonePermissionNotDetermined:
            return "Please grant microphone permission."
        case .noAudioData:
            return "No audio recorded. Please try again."
        case .recordingInterrupted:
            return "Recording was interrupted."
        default:
            return error.localizedDescription
        }
    }
    
    private func handleWhisperError(_ error: WhisperError) -> String {
        switch error {
        case .contextNotInitialized:
            return "No model loaded. Please select a model in Settings."
        case .modelLoadFailed:
            return "Failed to load model. Try downloading again."
        case .invalidAudioData:
            return "Invalid audio data. Please try again."
        case .noSegments:
            return "No speech detected. Please try again."
        default:
            return error.localizedDescription
        }
    }
    
    private func handleTextInjectionError(_ error: TextInjectionError) -> String {
        switch error {
        case .accessibilityNotGranted:
            return "Accessibility permission required. Open System Settings to grant access."
        case .emptyText:
            return "No text to inject."
        default:
            return error.localizedDescription
        }
    }
    
    private func handleTranscriptionError(_ error: TranscriptionError) -> String {
        switch error {
        case .emptyResult:
            return "No speech detected in recording."
        }
    }
    
    // MARK: - Notification Display
    
    /// Show a notification message in the menu bar
    func showNotification(_ message: String, type: NotificationMessage.NotificationType, duration: TimeInterval = 4.0) {
        // Cancel any existing dismiss task
        notificationDismissTask?.cancel()
        
        // Set the new notification
        notification = NotificationMessage(message: message, type: type, timestamp: Date())
        
        // Schedule auto-dismiss
        notificationDismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            
            if !Task.isCancelled {
                await MainActor.run {
                    self.dismissNotification()
                }
            }
        }
    }
    
    /// Dismiss the current notification
    func dismissNotification() {
        notification = nil
        notificationDismissTask?.cancel()
        notificationDismissTask = nil
    }
    
    // MARK: - Permission Checks
    
    /// Check all required permissions and show appropriate notifications
    func checkPermissions() {
        var issues: [String] = []
        
        // Check microphone permission
        if !audioRecorder.checkMicrophonePermission() {
            issues.append("Microphone")
        }
        
        // Check accessibility permission
        if !textInjector.hasAccessibilityPermission {
            issues.append("Accessibility")
        }
        
        if !issues.isEmpty {
            let issueList = issues.joined(separator: " and ")
            showNotification("\(issueList) permission required. Open Settings to grant access.", type: .warning, duration: 6.0)
        }
    }
    
    // MARK: - Status Helpers
    
    /// Get current status icon name for menu bar
    var statusIconName: String {
        switch state {
        case .idle:
            return "waveform"
        case .loading:
            return "ellipsis.circle"
        case .ready:
            return "waveform"
        case .recording:
            return "mic.fill"
        case .processing:
            return "ellipsis.circle"
        case .error:
            return "exclamationmark.triangle"
        }
    }
    
    /// Get current status description
    var statusDescription: String {
        switch state {
        case .idle:
            return "Idle"
        case .loading(let message):
            return message
        case .ready:
            if let model = whisperWrapper.loadedModelType {
                return "Ready (\(model.displayName))"
            }
            return "Ready"
        case .recording:
            return "Recording... (\(audioRecorder.formattedDuration))"
        case .processing:
            return "Processing..."
        case .error(let message):
            return message
        }
    }
    
    /// Audio level for visualization (0.0 - 1.0)
    var audioLevel: Float {
        audioRecorder.audioLevel
    }
    
    /// Recording duration
    var recordingDuration: TimeInterval {
        audioRecorder.recordingDuration
    }
}

// MARK: - Transcription Error

enum TranscriptionError: LocalizedError {
    case emptyResult
    
    var errorDescription: String? {
        switch self {
        case .emptyResult:
            return "No speech was detected in the recording."
        }
    }
}
