//
//  MeetingCoordinator.swift
//  WhisperType
//
//  State machine orchestrating the entire meeting workflow.
//  Manages transitions between recording, processing, and completion.
//

import Foundation
import Combine

/// Central coordinator for meeting recording workflow
@MainActor
class MeetingCoordinator: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = MeetingCoordinator()
    
    // MARK: - Published Properties
    
    /// Current meeting session (nil when idle)
    @Published private(set) var currentSession: MeetingSession?
    
    /// Current state of the coordinator
    @Published private(set) var state: MeetingState = .idle
    
    /// Whether a meeting is currently active
    var isActive: Bool {
        state.isActive
    }
    
    /// Whether recording is in progress
    var isRecording: Bool {
        state == .recording
    }
    
    /// Whether processing is in progress
    var isProcessing: Bool {
        state == .processing
    }
    
    /// Current recording duration
    var duration: TimeInterval {
        recorder.duration
    }
    
    /// Current audio level (for UI display)
    var audioLevel: Float {
        recorder.audioLevel
    }
    
    /// Formatted duration string
    var formattedDuration: String {
        recorder.formattedDuration
    }
    
    // MARK: - Live Subtitles
    
    /// Whether live subtitles are enabled for recording
    @Published var liveSubtitlesEnabled: Bool = true
    
    /// The streaming processor for live transcription
    private(set) var streamingProcessor: StreamingWhisperProcessor?
    
    /// The live subtitle window
    private(set) var subtitleWindow: LiveSubtitleWindow?
    
    // MARK: - Dependencies
    
    private let recorder: MeetingRecorder
    private let streamBus: AudioStreamBus
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var backgroundTaskIdentifier: NSBackgroundActivityScheduler?
    
    // MARK: - Initialization
    
    private init(recorder: MeetingRecorder? = nil, streamBus: AudioStreamBus = .shared) {
        self.recorder = recorder ?? MeetingRecorder(streamBus: streamBus)
        self.streamBus = streamBus
        
        setupBindings()
        setupNotifications()
        
        print("MeetingCoordinator: Initialized")
    }
    
    // MARK: - Bindings
    
    private func setupBindings() {
        // Sync state with recorder
        recorder.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                if isRecording && self?.state == .idle {
                    self?.state = .recording
                }
            }
            .store(in: &cancellables)
        
        // Sync duration with session
        recorder.$duration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                self?.currentSession?.updateDuration(duration)
            }
            .store(in: &cancellables)
    }
    
    private func setupNotifications() {
        // Handle duration warning
        NotificationCenter.default.addObserver(
            forName: .meetingDurationWarning,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDurationWarning()
        }
    }
    
    // MARK: - Public API
    
    /// Start a new meeting recording
    /// - Parameters:
    ///   - title: Optional title for the meeting
    ///   - audioSource: Audio source configuration
    func startRecording(title: String? = nil, audioSource: AudioSource = .both) async throws {
        guard state == .idle else {
            throw MeetingStateError.invalidTransition(from: state, to: .recording)
        }
        
        // Create new session
        let session = MeetingSession(title: title, audioSource: audioSource)
        currentSession = session
        
        // Transition session to recording
        try session.transition(to: .recording)
        
        // Start recording
        try await recorder.startRecording(session: session)
        
        // Update state
        state = .recording
        
        // Start live subtitles if enabled
        print("MeetingCoordinator: liveSubtitlesEnabled = \(liveSubtitlesEnabled)")
        if liveSubtitlesEnabled {
            print("MeetingCoordinator: Starting live subtitles...")
            startLiveSubtitles()
        } else {
            print("MeetingCoordinator: Live subtitles disabled, skipping")
        }
        
        // Begin background task protection
        beginBackgroundTask()
        
        print("MeetingCoordinator: Started recording session \(session.id)")
    }
    
    /// Stop the current recording and begin processing
    func stopRecording() async throws -> MeetingSession? {
        guard state == .recording else {
            throw MeetingStateError.invalidTransition(from: state, to: .processing)
        }
        
        guard let session = currentSession else {
            throw MeetingRecorderError.notRecording
        }
        
        print("MeetingCoordinator: Stopping recording...")
        
        // IMPORTANT: Capture session directory BEFORE stopping recorder (it becomes nil after stop)
        let savedSessionDir = sessionDirectory
        print("MeetingCoordinator: Session directory for saving: \(savedSessionDir?.path ?? "nil")")
        
        // Stop recording FIRST so final audio chunks are published
        let chunkURLs = try await recorder.stopRecording()
        
        // Wait for the streaming processor to receive and process final chunks
        // Whisper transcription can take 1-2 seconds, so we wait 2.5s to be safe
        print("MeetingCoordinator: Waiting for final transcription...")
        try? await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 seconds
        
        // NOW stop live subtitles (processor will save transcripts)
        stopLiveSubtitles(savingTo: savedSessionDir)
        
        // Transition to processing
        state = .processing
        try session.transition(to: .processing)
        
        // Start processing (for Phase 1, this just completes immediately)
        await processRecording(session: session, chunkURLs: chunkURLs)
        
        return session
    }
    
    /// Cancel the current recording without saving
    func cancelRecording() {
        guard state == .recording || state == .paused else { return }
        
        print("MeetingCoordinator: Cancelling recording...")
        
        // Stop live subtitles
        stopLiveSubtitles()
        
        recorder.cancelRecording()
        
        // Reset state
        state = .idle
        currentSession = nil
        
        // End background task
        endBackgroundTask()
    }
    
    /// Transition to a new state
    func transition(to newState: MeetingState) throws {
        guard state != newState else {
            throw MeetingStateError.alreadyInState(newState)
        }
        
        // Validate transition using same rules as MeetingSession
        let validTransitions: [MeetingState: Set<MeetingState>] = [
            .idle: [.recording],
            .recording: [.paused, .processing, .error],
            .paused: [.recording, .processing, .error],
            .processing: [.complete, .error],
            .complete: [.idle],
            .error: [.idle, .recording]
        ]
        
        guard validTransitions[state]?.contains(newState) ?? false else {
            throw MeetingStateError.invalidTransition(from: state, to: newState)
        }
        
        let oldState = state
        state = newState
        
        print("MeetingCoordinator: Transitioned from \(oldState) to \(newState)")
        
        // Handle state-specific actions
        switch newState {
        case .idle:
            currentSession = nil
            endBackgroundTask()
        case .complete:
            endBackgroundTask()
            NotificationCenter.default.post(name: .meetingProcessingComplete, object: currentSession)
        case .error:
            endBackgroundTask()
        default:
            break
        }
    }
    
    /// Reset coordinator to idle state
    func reset() {
        if recorder.isRecording {
            recorder.cancelRecording()
        }
        
        state = .idle
        currentSession = nil
        endBackgroundTask()
        
        print("MeetingCoordinator: Reset to idle")
    }
    
    // MARK: - Processing
    
    /// Process a completed recording
    /// For Phase 1, this is a placeholder that immediately completes
    private func processRecording(session: MeetingSession, chunkURLs: [URL]) async {
        print("MeetingCoordinator: Processing \(chunkURLs.count) chunks...")
        
        // Phase 1: Just mark as complete
        // Future phases will add transcription, diarization, summarization
        
        session.setProcessingStage(.transcribing)
        
        // Simulate minimal processing delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        session.setProcessingStage(.complete)
        
        // Transition to complete
        do {
            try session.transition(to: .complete)
            try transition(to: .complete)
        } catch {
            print("MeetingCoordinator: Error completing session - \(error)")
            session.setError(error.localizedDescription)
        }
        
        print("MeetingCoordinator: Processing complete for session \(session.id)")
        
        // Reset to idle so user can start a new recording
        do {
            try transition(to: .idle)
            print("MeetingCoordinator: Reset to idle, ready for new recording")
        } catch {
            print("MeetingCoordinator: Error resetting to idle - \(error)")
        }
    }
    
    // MARK: - Background Task Management
    
    private func beginBackgroundTask() {
        // Create a background activity to keep the app running during recording
        let scheduler = NSBackgroundActivityScheduler(identifier: "com.whispertype.meeting-recording")
        scheduler.interval = 60 // Check every minute
        scheduler.repeats = true
        scheduler.qualityOfService = .userInitiated
        
        scheduler.schedule { [weak self] completion in
            // Keep activity alive while recording
            if self?.isRecording == true {
                completion(.finished)
            } else {
                completion(.deferred)
            }
        }
        
        backgroundTaskIdentifier = scheduler
        print("MeetingCoordinator: Background task started")
    }
    
    private func endBackgroundTask() {
        backgroundTaskIdentifier?.invalidate()
        backgroundTaskIdentifier = nil
        print("MeetingCoordinator: Background task ended")
    }
    
    // MARK: - Duration Warning
    
    private func handleDurationWarning() {
        guard state == .recording else { return }
        
        print("MeetingCoordinator: Duration warning - 5 minutes remaining")
        
        // The notification is already posted by MeetingRecorder
        // UI layer should observe this and show warning to user
    }
    
    // MARK: - Utility
    
    /// Get all chunk URLs for the current session
    var chunkURLs: [URL] {
        recorder.chunkURLs
    }
    
    /// Get the session directory for the current session
    var sessionDirectory: URL? {
        recorder.sessionDirectory
    }
    
    // MARK: - Live Subtitles
    
    /// Start the live subtitles feature
    private func startLiveSubtitles() {
        print("MeetingCoordinator: Starting live subtitles...")
        
        // Create streaming processor
        let processor = StreamingWhisperProcessor(
            whisperWrapper: .shared,
            streamBus: streamBus
        )
        streamingProcessor = processor
        
        // Create subtitle window
        let window = LiveSubtitleWindow()
        subtitleWindow = window
        
        // Connect window to processor
        window.connectToProcessor(processor)
        window.connectToCoordinator(self)
        
        // Start processor
        processor.start()
        
        // Show window
        window.show()
        
        print("MeetingCoordinator: Live subtitles started")
    }
    
    /// Stop the live subtitles feature
    /// - Parameter savingTo: Optional session directory to save transcripts to
    private func stopLiveSubtitles(savingTo directory: URL? = nil) {
        print("MeetingCoordinator: Stopping live subtitles...")
        
        // Debug: Log processor state
        if let processor = streamingProcessor {
            print("MeetingCoordinator: Processor has \(processor.transcriptUpdates.count) transcript updates")
            print("MeetingCoordinator: Full transcript: \(processor.fullTranscript)")
            
            // Save transcript before stopping
            if !processor.transcriptUpdates.isEmpty {
                saveTranscriptToDisk(updates: processor.transcriptUpdates, to: directory)
            } else {
                print("MeetingCoordinator: No transcripts to save (updates empty)")
            }
        } else {
            print("MeetingCoordinator: No streaming processor found")
        }
        
        // Stop processor
        streamingProcessor?.stop()
        
        // Hide and cleanup window
        subtitleWindow?.setRecording(false)
        subtitleWindow?.disconnect()
        
        // Delay hiding to show "Processing..." state briefly
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await MainActor.run {
                subtitleWindow?.hide()
            }
        }
        
        print("MeetingCoordinator: Live subtitles stopped")
    }
    
    /// Save transcript updates to the session directory
    /// - Parameters:
    ///   - updates: The transcript updates to save
    ///   - directory: Optional directory to save to (uses sessionDirectory if nil)
    private func saveTranscriptToDisk(updates: [TranscriptUpdate], to directory: URL? = nil) {
        guard let sessionDir = directory ?? sessionDirectory else {
            print("MeetingCoordinator: No session directory, skipping transcript save")
            return
        }
        
        print("MeetingCoordinator: Saving transcript to \(sessionDir.path)")
        
        do {
            // Save as JSON
            let jsonURL = sessionDir.appendingPathComponent("live_transcript.json")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(updates)
            try jsonData.write(to: jsonURL, options: .atomic)
            print("MeetingCoordinator: Saved transcript JSON to \(jsonURL.path)")
            
            // Also save as Markdown for easy reading
            let markdownURL = sessionDir.appendingPathComponent("live_transcript.md")
            var markdown = "# Live Transcript\n\n"
            markdown += "**Date:** \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))\n\n"
            markdown += "---\n\n"
            for update in updates.sorted(by: { $0.timestamp < $1.timestamp }) {
                markdown += "\(update.formattedTimestamp)\n\(update.text)\n\n"
            }
            try markdown.write(to: markdownURL, atomically: true, encoding: .utf8)
            print("MeetingCoordinator: Saved transcript Markdown to \(markdownURL.path)")
            
        } catch {
            print("MeetingCoordinator: Failed to save transcript - \(error)")
        }
    }
    
    /// Toggle the subtitle window visibility
    func toggleSubtitleWindow() {
        subtitleWindow?.toggle()
    }
    
    /// Show the subtitle window
    func showSubtitleWindow() {
        subtitleWindow?.show()
    }
    
    /// Hide the subtitle window
    func hideSubtitleWindow() {
        subtitleWindow?.hide()
    }
    
    /// Whether the subtitle window is visible
    var isSubtitleWindowVisible: Bool {
        subtitleWindow?.isVisible ?? false
    }
}
