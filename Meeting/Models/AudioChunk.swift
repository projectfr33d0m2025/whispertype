//
//  AudioChunk.swift
//  WhisperType
//
//  Represents a chunk of audio data for meeting recording.
//  Used by AudioStreamBus to distribute audio to subscribers.
//

import Foundation

/// Represents a chunk of audio data with metadata
struct AudioChunk: Identifiable, Equatable {
    
    // MARK: - Properties
    
    /// Unique identifier for this chunk
    let id: UUID
    
    /// Audio samples in Float32 format (Whisper-compatible)
    let samples: [Float]
    
    /// Timestamp when this chunk was captured (relative to recording start)
    let timestamp: TimeInterval
    
    /// Duration of this chunk in seconds
    let duration: TimeInterval
    
    /// Sample rate of the audio
    let sampleRate: Double
    
    /// Index of this chunk within the session (0-based)
    let chunkIndex: Int
    
    // MARK: - Computed Properties
    
    /// Number of samples in this chunk
    var sampleCount: Int {
        samples.count
    }
    
    /// Check if chunk is empty (no audio data)
    var isEmpty: Bool {
        samples.isEmpty
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        samples: [Float],
        timestamp: TimeInterval,
        duration: TimeInterval,
        sampleRate: Double = Constants.Audio.meetingSampleRate,
        chunkIndex: Int = 0
    ) {
        self.id = id
        self.samples = samples
        self.timestamp = timestamp
        self.duration = duration
        self.sampleRate = sampleRate
        self.chunkIndex = chunkIndex
    }
    
    // MARK: - Convenience Initializers
    
    /// Create an empty chunk (for testing or placeholders)
    static func empty(at timestamp: TimeInterval = 0, index: Int = 0) -> AudioChunk {
        AudioChunk(
            samples: [],
            timestamp: timestamp,
            duration: 0,
            chunkIndex: index
        )
    }
    
    // MARK: - Equatable
    
    static func == (lhs: AudioChunk, rhs: AudioChunk) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - AudioChunk Extensions

extension AudioChunk {
    
    /// Convert samples to 16-bit integer format for WAV file writing
    func samplesAsInt16() -> [Int16] {
        samples.map { sample in
            // Clamp to [-1, 1] range and convert to Int16
            let clamped = max(-1.0, min(1.0, sample))
            return Int16(clamped * Float(Int16.max))
        }
    }
    
    /// Get the data as raw bytes for WAV file writing (16-bit PCM)
    func dataAsInt16() -> Data {
        let int16Samples = samplesAsInt16()
        return int16Samples.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
    }
}
