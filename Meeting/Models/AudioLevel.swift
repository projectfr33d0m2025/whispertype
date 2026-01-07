//
//  AudioLevel.swift
//  WhisperType
//
//  Represents audio level information for monitoring during recording.
//

import Foundation

/// Represents audio level information from one or more sources
struct AudioLevel: Equatable {
    
    // MARK: - Properties
    
    /// Audio level in decibels (dB) for microphone input
    /// Range: typically -60 dB (silence) to 0 dB (max)
    let microphoneLevel: Float?
    
    /// Audio level in decibels (dB) for system audio
    /// Range: typically -60 dB (silence) to 0 dB (max)
    let systemLevel: Float?
    
    /// Peak level in decibels (highest of all sources)
    var peakLevel: Float {
        let levels = [microphoneLevel, systemLevel].compactMap { $0 }
        return levels.max() ?? -60.0
    }
    
    /// Whether any audio is currently being detected
    var hasAudio: Bool {
        peakLevel > AudioLevel.silenceThreshold
    }
    
    /// Whether audio level indicates clipping
    var isClipping: Bool {
        peakLevel > AudioLevel.clippingThreshold
    }
    
    /// Whether audio level is too low
    var isTooQuiet: Bool {
        peakLevel < AudioLevel.tooQuietThreshold
    }
    
    // MARK: - Thresholds (in dB)
    
    /// Threshold below which audio is considered silence
    static let silenceThreshold: Float = -50.0
    
    /// Threshold above which audio is clipping
    static let clippingThreshold: Float = -1.0
    
    /// Threshold below which audio is too quiet for good transcription
    static let tooQuietThreshold: Float = -40.0
    
    /// Duration before warning about low/no audio (seconds)
    static let warningDuration: TimeInterval = 10.0
    
    // MARK: - Initialization
    
    init(microphoneLevel: Float? = nil, systemLevel: Float? = nil) {
        self.microphoneLevel = microphoneLevel
        self.systemLevel = systemLevel
    }
    
    // MARK: - Convenience Initializers
    
    /// Create level from a single microphone source
    static func microphone(_ level: Float) -> AudioLevel {
        AudioLevel(microphoneLevel: level)
    }
    
    /// Create level from a single system audio source
    static func system(_ level: Float) -> AudioLevel {
        AudioLevel(systemLevel: level)
    }
    
    /// Create level from both sources
    static func both(microphone: Float, system: Float) -> AudioLevel {
        AudioLevel(microphoneLevel: microphone, systemLevel: system)
    }
    
    /// Silent level (no audio)
    static var silent: AudioLevel {
        AudioLevel(microphoneLevel: -60.0, systemLevel: -60.0)
    }
    
    // MARK: - Helper Methods
    
    /// Normalize level to 0-1 range for UI display
    /// Maps -60 dB (silence) to 0.0 and 0 dB (max) to 1.0
    static func normalizeLevel(_ dB: Float) -> Float {
        let minDB: Float = -60.0
        let maxDB: Float = 0.0
        return max(0, min(1, (dB - minDB) / (maxDB - minDB)))
    }
    
    /// Get normalized microphone level (0-1) for UI display
    var normalizedMicrophoneLevel: Float {
        guard let level = microphoneLevel else { return 0 }
        return AudioLevel.normalizeLevel(level)
    }
    
    /// Get normalized system level (0-1) for UI display
    var normalizedSystemLevel: Float {
        guard let level = systemLevel else { return 0 }
        return AudioLevel.normalizeLevel(level)
    }
    
    /// Get normalized peak level (0-1) for UI display
    var normalizedPeakLevel: Float {
        AudioLevel.normalizeLevel(peakLevel)
    }
}

// MARK: - AudioLevelWarning

/// Warning types for audio quality issues
enum AudioLevelWarning: Equatable {
    /// Audio level is too low for good transcription
    case tooQuiet
    
    /// Audio is clipping (too loud)
    case clipping
    
    /// No audio detected for extended period
    case noAudio
    
    /// Warning message for display
    var message: String {
        switch self {
        case .tooQuiet:
            return "Audio level is very low. Check your microphone."
        case .clipping:
            return "Audio is too loud and may be distorted."
        case .noAudio:
            return "No audio detected. Is your microphone working?"
        }
    }
}
