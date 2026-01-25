//
//  MeetingFileManager.swift
//  WhisperType
//
//  File system manager for meeting artifacts.
//  Handles directory creation, file saving/deletion, and storage calculation.
//

import Foundation

// MARK: - File Manager Error

enum MeetingFileError: LocalizedError {
    case directoryCreationFailed(String)
    case fileWriteFailed(String)
    case fileReadFailed(String)
    case deleteFailed(String)
    case directoryNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let path):
            return "Failed to create directory: \(path)"
        case .fileWriteFailed(let path):
            return "Failed to write file: \(path)"
        case .fileReadFailed(let path):
            return "Failed to read file: \(path)"
        case .deleteFailed(let path):
            return "Failed to delete: \(path)"
        case .directoryNotFound(let path):
            return "Directory not found: \(path)"
        }
    }
}

// MARK: - Storage Info

/// Information about storage usage
struct StorageInfo {
    let totalBytes: Int64
    let meetingCount: Int
    let audioBytes: Int64
    let transcriptBytes: Int64
    
    var totalFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
    
    var audioFormatted: String {
        ByteCountFormatter.string(fromByteCount: audioBytes, countStyle: .file)
    }
    
    var transcriptFormatted: String {
        ByteCountFormatter.string(fromByteCount: transcriptBytes, countStyle: .file)
    }
}

// MARK: - Meeting File Manager

/// Manages file system operations for meeting artifacts
class MeetingFileManager {
    
    // MARK: - Singleton
    
    static let shared = MeetingFileManager()
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private let meetingsDirectory: URL
    
    // MARK: - Initialization
    
    init(meetingsDirectory: URL? = nil) {
        self.meetingsDirectory = meetingsDirectory ?? Constants.Paths.meetings
        print("MeetingFileManager: Initialized at \(self.meetingsDirectory.path)")
    }
    
    // MARK: - Directory Operations
    
    /// Create a new session directory for a meeting
    func createSessionDirectory(sessionId: String, date: Date = Date()) throws -> URL {
        let sessionDir = Constants.Paths.meetingSession(id: sessionId, date: date)
        
        if !fileManager.fileExists(atPath: sessionDir.path) {
            try fileManager.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        }
        
        // Also create the audio subdirectory
        let audioDir = sessionDir.appendingPathComponent("audio")
        if !fileManager.fileExists(atPath: audioDir.path) {
            try fileManager.createDirectory(at: audioDir, withIntermediateDirectories: true)
        }
        
        print("MeetingFileManager: Created session directory at \(sessionDir.path)")
        return sessionDir
    }
    
    /// Get the audio directory for a session
    func audioDirectory(for sessionDirectory: URL) -> URL {
        sessionDirectory.appendingPathComponent("audio")
    }
    
    /// Check if a session directory exists
    func sessionExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }
    
    // MARK: - File Operations
    
    /// Save transcript content to a file
    func saveTranscript(_ content: String, to sessionDirectory: URL, format: TranscriptFormat = .markdown) throws -> String {
        let filename: String
        switch format {
        case .markdown:
            filename = "transcript.md"
        case .plainText:
            filename = "transcript.txt"
        case .json:
            filename = "transcript.json"
        }
        
        let fileURL = sessionDirectory.appendingPathComponent(filename)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            print("MeetingFileManager: Saved transcript to \(fileURL.path)")
            return filename
        } catch {
            throw MeetingFileError.fileWriteFailed(fileURL.path)
        }
    }
    
    /// Save summary content to a file
    func saveSummary(_ content: String, to sessionDirectory: URL) throws -> String {
        let filename = "summary.md"
        let fileURL = sessionDirectory.appendingPathComponent(filename)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            print("MeetingFileManager: Saved summary to \(fileURL.path)")
            return filename
        } catch {
            throw MeetingFileError.fileWriteFailed(fileURL.path)
        }
    }
    
    /// Save metadata JSON
    func saveMetadata(_ metadata: [String: Any], to sessionDirectory: URL) throws {
        let fileURL = sessionDirectory.appendingPathComponent("metadata.json")
        
        do {
            let data = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: fileURL)
            print("MeetingFileManager: Saved metadata to \(fileURL.path)")
        } catch {
            throw MeetingFileError.fileWriteFailed(fileURL.path)
        }
    }
    
    /// Read transcript from a session directory
    func readTranscript(from sessionDirectory: URL, format: TranscriptFormat = .markdown) throws -> String {
        let filename: String
        switch format {
        case .markdown:
            filename = "transcript.md"
        case .plainText:
            filename = "transcript.txt"
        case .json:
            filename = "transcript.json"
        }
        
        let fileURL = sessionDirectory.appendingPathComponent(filename)
        
        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw MeetingFileError.fileReadFailed(fileURL.path)
        }
    }
    
    /// Read summary from a session directory
    func readSummary(from sessionDirectory: URL) throws -> String {
        let fileURL = sessionDirectory.appendingPathComponent("summary.md")
        
        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw MeetingFileError.fileReadFailed(fileURL.path)
        }
    }
    
    // MARK: - Deletion Operations
    
    /// Delete a session directory and all its contents
    func deleteSession(at sessionDirectory: URL) throws {
        guard fileManager.fileExists(atPath: sessionDirectory.path) else {
            return // Already deleted
        }
        
        do {
            try fileManager.removeItem(at: sessionDirectory)
            print("MeetingFileManager: Deleted session at \(sessionDirectory.path)")
        } catch {
            throw MeetingFileError.deleteFailed(sessionDirectory.path)
        }
    }
    
    /// Delete only audio files from a session, keeping transcripts and summaries
    func deleteAudioFiles(from sessionDirectory: URL) throws {
        let audioDir = audioDirectory(for: sessionDirectory)
        
        guard fileManager.fileExists(atPath: audioDir.path) else {
            return // No audio directory
        }
        
        do {
            try fileManager.removeItem(at: audioDir)
            print("MeetingFileManager: Deleted audio files from \(sessionDirectory.path)")
        } catch {
            throw MeetingFileError.deleteFailed(audioDir.path)
        }
    }
    
    /// Delete multiple sessions
    func deleteSessions(at directories: [URL]) throws {
        for directory in directories {
            try deleteSession(at: directory)
        }
    }
    
    // MARK: - Storage Calculation
    
    /// Calculate total storage used by all meetings
    func calculateStorageUsage() throws -> StorageInfo {
        var totalBytes: Int64 = 0
        var audioBytes: Int64 = 0
        var transcriptBytes: Int64 = 0
        var meetingCount = 0
        
        guard fileManager.fileExists(atPath: meetingsDirectory.path) else {
            return StorageInfo(totalBytes: 0, meetingCount: 0, audioBytes: 0, transcriptBytes: 0)
        }
        
        let contents = try fileManager.contentsOfDirectory(at: meetingsDirectory, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey])
        
        for item in contents {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                meetingCount += 1
                let (sessionTotal, sessionAudio, sessionTranscript) = try calculateSessionSize(at: item)
                totalBytes += sessionTotal
                audioBytes += sessionAudio
                transcriptBytes += sessionTranscript
            }
        }
        
        return StorageInfo(
            totalBytes: totalBytes,
            meetingCount: meetingCount,
            audioBytes: audioBytes,
            transcriptBytes: transcriptBytes
        )
    }
    
    /// Calculate size of a single session directory
    func calculateSessionSize(at sessionDirectory: URL) throws -> (total: Int64, audio: Int64, transcript: Int64) {
        var totalBytes: Int64 = 0
        var audioBytes: Int64 = 0
        var transcriptBytes: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(at: sessionDirectory, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]) else {
            return (0, 0, 0)
        }
        
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
            
            guard let isDirectory = resourceValues.isDirectory, !isDirectory else { continue }
            guard let fileSize = resourceValues.fileSize else { continue }
            
            totalBytes += Int64(fileSize)
            
            // Categorize by path
            if fileURL.path.contains("/audio/") {
                audioBytes += Int64(fileSize)
            } else if fileURL.pathExtension == "md" || fileURL.pathExtension == "txt" || fileURL.pathExtension == "json" {
                transcriptBytes += Int64(fileSize)
            }
        }
        
        return (totalBytes, audioBytes, transcriptBytes)
    }
    
    /// Get all session directories sorted by size (largest first)
    func getSessionsBySize() throws -> [(URL, Int64)] {
        guard fileManager.fileExists(atPath: meetingsDirectory.path) else {
            return []
        }
        
        let contents = try fileManager.contentsOfDirectory(at: meetingsDirectory, includingPropertiesForKeys: [.isDirectoryKey])
        
        var sessions: [(URL, Int64)] = []
        
        for item in contents {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                let (total, _, _) = try calculateSessionSize(at: item)
                sessions.append((item, total))
            }
        }
        
        // Sort by size descending
        sessions.sort { $0.1 > $1.1 }
        
        return sessions
    }
    
    // MARK: - Cleanup Operations
    
    /// Find orphan session directories (exist on disk but not in database)
    func findOrphanSessions(existingIds: Set<String>) throws -> [URL] {
        guard fileManager.fileExists(atPath: meetingsDirectory.path) else {
            return []
        }
        
        let contents = try fileManager.contentsOfDirectory(at: meetingsDirectory, includingPropertiesForKeys: [.isDirectoryKey])
        
        var orphans: [URL] = []
        
        for item in contents {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                // Extract ID from directory name (format: yyyy-MM-dd_HHmmss_uuid)
                let dirName = item.lastPathComponent
                let components = dirName.split(separator: "_")
                if components.count >= 3 {
                    // The ID is the last component (UUID)
                    let id = String(components.last!)
                    if !existingIds.contains(id) {
                        orphans.append(item)
                    }
                }
            }
        }
        
        return orphans
    }
    
    /// Clean up orphan sessions
    func cleanupOrphanSessions(existingIds: Set<String>) throws -> Int {
        let orphans = try findOrphanSessions(existingIds: existingIds)
        
        for orphan in orphans {
            try deleteSession(at: orphan)
        }
        
        if !orphans.isEmpty {
            print("MeetingFileManager: Cleaned up \(orphans.count) orphan session(s)")
        }
        
        return orphans.count
    }
    
    // MARK: - Utility
    
    /// List all files in a session directory
    func listSessionFiles(at sessionDirectory: URL) throws -> [URL] {
        guard fileManager.fileExists(atPath: sessionDirectory.path) else {
            return []
        }
        
        let contents = try fileManager.contentsOfDirectory(at: sessionDirectory, includingPropertiesForKeys: nil)
        return contents
    }
    
    /// Check if transcript exists for a session
    func hasTranscript(at sessionDirectory: URL) -> Bool {
        let mdPath = sessionDirectory.appendingPathComponent("transcript.md")
        let txtPath = sessionDirectory.appendingPathComponent("transcript.txt")
        return fileManager.fileExists(atPath: mdPath.path) || fileManager.fileExists(atPath: txtPath.path)
    }
    
    /// Check if summary exists for a session
    func hasSummary(at sessionDirectory: URL) -> Bool {
        let summaryPath = sessionDirectory.appendingPathComponent("summary.md")
        return fileManager.fileExists(atPath: summaryPath.path)
    }
    
    /// Check if audio files exist for a session
    func hasAudioFiles(at sessionDirectory: URL) -> Bool {
        let audioDir = audioDirectory(for: sessionDirectory)
        guard fileManager.fileExists(atPath: audioDir.path) else { return false }
        
        if let contents = try? fileManager.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: nil) {
            return !contents.isEmpty
        }
        
        return false
    }
}

// MARK: - Transcript Format

enum TranscriptFormat {
    case markdown
    case plainText
    case json
}
