//
//  TranscriptUpdate.swift
//  WhisperType
//
//  Model representing a single transcript update for live subtitles.
//

import Foundation

/// Represents a single transcript update event
struct TranscriptUpdate: Identifiable, Codable, Equatable {
    
    // MARK: - Properties
    
    /// Unique identifier for this update
    let id: UUID
    
    /// Transcribed text content
    let text: String
    
    /// Timestamp relative to recording start (in seconds)
    let timestamp: TimeInterval
    
    /// When this transcription was produced
    let createdAt: Date
    
    /// Duration of the audio that produced this transcript (in seconds)
    let audioDuration: TimeInterval
    
    // MARK: - Computed Properties
    
    /// Formatted timestamp string [HH:MM:SS]
    var formattedTimestamp: String {
        let hours = Int(timestamp) / 3600
        let minutes = (Int(timestamp) % 3600) / 60
        let seconds = Int(timestamp) % 60
        
        if hours > 0 {
            return String(format: "[%02d:%02d:%02d]", hours, minutes, seconds)
        } else {
            return String(format: "[%02d:%02d]", minutes, seconds)
        }
    }
    
    /// Check if text is empty or whitespace only
    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        text: String,
        timestamp: TimeInterval,
        createdAt: Date = Date(),
        audioDuration: TimeInterval = 0
    ) {
        self.id = id
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.timestamp = timestamp
        self.createdAt = createdAt
        self.audioDuration = audioDuration
    }
    
    // MARK: - Equatable
    
    static func == (lhs: TranscriptUpdate, rhs: TranscriptUpdate) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - TranscriptUpdate Extensions

extension TranscriptUpdate {
    
    /// Create a placeholder update (for testing or UI placeholders)
    static func placeholder(at timestamp: TimeInterval = 0) -> TranscriptUpdate {
        TranscriptUpdate(
            text: "...",
            timestamp: timestamp
        )
    }
    
    /// Extract last N words from text (for context prompt)
    func lastWords(_ count: Int) -> String {
        let words = text.split(separator: " ")
        let lastWords = words.suffix(count)
        return lastWords.joined(separator: " ")
    }
}
