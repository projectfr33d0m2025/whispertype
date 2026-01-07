//
//  ChunkedDiskWriter.swift
//  WhisperType
//
//  Writes audio chunks to disk as WAV files.
//  Manages chunk naming and session directory structure.
//

import Foundation
import Combine

/// Errors that can occur during disk writing
enum ChunkedDiskWriterError: LocalizedError {
    case sessionNotStarted
    case directoryCreationFailed(String)
    case fileWriteFailed(String)
    case invalidChunk
    case diskFull
    
    var errorDescription: String? {
        switch self {
        case .sessionNotStarted:
            return "No recording session has been started"
        case .directoryCreationFailed(let path):
            return "Failed to create directory at: \(path)"
        case .fileWriteFailed(let message):
            return "Failed to write file: \(message)"
        case .invalidChunk:
            return "Invalid audio chunk data"
        case .diskFull:
            return "Not enough disk space to continue recording"
        }
    }
}

/// Writes audio chunks to disk as WAV files
class ChunkedDiskWriter: AudioChunkSubscriber {
    
    // MARK: - Properties
    
    /// Session ID for the current recording
    private(set) var sessionId: String?
    
    /// Directory where chunks are being written
    private(set) var sessionDirectory: URL?
    
    /// Audio directory within the session
    private(set) var audioDirectory: URL?
    
    /// Number of chunks written in this session
    private(set) var chunksWritten: Int = 0
    
    /// Total bytes written in this session
    private(set) var bytesWritten: UInt64 = 0
    
    /// URLs of all chunk files written
    private(set) var chunkURLs: [URL] = []
    
    /// Whether a session is currently active
    var isSessionActive: Bool {
        sessionId != nil
    }
    
    // MARK: - Audio Format Constants
    
    private let sampleRate: Double = Constants.Audio.meetingSampleRate
    private let channels: UInt32 = 1
    private let bitDepth: UInt32 = 16
    
    // MARK: - Initialization
    
    init() {
        print("ChunkedDiskWriter: Initialized")
    }
    
    // MARK: - Session Management
    
    /// Start a new recording session
    /// - Parameter sessionId: Optional session ID (auto-generated if nil)
    /// - Returns: The session directory URL
    @discardableResult
    func startSession(sessionId: String? = nil) throws -> URL {
        let id = sessionId ?? UUID().uuidString
        self.sessionId = id
        
        // Create session directory
        let sessionDir = Constants.Paths.meetingSession(id: id)
        self.sessionDirectory = sessionDir
        
        // Create audio directory
        let audioDir = Constants.Paths.audioChunks(sessionDirectory: sessionDir)
        self.audioDirectory = audioDir
        
        // Reset counters
        chunksWritten = 0
        bytesWritten = 0
        chunkURLs = []
        
        print("ChunkedDiskWriter: Started session \(id) at \(sessionDir.path)")
        
        return sessionDir
    }
    
    /// End the current session
    /// - Returns: Array of URLs to all written chunk files
    func endSession() -> [URL] {
        guard let id = sessionId else { return [] }
        
        print("ChunkedDiskWriter: Ended session \(id) - \(chunksWritten) chunks, \(bytesWritten) bytes")
        
        let urls = chunkURLs
        
        // Reset state
        sessionId = nil
        sessionDirectory = nil
        audioDirectory = nil
        chunksWritten = 0
        bytesWritten = 0
        chunkURLs = []
        
        return urls
    }
    
    /// Cancel the current session and cleanup files
    func cancelSession() {
        guard let sessionDir = sessionDirectory else { return }
        
        print("ChunkedDiskWriter: Cancelling session, removing \(sessionDir.path)")
        
        // Remove session directory and all contents
        try? FileManager.default.removeItem(at: sessionDir)
        
        // Reset state
        sessionId = nil
        sessionDirectory = nil
        audioDirectory = nil
        chunksWritten = 0
        bytesWritten = 0
        chunkURLs = []
    }
    
    // MARK: - Chunk Writing
    
    /// Write an audio chunk to disk
    /// - Parameter chunk: The audio chunk to write
    /// - Returns: URL of the written file
    @discardableResult
    func writeChunk(_ chunk: AudioChunk) throws -> URL {
        guard let audioDir = audioDirectory else {
            throw ChunkedDiskWriterError.sessionNotStarted
        }
        
        guard !chunk.isEmpty else {
            throw ChunkedDiskWriterError.invalidChunk
        }
        
        // Generate chunk filename
        chunksWritten += 1
        let chunkNumber = String(format: "%03d", chunksWritten)
        let filename = "chunk_\(chunkNumber).wav"
        let fileURL = audioDir.appendingPathComponent(filename)
        
        // Write WAV file
        try writeWAVFile(chunk: chunk, to: fileURL)
        
        // Track file
        chunkURLs.append(fileURL)
        
        // Get file size
        if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let fileSize = attributes[.size] as? UInt64 {
            bytesWritten += fileSize
        }
        
        print("ChunkedDiskWriter: Wrote \(filename) - \(chunk.sampleCount) samples, \(String(format: "%.2f", chunk.duration))s")
        
        return fileURL
    }
    
    // MARK: - AudioChunkSubscriber Conformance
    
    func handleChunk(_ chunk: AudioChunk) {
        do {
            try writeChunk(chunk)
        } catch {
            print("ChunkedDiskWriter: Error writing chunk - \(error.localizedDescription)")
        }
    }
    
    func audioStreamDidStart() {
        print("ChunkedDiskWriter: Audio stream started")
    }
    
    func audioStreamDidStop() {
        print("ChunkedDiskWriter: Audio stream stopped")
    }
    
    // MARK: - WAV File Writing
    
    /// Write audio samples to a WAV file
    private func writeWAVFile(chunk: AudioChunk, to url: URL) throws {
        // Convert Float32 samples to Int16
        let int16Data = chunk.dataAsInt16()
        
        // Create WAV header
        let header = createWAVHeader(dataSize: UInt32(int16Data.count))
        
        // Combine header and data
        var fileData = Data()
        fileData.append(header)
        fileData.append(int16Data)
        
        // Write to disk
        do {
            try fileData.write(to: url)
        } catch {
            throw ChunkedDiskWriterError.fileWriteFailed(error.localizedDescription)
        }
    }
    
    /// Create a WAV file header
    private func createWAVHeader(dataSize: UInt32) -> Data {
        var header = Data()
        
        // RIFF header
        header.append(contentsOf: "RIFF".utf8)
        header.append(contentsOf: withUnsafeBytes(of: UInt32(36 + dataSize).littleEndian) { Array($0) })
        header.append(contentsOf: "WAVE".utf8)
        
        // fmt subchunk
        header.append(contentsOf: "fmt ".utf8)
        header.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) }) // Subchunk size
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // Audio format (PCM)
        header.append(contentsOf: withUnsafeBytes(of: UInt16(channels).littleEndian) { Array($0) }) // Channels
        header.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) }) // Sample rate
        
        let byteRate = UInt32(sampleRate) * UInt32(channels) * UInt32(bitDepth / 8)
        header.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) }) // Byte rate
        
        let blockAlign = UInt16(channels * (bitDepth / 8))
        header.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) }) // Block align
        header.append(contentsOf: withUnsafeBytes(of: UInt16(bitDepth).littleEndian) { Array($0) }) // Bits per sample
        
        // data subchunk
        header.append(contentsOf: "data".utf8)
        header.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) }) // Data size
        
        return header
    }
    
    // MARK: - Utility Methods
    
    /// Get the total duration of all chunks
    func totalDuration() -> TimeInterval {
        // Each chunk is approximately 30 seconds
        return TimeInterval(chunksWritten) * Constants.Audio.chunkDurationSeconds
    }
    
    /// Get storage used by current session in bytes
    func storageUsed() -> UInt64 {
        bytesWritten
    }
    
    /// Get storage used by current session as formatted string
    func formattedStorageUsed() -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytesWritten))
    }
}
