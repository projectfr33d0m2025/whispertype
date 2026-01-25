//
//  MeetingFileManagerTests.swift
//  WhisperTypeTests
//
//  Unit tests for MeetingFileManager file operations.
//

import XCTest
@testable import WhisperType

final class MeetingFileManagerTests: XCTestCase {
    
    var fileManager: MeetingFileManager!
    var tempDirectory: URL!
    
    override func setUpWithError() throws {
        // Create a temporary directory for testing
        let tempBase = FileManager.default.temporaryDirectory
        tempDirectory = tempBase.appendingPathComponent("test_meetings_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        fileManager = MeetingFileManager(meetingsDirectory: tempDirectory)
    }
    
    override func tearDownWithError() throws {
        // Clean up temp directory
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        fileManager = nil
    }
    
    // MARK: - Directory Creation Tests
    
    func testCreateSessionDirectory() throws {
        let sessionId = UUID().uuidString
        
        let sessionDir = try fileManager.createSessionDirectory(sessionId: sessionId)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: sessionDir.path))
        
        // Audio subdirectory should also exist
        let audioDir = sessionDir.appendingPathComponent("audio")
        XCTAssertTrue(FileManager.default.fileExists(atPath: audioDir.path))
    }
    
    func testSessionExists() throws {
        let sessionId = UUID().uuidString
        let sessionDir = try fileManager.createSessionDirectory(sessionId: sessionId)
        
        XCTAssertTrue(fileManager.sessionExists(at: sessionDir))
        
        let nonExistent = tempDirectory.appendingPathComponent("non-existent")
        XCTAssertFalse(fileManager.sessionExists(at: nonExistent))
    }
    
    // MARK: - Transcript Tests
    
    func testSaveTranscriptMarkdown() throws {
        let sessionId = UUID().uuidString
        let sessionDir = try fileManager.createSessionDirectory(sessionId: sessionId)
        
        let content = "# Meeting Transcript\n\n[00:00:00]\nHello, this is a test."
        
        let filename = try fileManager.saveTranscript(content, to: sessionDir, format: .markdown)
        
        XCTAssertEqual(filename, "transcript.md")
        
        let savedPath = sessionDir.appendingPathComponent(filename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedPath.path))
        
        let savedContent = try String(contentsOf: savedPath, encoding: .utf8)
        XCTAssertEqual(savedContent, content)
    }
    
    func testSaveTranscriptPlainText() throws {
        let sessionId = UUID().uuidString
        let sessionDir = try fileManager.createSessionDirectory(sessionId: sessionId)
        
        let content = "Plain text transcript"
        
        let filename = try fileManager.saveTranscript(content, to: sessionDir, format: .plainText)
        
        XCTAssertEqual(filename, "transcript.txt")
    }
    
    func testReadTranscript() throws {
        let sessionId = UUID().uuidString
        let sessionDir = try fileManager.createSessionDirectory(sessionId: sessionId)
        
        let originalContent = "# Test Transcript"
        _ = try fileManager.saveTranscript(originalContent, to: sessionDir)
        
        let readContent = try fileManager.readTranscript(from: sessionDir)
        
        XCTAssertEqual(readContent, originalContent)
    }
    
    // MARK: - Summary Tests
    
    func testSaveSummary() throws {
        let sessionId = UUID().uuidString
        let sessionDir = try fileManager.createSessionDirectory(sessionId: sessionId)
        
        let content = "## Summary\n\nThis meeting discussed important topics."
        
        let filename = try fileManager.saveSummary(content, to: sessionDir)
        
        XCTAssertEqual(filename, "summary.md")
        
        let savedPath = sessionDir.appendingPathComponent(filename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedPath.path))
    }
    
    func testReadSummary() throws {
        let sessionId = UUID().uuidString
        let sessionDir = try fileManager.createSessionDirectory(sessionId: sessionId)
        
        let originalContent = "## Summary Content"
        _ = try fileManager.saveSummary(originalContent, to: sessionDir)
        
        let readContent = try fileManager.readSummary(from: sessionDir)
        
        XCTAssertEqual(readContent, originalContent)
    }
    
    // MARK: - Deletion Tests
    
    func testDeleteSession() throws {
        let sessionId = UUID().uuidString
        let sessionDir = try fileManager.createSessionDirectory(sessionId: sessionId)
        
        // Add some files
        _ = try fileManager.saveTranscript("Test", to: sessionDir)
        _ = try fileManager.saveSummary("Summary", to: sessionDir)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: sessionDir.path))
        
        // Delete
        try fileManager.deleteSession(at: sessionDir)
        
        XCTAssertFalse(FileManager.default.fileExists(atPath: sessionDir.path))
    }
    
    func testDeleteAudioFiles() throws {
        let sessionId = UUID().uuidString
        let sessionDir = try fileManager.createSessionDirectory(sessionId: sessionId)
        
        // Create some fake audio files
        let audioDir = sessionDir.appendingPathComponent("audio")
        let audioFile = audioDir.appendingPathComponent("chunk_001.wav")
        FileManager.default.createFile(atPath: audioFile.path, contents: Data())
        
        // Also add transcript
        _ = try fileManager.saveTranscript("Test", to: sessionDir)
        
        XCTAssertTrue(fileManager.hasAudioFiles(at: sessionDir))
        XCTAssertTrue(fileManager.hasTranscript(at: sessionDir))
        
        // Delete only audio
        try fileManager.deleteAudioFiles(from: sessionDir)
        
        XCTAssertFalse(fileManager.hasAudioFiles(at: sessionDir))
        XCTAssertTrue(fileManager.hasTranscript(at: sessionDir)) // Transcript should still exist
    }
    
    // MARK: - Storage Calculation Tests
    
    func testCalculateStorageUsage() throws {
        // Create some sessions with content
        let session1 = try fileManager.createSessionDirectory(sessionId: "session-1")
        _ = try fileManager.saveTranscript("Short transcript", to: session1)
        
        let session2 = try fileManager.createSessionDirectory(sessionId: "session-2")
        _ = try fileManager.saveTranscript(String(repeating: "A", count: 1000), to: session2)
        _ = try fileManager.saveSummary(String(repeating: "B", count: 500), to: session2)
        
        let storage = try fileManager.calculateStorageUsage()
        
        XCTAssertEqual(storage.meetingCount, 2)
        XCTAssertGreaterThan(storage.totalBytes, 0)
        XCTAssertGreaterThan(storage.transcriptBytes, 0)
    }
    
    func testCalculateSessionSize() throws {
        let sessionId = UUID().uuidString
        let sessionDir = try fileManager.createSessionDirectory(sessionId: sessionId)
        
        // Add transcript
        _ = try fileManager.saveTranscript(String(repeating: "X", count: 1000), to: sessionDir)
        
        // Add fake audio
        let audioDir = sessionDir.appendingPathComponent("audio")
        let audioData = Data(repeating: 0, count: 5000)
        try audioData.write(to: audioDir.appendingPathComponent("chunk_001.wav"))
        
        let (total, audio, transcript) = try fileManager.calculateSessionSize(at: sessionDir)
        
        XCTAssertGreaterThanOrEqual(total, 6000) // At least 6000 bytes
        XCTAssertEqual(audio, 5000)
        XCTAssertGreaterThanOrEqual(transcript, 1000)
    }
    
    func testGetSessionsBySize() throws {
        // Create sessions with different sizes
        let session1 = try fileManager.createSessionDirectory(sessionId: "small")
        _ = try fileManager.saveTranscript("Small", to: session1)
        
        let session2 = try fileManager.createSessionDirectory(sessionId: "large")
        _ = try fileManager.saveTranscript(String(repeating: "L", count: 10000), to: session2)
        
        let session3 = try fileManager.createSessionDirectory(sessionId: "medium")
        _ = try fileManager.saveTranscript(String(repeating: "M", count: 1000), to: session3)
        
        let sessions = try fileManager.getSessionsBySize()
        
        XCTAssertEqual(sessions.count, 3)
        // Should be sorted by size descending
        XCTAssertGreaterThanOrEqual(sessions[0].1, sessions[1].1)
        XCTAssertGreaterThanOrEqual(sessions[1].1, sessions[2].1)
    }
    
    // MARK: - Cleanup Tests
    
    func testFindOrphanSessions() throws {
        // Create sessions
        _ = try fileManager.createSessionDirectory(sessionId: "known-1")
        _ = try fileManager.createSessionDirectory(sessionId: "known-2")
        _ = try fileManager.createSessionDirectory(sessionId: "orphan-1")
        
        let existingIds: Set<String> = ["known-1", "known-2"]
        
        let orphans = try fileManager.findOrphanSessions(existingIds: existingIds)
        
        XCTAssertEqual(orphans.count, 1)
        XCTAssertTrue(orphans[0].lastPathComponent.contains("orphan-1"))
    }
    
    func testCleanupOrphanSessions() throws {
        // Create sessions
        _ = try fileManager.createSessionDirectory(sessionId: "keep")
        let orphan = try fileManager.createSessionDirectory(sessionId: "orphan")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: orphan.path))
        
        let cleaned = try fileManager.cleanupOrphanSessions(existingIds: ["keep"])
        
        XCTAssertEqual(cleaned, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path))
    }
    
    // MARK: - Utility Tests
    
    func testHasTranscript() throws {
        let sessionId = UUID().uuidString
        let sessionDir = try fileManager.createSessionDirectory(sessionId: sessionId)
        
        XCTAssertFalse(fileManager.hasTranscript(at: sessionDir))
        
        _ = try fileManager.saveTranscript("Test", to: sessionDir)
        
        XCTAssertTrue(fileManager.hasTranscript(at: sessionDir))
    }
    
    func testHasSummary() throws {
        let sessionId = UUID().uuidString
        let sessionDir = try fileManager.createSessionDirectory(sessionId: sessionId)
        
        XCTAssertFalse(fileManager.hasSummary(at: sessionDir))
        
        _ = try fileManager.saveSummary("Summary", to: sessionDir)
        
        XCTAssertTrue(fileManager.hasSummary(at: sessionDir))
    }
    
    func testHasAudioFiles() throws {
        let sessionId = UUID().uuidString
        let sessionDir = try fileManager.createSessionDirectory(sessionId: sessionId)
        
        XCTAssertFalse(fileManager.hasAudioFiles(at: sessionDir))
        
        // Create fake audio file
        let audioDir = sessionDir.appendingPathComponent("audio")
        FileManager.default.createFile(atPath: audioDir.appendingPathComponent("chunk.wav").path, contents: Data())
        
        XCTAssertTrue(fileManager.hasAudioFiles(at: sessionDir))
    }
    
    func testListSessionFiles() throws {
        let sessionId = UUID().uuidString
        let sessionDir = try fileManager.createSessionDirectory(sessionId: sessionId)
        
        _ = try fileManager.saveTranscript("Test", to: sessionDir)
        _ = try fileManager.saveSummary("Summary", to: sessionDir)
        
        let files = try fileManager.listSessionFiles(at: sessionDir)
        
        // Should have: audio directory, transcript.md, summary.md
        XCTAssertGreaterThanOrEqual(files.count, 2)
    }
}
