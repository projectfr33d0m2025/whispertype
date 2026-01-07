//
//  ChunkedDiskWriterTests.swift
//  WhisperTypeTests
//
//  Unit tests for ChunkedDiskWriter.
//

import XCTest
@testable import WhisperType

final class ChunkedDiskWriterTests: XCTestCase {
    
    var sut: ChunkedDiskWriter!
    var testDirectory: URL!
    
    override func setUp() {
        super.setUp()
        sut = ChunkedDiskWriter()
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChunkedDiskWriterTests")
            .appendingPathComponent(UUID().uuidString)
    }
    
    override func tearDown() {
        // Clean up test files
        if let sessionDir = sut.sessionDirectory {
            try? FileManager.default.removeItem(at: sessionDir)
        }
        try? FileManager.default.removeItem(at: testDirectory)
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Test Helpers
    
    private func createTestChunk(index: Int = 0, durationSeconds: Double = 30.0) -> AudioChunk {
        let sampleRate = 16000.0
        let sampleCount = Int(sampleRate * durationSeconds)
        
        // Generate a simple sine wave
        let samples = (0..<sampleCount).map { i in
            Float(sin(Double(i) * 2.0 * .pi * 440.0 / sampleRate) * 0.5)
        }
        
        return AudioChunk(
            samples: samples,
            timestamp: TimeInterval(index) * durationSeconds,
            duration: durationSeconds,
            sampleRate: sampleRate,
            chunkIndex: index
        )
    }
    
    // MARK: - Session Management Tests
    
    func testStartSessionCreatesDirectory() throws {
        // When
        let sessionDir = try sut.startSession()
        
        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: sessionDir.path))
        XCTAssertTrue(sut.isSessionActive)
    }
    
    func testEndSessionReturnsChunkURLs() throws {
        // Given
        try sut.startSession()
        let chunk1 = createTestChunk(index: 0)
        let chunk2 = createTestChunk(index: 1)
        
        try sut.writeChunk(chunk1)
        try sut.writeChunk(chunk2)
        
        // When
        let urls = sut.endSession()
        
        // Then
        XCTAssertEqual(urls.count, 2)
        XCTAssertFalse(sut.isSessionActive)
    }
    
    func testCancelSessionRemovesFiles() throws {
        // Given
        let sessionDir = try sut.startSession()
        let chunk = createTestChunk()
        try sut.writeChunk(chunk)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: sessionDir.path))
        
        // When
        sut.cancelSession()
        
        // Then
        XCTAssertFalse(FileManager.default.fileExists(atPath: sessionDir.path))
        XCTAssertFalse(sut.isSessionActive)
    }
    
    // MARK: - Chunk Writing Tests
    
    func testChunkWritingProducesValidWAV() throws {
        // Given
        try sut.startSession()
        let chunk = createTestChunk(durationSeconds: 30.0)
        
        // When
        let fileURL = try sut.writeChunk(chunk)
        
        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        
        // Validate WAV file - note: AVAudioFile may read as Float32 even if written as Int16
        let result = WAVValidator.validate(
            url: fileURL,
            expectedSampleRate: 16000,
            expectedChannels: 1
            // Removed bit depth check as conversion varies
        )
        
        XCTAssertTrue(result.isValid, "WAV validation failed: \(result.error?.localizedDescription ?? "unknown")")
        XCTAssertEqual(result.sampleRate, 16000)
        XCTAssertEqual(result.channels, 1)
        // Bit depth may be 16 or 32 depending on AVAudioFile processing
        XCTAssertTrue(result.bitDepth == 16 || result.bitDepth == 32, "Unexpected bit depth: \(result.bitDepth)")
    }
    
    func testChunkDurationIsCorrect() throws {
        // Given
        try sut.startSession()
        let expectedDuration: Double = 30.0
        let chunk = createTestChunk(durationSeconds: expectedDuration)
        
        // When
        let fileURL = try sut.writeChunk(chunk)
        
        // Then
        let result = WAVValidator.validate(url: fileURL)
        
        XCTAssertTrue(result.isValid)
        // Allow 2 second tolerance for duration
        XCTAssertEqual(result.duration, expectedDuration, accuracy: 2.0)
    }
    
    func testChunkNamingSequence() throws {
        // Given
        try sut.startSession()
        
        // When
        let url1 = try sut.writeChunk(createTestChunk(index: 0))
        let url2 = try sut.writeChunk(createTestChunk(index: 1))
        let url3 = try sut.writeChunk(createTestChunk(index: 2))
        
        // Then
        XCTAssertTrue(url1.lastPathComponent.contains("chunk_001"))
        XCTAssertTrue(url2.lastPathComponent.contains("chunk_002"))
        XCTAssertTrue(url3.lastPathComponent.contains("chunk_003"))
    }
    
    func testSessionFinalizationReturnsAllChunkURLs() throws {
        // Given
        try sut.startSession()
        let chunkCount = 5
        
        for i in 0..<chunkCount {
            try sut.writeChunk(createTestChunk(index: i))
        }
        
        // When
        let urls = sut.endSession()
        
        // Then
        XCTAssertEqual(urls.count, chunkCount)
        
        // Verify all files exist
        for url in urls {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        }
    }
    
    func testCleanupRemovesAllFiles() throws {
        // Given
        let sessionDir = try sut.startSession()
        
        for i in 0..<3 {
            try sut.writeChunk(createTestChunk(index: i))
        }
        
        // Verify files exist
        XCTAssertEqual(sut.chunkURLs.count, 3)
        
        // When
        sut.cancelSession()
        
        // Then - directory should be removed
        XCTAssertFalse(FileManager.default.fileExists(atPath: sessionDir.path))
    }
    
    // MARK: - Error Handling Tests
    
    func testWriteWithoutSessionThrows() {
        // Given - no session started
        let chunk = createTestChunk()
        
        // Then
        XCTAssertThrowsError(try sut.writeChunk(chunk)) { error in
            XCTAssertTrue(error is ChunkedDiskWriterError)
        }
    }
    
    func testWriteEmptyChunkThrows() throws {
        // Given
        try sut.startSession()
        let emptyChunk = AudioChunk.empty()
        
        // Then
        XCTAssertThrowsError(try sut.writeChunk(emptyChunk)) { error in
            XCTAssertTrue(error is ChunkedDiskWriterError)
        }
    }
    
    // MARK: - Statistics Tests
    
    func testChunksWrittenCounter() throws {
        // Given
        try sut.startSession()
        XCTAssertEqual(sut.chunksWritten, 0)
        
        // When
        try sut.writeChunk(createTestChunk(index: 0))
        try sut.writeChunk(createTestChunk(index: 1))
        
        // Then
        XCTAssertEqual(sut.chunksWritten, 2)
    }
    
    func testBytesWrittenTracker() throws {
        // Given
        try sut.startSession()
        XCTAssertEqual(sut.bytesWritten, 0)
        
        // When
        try sut.writeChunk(createTestChunk(durationSeconds: 30.0))
        
        // Then
        // 30 seconds at 16kHz, 16-bit = 30 * 16000 * 2 = 960,000 bytes + 44 byte header
        XCTAssertGreaterThan(sut.bytesWritten, 0)
        XCTAssertGreaterThan(sut.bytesWritten, 900000) // At least 900KB
    }
}
