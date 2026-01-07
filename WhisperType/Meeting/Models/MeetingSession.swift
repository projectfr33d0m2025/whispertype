//
//  MeetingSession.swift
//  WhisperType
//
//  Core model for a meeting recording session.
//  Includes state machine, metadata, and audio source configuration.
//

import Foundation

// MARK: - Audio Source

/// Audio source selection for meeting recording
enum AudioSource: String, Codable, CaseIterable {
    case microphone = "microphone"
    case system = "system"
    case both = "both"
    
    var displayName: String {
        switch self {
        case .microphone: return "Microphone Only"
        case .system: return "System Audio Only"
        case .both: return "Both (Microphone + System)"
        }
    }
    
    var description: String {
        switch self {
        case .microphone:
            return "Records only from your microphone. Best for in-person meetings."
        case .system:
            return "Records audio from other applications. Best for listening to recordings."
        case .both:
            return "Combines microphone and system audio. Recommended for video calls."
        }
    }
}

// MARK: - Meeting State

/// State of the meeting recording session
enum MeetingState: String, Codable, CaseIterable {
    case idle = "idle"
    case recording = "recording"
    case paused = "paused"
    case processing = "processing"
    case complete = "complete"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .idle: return "Ready"
        case .recording: return "Recording"
        case .paused: return "Paused"
        case .processing: return "Processing"
        case .complete: return "Complete"
        case .error: return "Error"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .recording, .paused, .processing:
            return true
        case .idle, .complete, .error:
            return false
        }
    }
}

// MARK: - Processing Stage

/// Processing stages after recording stops
enum ProcessingStage: String, Codable, CaseIterable {
    case none = "none"
    case transcribing = "transcribing"
    case diarizing = "diarizing"
    case summarizing = "summarizing"
    case complete = "complete"
    
    var displayName: String {
        switch self {
        case .none: return ""
        case .transcribing: return "Transcribing audio..."
        case .diarizing: return "Identifying speakers..."
        case .summarizing: return "Generating summary..."
        case .complete: return "Processing complete"
        }
    }
    
    var progress: Double {
        switch self {
        case .none: return 0.0
        case .transcribing: return 0.25
        case .diarizing: return 0.50
        case .summarizing: return 0.75
        case .complete: return 1.0
        }
    }
}

// MARK: - State Transition Error

/// Errors that can occur during state transitions
enum MeetingStateError: LocalizedError {
    case invalidTransition(from: MeetingState, to: MeetingState)
    case alreadyInState(MeetingState)
    case cannotStartRecording(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidTransition(let from, let to):
            return "Cannot transition from \(from.displayName) to \(to.displayName)"
        case .alreadyInState(let state):
            return "Already in \(state.displayName) state"
        case .cannotStartRecording(let reason):
            return "Cannot start recording: \(reason)"
        }
    }
}

// MARK: - Meeting Session

/// Represents a meeting recording session
class MeetingSession: ObservableObject, Identifiable, Codable {
    
    // MARK: - Properties
    
    /// Unique session identifier
    let id: String
    
    /// Meeting title (defaults to date/time, user can edit)
    @Published var title: String
    
    /// When the meeting was created/started
    let createdAt: Date
    
    /// Current state of the session
    @Published private(set) var state: MeetingState = .idle
    
    /// Current processing stage (when state is .processing)
    @Published private(set) var processingStage: ProcessingStage = .none
    
    /// Audio source configuration
    let audioSource: AudioSource
    
    /// Recording duration in seconds
    @Published private(set) var duration: TimeInterval = 0
    
    /// Number of speakers detected (after diarization)
    @Published var speakerCount: Int = 0
    
    /// Error message if state is .error
    @Published var errorMessage: String?
    
    /// Session directory on disk
    let sessionDirectory: URL
    
    /// Whether audio files should be kept after transcription
    var keepAudioFiles: Bool = false
    
    // MARK: - Computed Properties
    
    /// Formatted duration string (MM:SS or HH:MM:SS)
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    /// Time remaining before 90-minute limit
    var timeRemaining: TimeInterval {
        max(0, Constants.Limits.maxMeetingDuration - duration)
    }
    
    /// Formatted time remaining
    var formattedTimeRemaining: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Whether the duration warning should be shown (at 85 minutes)
    var shouldShowDurationWarning: Bool {
        duration >= Constants.Limits.meetingWarningDuration &&
        duration < Constants.Limits.maxMeetingDuration
    }
    
    /// Whether the max duration has been reached
    var hasReachedMaxDuration: Bool {
        duration >= Constants.Limits.maxMeetingDuration
    }
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        title: String? = nil,
        audioSource: AudioSource = .both,
        sessionDirectory: URL? = nil
    ) {
        self.id = id
        self.createdAt = Date()
        self.audioSource = audioSource
        
        // Generate default title from current date/time
        if let title = title {
            self.title = title
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, h:mm a"
            self.title = "Meeting - \(formatter.string(from: createdAt))"
        }
        
        // Set session directory
        if let dir = sessionDirectory {
            self.sessionDirectory = dir
        } else {
            self.sessionDirectory = Constants.Paths.meetingSession(id: id, date: createdAt)
        }
    }
    
    // MARK: - State Machine
    
    /// Valid state transitions
    private static let validTransitions: [MeetingState: Set<MeetingState>] = [
        .idle: [.recording],
        .recording: [.paused, .processing, .error],
        .paused: [.recording, .processing, .error],
        .processing: [.complete, .error],
        .complete: [.idle], // For starting a new recording
        .error: [.idle, .recording] // Can retry or reset
    ]
    
    /// Check if a transition is valid
    func canTransition(to newState: MeetingState) -> Bool {
        if state == newState { return false }
        return MeetingSession.validTransitions[state]?.contains(newState) ?? false
    }
    
    /// Transition to a new state
    /// - Throws: MeetingStateError if transition is invalid
    func transition(to newState: MeetingState) throws {
        guard state != newState else {
            throw MeetingStateError.alreadyInState(newState)
        }
        
        guard canTransition(to: newState) else {
            throw MeetingStateError.invalidTransition(from: state, to: newState)
        }
        
        let oldState = state
        state = newState
        
        // Reset processing stage when leaving processing
        if oldState == .processing {
            processingStage = .complete
        }
        
        // Clear error when leaving error state
        if oldState == .error {
            errorMessage = nil
        }
        
        print("MeetingSession: Transitioned from \(oldState) to \(newState)")
        
        // Post notification
        NotificationCenter.default.post(
            name: .meetingStateChanged,
            object: self,
            userInfo: ["oldState": oldState, "newState": newState]
        )
    }
    
    /// Set the processing stage
    func setProcessingStage(_ stage: ProcessingStage) {
        guard state == .processing else { return }
        processingStage = stage
        print("MeetingSession: Processing stage: \(stage.displayName)")
    }
    
    /// Update the recording duration
    func updateDuration(_ newDuration: TimeInterval) {
        duration = newDuration
        
        // Check for duration warning
        if shouldShowDurationWarning {
            NotificationCenter.default.post(name: .meetingDurationWarning, object: self)
        }
    }
    
    /// Set error state with message
    func setError(_ message: String) {
        errorMessage = message
        do {
            try transition(to: .error)
        } catch {
            // Force set to error state
            state = .error
        }
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, title, createdAt, state, processingStage, audioSource
        case duration, speakerCount, errorMessage, sessionDirectory, keepAudioFiles
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        state = try container.decode(MeetingState.self, forKey: .state)
        processingStage = try container.decode(ProcessingStage.self, forKey: .processingStage)
        audioSource = try container.decode(AudioSource.self, forKey: .audioSource)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        speakerCount = try container.decode(Int.self, forKey: .speakerCount)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        sessionDirectory = try container.decode(URL.self, forKey: .sessionDirectory)
        keepAudioFiles = try container.decode(Bool.self, forKey: .keepAudioFiles)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(state, forKey: .state)
        try container.encode(processingStage, forKey: .processingStage)
        try container.encode(audioSource, forKey: .audioSource)
        try container.encode(duration, forKey: .duration)
        try container.encode(speakerCount, forKey: .speakerCount)
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
        try container.encode(sessionDirectory, forKey: .sessionDirectory)
        try container.encode(keepAudioFiles, forKey: .keepAudioFiles)
    }
}
