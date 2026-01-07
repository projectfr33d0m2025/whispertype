//
//  WAVValidator.swift
//  WhisperType
//
//  Utility for validating WAV file headers and audio properties.
//

import Foundation
import AVFoundation

/// WAV file validation errors
enum WAVValidationError: LocalizedError {
    case fileNotFound
    case invalidHeader
    case unsupportedFormat
    case invalidSampleRate(expected: Double, actual: Double)
    case invalidChannels(expected: Int, actual: Int)
    case invalidBitDepth(expected: Int, actual: Int)
    case durationMismatch(expected: TimeInterval, actual: TimeInterval, tolerance: TimeInterval)
    case readError(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "WAV file not found"
        case .invalidHeader:
            return "Invalid WAV file header"
        case .unsupportedFormat:
            return "Unsupported WAV format"
        case .invalidSampleRate(let expected, let actual):
            return "Invalid sample rate: expected \(Int(expected)) Hz, got \(Int(actual)) Hz"
        case .invalidChannels(let expected, let actual):
            return "Invalid channels: expected \(expected), got \(actual)"
        case .invalidBitDepth(let expected, let actual):
            return "Invalid bit depth: expected \(expected)-bit, got \(actual)-bit"
        case .durationMismatch(let expected, let actual, let tolerance):
            return "Duration mismatch: expected \(String(format: "%.2f", expected))s ±\(String(format: "%.2f", tolerance))s, got \(String(format: "%.2f", actual))s"
        case .readError(let message):
            return "WAV read error: \(message)"
        }
    }
}

/// Result of WAV file validation
struct WAVValidationResult {
    let isValid: Bool
    let sampleRate: Double
    let channels: Int
    let bitDepth: Int
    let duration: TimeInterval
    let fileSize: UInt64
    let error: WAVValidationError?
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// Utility for validating WAV files
struct WAVValidator {
    
    // MARK: - Public Methods
    
    /// Validate a WAV file at the given URL
    /// - Parameters:
    ///   - url: Path to the WAV file
    ///   - expectedSampleRate: Expected sample rate (optional)
    ///   - expectedChannels: Expected number of channels (optional)
    ///   - expectedBitDepth: Expected bit depth (optional)
    ///   - expectedDuration: Expected duration (optional)
    ///   - durationTolerance: Tolerance for duration matching (default 2 seconds)
    /// - Returns: WAVValidationResult with validation details
    static func validate(
        url: URL,
        expectedSampleRate: Double? = nil,
        expectedChannels: Int? = nil,
        expectedBitDepth: Int? = nil,
        expectedDuration: TimeInterval? = nil,
        durationTolerance: TimeInterval = 2.0
    ) -> WAVValidationResult {
        // Check file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            return WAVValidationResult(
                isValid: false,
                sampleRate: 0,
                channels: 0,
                bitDepth: 0,
                duration: 0,
                fileSize: 0,
                error: .fileNotFound
            )
        }
        
        // Get file size
        let fileSize: UInt64
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            fileSize = attributes[.size] as? UInt64 ?? 0
        } catch {
            fileSize = 0
        }
        
        // Try to read audio file properties
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let format = audioFile.processingFormat
            
            let sampleRate = format.sampleRate
            let channels = Int(format.channelCount)
            let duration = Double(audioFile.length) / sampleRate
            
            // Determine bit depth from common format
            let bitDepth: Int
            if format.commonFormat == .pcmFormatInt16 {
                bitDepth = 16
            } else if format.commonFormat == .pcmFormatInt32 {
                bitDepth = 32
            } else if format.commonFormat == .pcmFormatFloat32 {
                bitDepth = 32
            } else if format.commonFormat == .pcmFormatFloat64 {
                bitDepth = 64
            } else {
                bitDepth = 16 // Default assumption
            }
            
            // Validate expected values
            if let expected = expectedSampleRate, abs(sampleRate - expected) > 1 {
                return WAVValidationResult(
                    isValid: false,
                    sampleRate: sampleRate,
                    channels: channels,
                    bitDepth: bitDepth,
                    duration: duration,
                    fileSize: fileSize,
                    error: .invalidSampleRate(expected: expected, actual: sampleRate)
                )
            }
            
            if let expected = expectedChannels, channels != expected {
                return WAVValidationResult(
                    isValid: false,
                    sampleRate: sampleRate,
                    channels: channels,
                    bitDepth: bitDepth,
                    duration: duration,
                    fileSize: fileSize,
                    error: .invalidChannels(expected: expected, actual: channels)
                )
            }
            
            if let expected = expectedBitDepth, bitDepth != expected {
                return WAVValidationResult(
                    isValid: false,
                    sampleRate: sampleRate,
                    channels: channels,
                    bitDepth: bitDepth,
                    duration: duration,
                    fileSize: fileSize,
                    error: .invalidBitDepth(expected: expected, actual: bitDepth)
                )
            }
            
            if let expected = expectedDuration {
                let difference = abs(duration - expected)
                if difference > durationTolerance {
                    return WAVValidationResult(
                        isValid: false,
                        sampleRate: sampleRate,
                        channels: channels,
                        bitDepth: bitDepth,
                        duration: duration,
                        fileSize: fileSize,
                        error: .durationMismatch(expected: expected, actual: duration, tolerance: durationTolerance)
                    )
                }
            }
            
            // All validations passed
            return WAVValidationResult(
                isValid: true,
                sampleRate: sampleRate,
                channels: channels,
                bitDepth: bitDepth,
                duration: duration,
                fileSize: fileSize,
                error: nil
            )
            
        } catch {
            return WAVValidationResult(
                isValid: false,
                sampleRate: 0,
                channels: 0,
                bitDepth: 0,
                duration: 0,
                fileSize: fileSize,
                error: .readError(error.localizedDescription)
            )
        }
    }
    
    /// Validate a chunk file for meeting recording format
    /// - Parameter url: Path to the chunk file
    /// - Returns: WAVValidationResult
    static func validateChunk(url: URL) -> WAVValidationResult {
        validate(
            url: url,
            expectedSampleRate: Constants.Audio.meetingSampleRate,
            expectedChannels: 1,
            expectedBitDepth: 16,
            expectedDuration: Constants.Audio.chunkDurationSeconds,
            durationTolerance: 4.0 // Allow some variance for chunk boundaries
        )
    }
    
    /// Check if a file is a valid WAV file (basic check)
    /// - Parameter url: Path to the file
    /// - Returns: true if the file appears to be a valid WAV
    static func isValidWAV(url: URL) -> Bool {
        validate(url: url).isValid
    }
    
    /// Get duration of a WAV file
    /// - Parameter url: Path to the WAV file
    /// - Returns: Duration in seconds, or nil if invalid
    static func duration(of url: URL) -> TimeInterval? {
        let result = validate(url: url)
        return result.isValid ? result.duration : nil
    }
}
