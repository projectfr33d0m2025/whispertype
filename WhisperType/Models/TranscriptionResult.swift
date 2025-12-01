//
//  TranscriptionResult.swift
//  WhisperType
//
//  Represents the result of a transcription operation.
//

import Foundation

struct TranscriptionResult {

    // MARK: - Properties

    /// Unique identifier for this transcription
    let id: UUID

    /// The transcribed text
    let text: String

    /// Duration of the audio in seconds
    let audioDuration: TimeInterval

    /// Time taken to perform transcription
    let processingTime: TimeInterval

    /// Model used for transcription
    let modelUsed: WhisperModelType

    /// Timestamp when transcription was performed
    let timestamp: Date

    /// Optional: Confidence score (if available from Whisper)
    let confidence: Float?

    /// Optional: Language detected (for multilingual models)
    let detectedLanguage: String?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        text: String,
        audioDuration: TimeInterval,
        processingTime: TimeInterval,
        modelUsed: WhisperModelType,
        timestamp: Date = Date(),
        confidence: Float? = nil,
        detectedLanguage: String? = nil
    ) {
        self.id = id
        self.text = text
        self.audioDuration = audioDuration
        self.processingTime = processingTime
        self.modelUsed = modelUsed
        self.timestamp = timestamp
        self.confidence = confidence
        self.detectedLanguage = detectedLanguage
    }

    // MARK: - Computed Properties

    /// Speed factor (how many times faster than real-time)
    var speedFactor: Double {
        guard processingTime > 0 else { return 0 }
        return audioDuration / processingTime
    }

    var speedFactorFormatted: String {
        String(format: "%.1fx", speedFactor)
    }

    /// Formatted audio duration
    var audioDurationFormatted: String {
        formatDuration(audioDuration)
    }

    /// Formatted processing time
    var processingTimeFormatted: String {
        formatDuration(processingTime)
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let milliseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 1000)

        if minutes > 0 {
            return String(format: "%d:%02d.%03d", minutes, seconds, milliseconds)
        } else {
            return String(format: "%d.%03d s", seconds, milliseconds)
        }
    }
}

// MARK: - Identifiable

extension TranscriptionResult: Identifiable {}

// MARK: - Equatable

extension TranscriptionResult: Equatable {
    static func == (lhs: TranscriptionResult, rhs: TranscriptionResult) -> Bool {
        lhs.id == rhs.id
    }
}
