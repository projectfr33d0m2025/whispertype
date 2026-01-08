//
//  PartialTranscriptStoreTests.swift
//  WhisperTypeTests
//
//  Unit tests for PartialTranscriptStore.
//

import XCTest
@testable import WhisperType

final class PartialTranscriptStoreTests: XCTestCase {
    
    var sut: PartialTranscriptStore!
    var tempDirectory: URL!
    
    @MainActor
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        sut = PartialTranscriptStore(sessionId: "test-session", storageDirectory: tempDirectory)
    }
    
    @MainActor
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        sut = nil
        tempDirectory = nil
        super.tearDown()
    }
    
    // MARK: - Append Tests
    
    @MainActor
    func testAppendAddsEntry() {
        // Given
        let update = TranscriptUpdate(text: "Hello world", timestamp: 0)
        
        // When
        sut.append(update)
        
        // Then
        XCTAssertEqual(sut.entries.count, 1)
        XCTAssertEqual(sut.entries.first?.text, "Hello world")
    }
    
    @MainActor
    func testAppendIgnoresEmptyText() {
        // Given
        let emptyUpdate = TranscriptUpdate(text: "   ", timestamp: 0)
        
        // When
        sut.append(emptyUpdate)
        
        // Then
        XCTAssertEqual(sut.entries.count, 0, "Empty updates should be ignored")
    }
    
    @MainActor
    func testAppendAllAddsMultiple() {
        // Given
        let updates = [
            TranscriptUpdate(text: "First", timestamp: 0),
            TranscriptUpdate(text: "Second", timestamp: 5),
            TranscriptUpdate(text: "Third", timestamp: 10)
        ]
        
        // When
        sut.appendAll(updates)
        
        // Then
        XCTAssertEqual(sut.entries.count, 3)
    }
    
    // MARK: - Get All Tests
    
    @MainActor
    func testGetAllReturnsInOrder() {
        // Given - add in random order
        sut.append(TranscriptUpdate(text: "Third", timestamp: 20))
        sut.append(TranscriptUpdate(text: "First", timestamp: 5))
        sut.append(TranscriptUpdate(text: "Second", timestamp: 10))
        
        // When
        let sorted = sut.getAll()
        
        // Then
        XCTAssertEqual(sorted[0].text, "First")
        XCTAssertEqual(sorted[1].text, "Second")
        XCTAssertEqual(sorted[2].text, "Third")
    }
    
    @MainActor
    func testGetInRange() {
        // Given
        sut.appendAll([
            TranscriptUpdate(text: "One", timestamp: 0),
            TranscriptUpdate(text: "Two", timestamp: 10),
            TranscriptUpdate(text: "Three", timestamp: 20),
            TranscriptUpdate(text: "Four", timestamp: 30)
        ])
        
        // When
        let ranged = sut.getInRange(start: 10, end: 25)
        
        // Then
        XCTAssertEqual(ranged.count, 2)
        XCTAssertTrue(ranged.contains(where: { $0.text == "Two" }))
        XCTAssertTrue(ranged.contains(where: { $0.text == "Three" }))
    }
    
    // MARK: - Clear Tests
    
    @MainActor
    func testClearRemovesAll() {
        // Given
        sut.append(TranscriptUpdate(text: "Hello", timestamp: 0))
        sut.append(TranscriptUpdate(text: "World", timestamp: 5))
        XCTAssertEqual(sut.entries.count, 2)
        
        // When
        sut.clear()
        
        // Then
        XCTAssertEqual(sut.entries.count, 0)
        XCTAssertEqual(sut.wordCount, 0)
    }
    
    // MARK: - Statistics Tests
    
    @MainActor
    func testWordCount() {
        // Given
        sut.append(TranscriptUpdate(text: "Hello world", timestamp: 0))  // 2 words
        sut.append(TranscriptUpdate(text: "This is a test", timestamp: 5))  // 4 words
        
        // Then
        XCTAssertEqual(sut.wordCount, 6)
    }
    
    @MainActor
    func testCombinedText() {
        // Given
        sut.append(TranscriptUpdate(text: "Hello", timestamp: 0))
        sut.append(TranscriptUpdate(text: "World", timestamp: 5))
        
        // Then
        XCTAssertEqual(sut.combinedText, "Hello World")
    }
    
    // MARK: - Persistence Tests
    
    @MainActor
    func testJSONSaveLoadRoundtrip() throws {
        // Given
        let updates = [
            TranscriptUpdate(text: "First entry", timestamp: 0, audioDuration: 5),
            TranscriptUpdate(text: "Second entry", timestamp: 5, audioDuration: 5)
        ]
        sut.appendAll(updates)
        
        // When - save
        try sut.save()
        
        // Create new store and load
        let loadedStore = PartialTranscriptStore(sessionId: "test-session", storageDirectory: tempDirectory)
        try loadedStore.load()
        
        // Then
        XCTAssertEqual(loadedStore.entries.count, 2)
        XCTAssertEqual(loadedStore.entries[0].text, "First entry")
        XCTAssertEqual(loadedStore.entries[1].text, "Second entry")
    }
    
    @MainActor
    func testLoadWithNoFileDoesNotThrow() {
        // Given - new store with empty directory
        let emptyDir = tempDirectory.appendingPathComponent("empty")
        try? FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        let store = PartialTranscriptStore(storageDirectory: emptyDir)
        
        // When/Then - should not throw
        XCTAssertNoThrow(try store.load())
    }
    
    // MARK: - Export Tests
    
    @MainActor
    func testExportToMarkdown() {
        // Given
        sut.append(TranscriptUpdate(text: "Hello world", timestamp: 30))
        
        // When
        let markdown = sut.exportToMarkdown()
        
        // Then
        XCTAssertTrue(markdown.contains("# Live Transcript"))
        XCTAssertTrue(markdown.contains("Hello world"))
        XCTAssertTrue(markdown.contains("[00:30]"))
    }
}
