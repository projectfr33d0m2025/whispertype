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
}

enum Constants {

    // MARK: - App Info

    static let appName = "WhisperType"
    static let appVersion = "1.0.0"
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
    }

    // MARK: - Audio Settings

    enum Audio {
        // Whisper expects 16kHz sample rate
        static let whisperSampleRate: Double = 16000.0

        // Audio format for Whisper
        static let channels: UInt32 = 1 // mono
        static let bitDepth: UInt32 = 32 // Float32
    }

    // MARK: - Limits

    enum Limits {
        // Vocabulary word limit
        static let maxVocabularyWords = 30

        // History entry limit
        static let maxHistoryEntries = 500

        // Maximum recording duration (seconds)
        static let maxRecordingDuration: TimeInterval = 300 // 5 minutes
    }

    // MARK: - UI

    enum UI {
        // Menu bar icon names (to be added to Assets)
        static let menuBarIconIdle = "menubar.idle"
        static let menuBarIconRecording = "menubar.recording"
        static let menuBarIconProcessing = "menubar.processing"

        // Window sizes
        static let settingsWindowSize = NSSize(width: 600, height: 500)
    }
}
