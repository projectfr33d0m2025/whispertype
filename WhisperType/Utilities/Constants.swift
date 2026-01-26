//
//  Constants.swift
//  WhisperType
//
//  App-wide constants and configuration values.
//

import Foundation
import AppKit

// MARK: - Notification Names

extension Notification.Name {
    /// Posted to switch to the Vocabulary tab in settings
    static let switchToVocabularyTab = Notification.Name("switchToVocabularyTab")
    /// Posted to switch to the App Rules tab in settings
    static let switchToAppRulesTab = Notification.Name("switchToAppRulesTab")
    
    // MARK: - Meeting Notifications (v1.3)
    
    /// Posted when meeting recording starts
    static let meetingRecordingStarted = Notification.Name("meetingRecordingStarted")
    /// Posted when meeting recording stops
    static let meetingRecordingStopped = Notification.Name("meetingRecordingStopped")
    /// Posted when meeting recording is cancelled
    static let meetingRecordingCancelled = Notification.Name("meetingRecordingCancelled")
    /// Posted when meeting processing completes
    static let meetingProcessingComplete = Notification.Name("meetingProcessingComplete")
    /// Posted when full transcript is ready after two-pass processing
    static let meetingTranscriptReady = Notification.Name("meetingTranscriptReady")
    /// Posted when meeting state changes
    static let meetingStateChanged = Notification.Name("meetingStateChanged")
    /// Posted when 85-minute warning should be shown
    static let meetingDurationWarning = Notification.Name("meetingDurationWarning")
}

enum Constants {

    // MARK: - App Info

    static let appName = "WhisperType"
    static let appVersion = "1.3.0"
    static let appBundleIdentifier = "com.whispertype.app"

    // MARK: - URLs

    enum URLs {
        // Hugging Face model repository base URL
        static let huggingFaceBase = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main"

        // Model download URLs (constructed with model filename)
        static func modelDownloadURL(filename: String) -> URL {
            URL(string: "\(huggingFaceBase)/\(filename)")!
        }

        // GitHub repository
        static let githubRepo = URL(string: "https://github.com/whispertype/whispertype")!

        // Documentation
        static let documentation = URL(string: "https://github.com/whispertype/whispertype/wiki")!
    }

    // MARK: - File Paths

    enum Paths {
        // Application Support directory
        static var applicationSupport: URL {
            let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            let appSupport = paths[0].appendingPathComponent(appName)

            // Create directory if it doesn't exist
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)

            return appSupport
        }

        // Models directory
        static var models: URL {
            let modelsPath = applicationSupport.appendingPathComponent("Models")
            try? FileManager.default.createDirectory(at: modelsPath, withIntermediateDirectories: true)
            return modelsPath
        }

        // Audio history directory
        static var audioHistory: URL {
            let audioPath = applicationSupport.appendingPathComponent("AudioHistory")
            try? FileManager.default.createDirectory(at: audioPath, withIntermediateDirectories: true)
            return audioPath
        }

        // Vocabulary file
        static var vocabulary: URL {
            applicationSupport.appendingPathComponent("vocabulary.json")
        }

        // History file
        static var history: URL {
            applicationSupport.appendingPathComponent("history.json")
        }
        
        // MARK: - Meeting Paths (v1.3)
        
        /// Base directory for all meetings
        static var meetings: URL {
            let meetingsPath = applicationSupport.appendingPathComponent("Meetings")
            try? FileManager.default.createDirectory(at: meetingsPath, withIntermediateDirectories: true)
            return meetingsPath
        }
        
        /// SQLite database for meeting metadata
        static var meetingsDatabase: URL {
            applicationSupport.appendingPathComponent("meetings.db")
        }
        
        /// Generate a session directory for a new meeting
        /// Format: 2025-01-06_103000_<uuid>
        static func meetingSession(id: String, date: Date = Date()) -> URL {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
            let dateString = dateFormatter.string(from: date)
            
            let sessionDir = meetings.appendingPathComponent("\(dateString)_\(id)")
            try? FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
            return sessionDir
        }
        
        /// Audio chunks directory within a session
        static func audioChunks(sessionDirectory: URL) -> URL {
            let audioDir = sessionDirectory.appendingPathComponent("audio")
            try? FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
            return audioDir
        }
    }

    // MARK: - UserDefaults Keys

    enum UserDefaultsKeys {
        static let activeModelId = "activeModelId"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifierFlags = "hotkeyModifierFlags"
        static let launchAtLogin = "launchAtLogin"
        static let selectedMicrophoneId = "selectedMicrophoneId"
        static let keepAudioRecordings = "keepAudioRecordings"
        static let audioRetentionDays = "audioRetentionDays"
        static let playAudioFeedback = "playAudioFeedback"
        static let hotkeyMode = "hotkeyMode" // "hold" or "toggle"
        static let languageHint = "languageHint" // Language code for transcription
        
        // v1.2 Processing Settings
        static let processingMode = "processingMode"
        static let fillerRemovalEnabled = "fillerRemovalEnabled"
        static let llmPreference = "llmPreference"
        static let ollamaModel = "ollamaModel"
        static let ollamaHost = "ollamaHost"
        static let ollamaPort = "ollamaPort"
        
        // v1.2 Cloud Provider Settings
        static let cloudProviderType = "cloudProviderType"
        static let cloudModel = "cloudModel"
        
        // MARK: - v1.3 Meeting Settings
        
        static let meetingDefaultAudioSource = "meetingDefaultAudioSource"
        static let meetingShowLiveSubtitles = "meetingShowLiveSubtitles"
        static let meetingAudioQualityWarnings = "meetingAudioQualityWarnings"
        static let meetingKeepAudioFiles = "meetingKeepAudioFiles"
        static let meetingDefaultTemplate = "meetingDefaultTemplate"
        static let meetingSpeakerMode = "meetingSpeakerMode"
        static let meetingPythonPath = "meetingPythonPath"
        static let meetingLiveSubtitleWindowFrame = "meetingLiveSubtitleWindowFrame"
        static let meetingSummaryLLMPreference = "meetingSummaryLLMPreference"
    }

    // MARK: - Default Values

    enum Defaults {
        // Default hotkey: Option + Space
        static let hotkeyKeyCode: UInt32 = 49 // Space key
        static let hotkeyModifierFlags: NSEvent.ModifierFlags = [.option]

        // Default model (tiny.en - smallest, fastest)
        static let defaultModelId = "tiny.en"

        // Audio settings
        static let audioRetentionDays = 7
        static let keepAudioRecordings = false
        static let playAudioFeedback = true

        // Hotkey mode
        static let hotkeyMode = "toggle" // "hold" or "toggle"
        
        // Language hint (default to English)
        static let languageHint = "en"
        
        // v1.2 Processing Defaults
        static let processingMode: ProcessingMode = .formatted
        static let fillerRemovalEnabled = true
        static let llmPreference: LLMPreference = .localFirst
        static let ollamaModel = "llama3.2:3b"
        static let ollamaHost = "localhost"
        static let ollamaPort = 11434
        
        // v1.2 Cloud Provider Defaults
        static let cloudProviderType: CloudProviderType = .openRouter
        static let cloudModel = "openai/gpt-4o-mini"
        
        // MARK: - v1.3 Meeting Defaults
        
        static let meetingDefaultAudioSource = "both" // "microphone", "system", "both"
        static let meetingShowLiveSubtitles = true
        static let meetingAudioQualityWarnings = true
        static let meetingKeepAudioFiles = false
        static let meetingDefaultTemplate = "standard"
        static let meetingSpeakerMode = "basic" // "basic" or "enhanced" (pyannote)
    }

    // MARK: - Audio Settings

    enum Audio {
        // Whisper expects 16kHz sample rate
        static let whisperSampleRate: Double = 16000.0

        // Audio format for Whisper
        static let channels: UInt32 = 1 // mono
        static let bitDepth: UInt32 = 32 // Float32
        
        // MARK: - v1.3 Meeting Audio Settings
        
        /// Sample rate for meeting recordings (16kHz for Whisper compatibility)
        static let meetingSampleRate: Double = 16000.0
        
        /// Bit depth for meeting recordings (16-bit for smaller files)
        static let meetingBitDepth: UInt32 = 16
        
        /// Audio chunk duration in seconds
        static let chunkDurationSeconds: TimeInterval = 30.0
        
        /// Ring buffer size in seconds (max audio held in memory)
        static let ringBufferSizeSeconds: TimeInterval = 30.0
        
        /// Approximate bytes per second for 16kHz 16-bit mono audio
        static let bytesPerSecond: Int = 32000 // 16000 samples * 2 bytes
    }

    // MARK: - Limits

    enum Limits {
        // Vocabulary word limit
        static let maxVocabularyWords = 30

        // History entry limit
        static let maxHistoryEntries = 500

        // Maximum recording duration (seconds)
        static let maxRecordingDuration: TimeInterval = 300 // 5 minutes
        
        // MARK: - v1.3 Meeting Limits
        
        /// Maximum meeting recording duration in seconds (90 minutes)
        static let maxMeetingDuration: TimeInterval = 90 * 60 // 5400 seconds
        
        /// Duration warning threshold in seconds (85 minutes)
        static let meetingWarningDuration: TimeInterval = 85 * 60 // 5100 seconds
        
        /// Maximum memory usage for meeting recording in MB
        static let maxMeetingMemoryMB: Int = 100
        
        /// Maximum number of speakers for diarization
        static let maxSpeakers: Int = 10
        
        /// Minimum number of speakers for diarization
        static let minSpeakers: Int = 2
    }

    // MARK: - UI

    enum UI {
        // Menu bar icon names (to be added to Assets)
        static let menuBarIconIdle = "menubar.idle"
        static let menuBarIconRecording = "menubar.recording"
        static let menuBarIconProcessing = "menubar.processing"

        // Window sizes
        static let settingsWindowSize = NSSize(width: 600, height: 500)
        
        // MARK: - v1.3 Meeting UI
        
        /// Default live subtitle window size
        static let liveSubtitleWindowSize = NSSize(width: 500, height: 300)
        
        /// Minimum live subtitle window size
        static let liveSubtitleWindowMinSize = NSSize(width: 300, height: 150)
        
        /// Live subtitle window opacity
        static let liveSubtitleWindowOpacity: Double = 0.95
    }
}

