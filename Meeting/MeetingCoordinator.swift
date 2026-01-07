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
        
        // Stop recording
        let chunkURLs = try await recorder.stopRecording()
        
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
}
