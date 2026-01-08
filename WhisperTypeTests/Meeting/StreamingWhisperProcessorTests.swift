//
//  StreamingWhisperProcessorTests.swift
//  WhisperTypeTests
//
//  Unit tests for StreamingWhisperProcessor.
//

import XCTest
import Combine
@testable import WhisperType

final class StreamingWhisperProcessorTests: XCTestCase {
    
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Configuration Tests
    
    func testDefaultConfiguration() {
        let config = StreamingProcessorConfig.default
        
        XCTAssertEqual(config.bufferDuration, 10.0)
        XCTAssertEqual(config.processingInterval, 5.0)
        XCTAssertEqual(config.contextWordCount, 50)
    }
    
    func testFastConfiguration() {
        let config = StreamingProcessorConfig.fast
        
        XCTAssertEqual(config.bufferDuration, 5.0)
        XCTAssertEqual(config.processingInterval, 3.0)
        XCTAssertEqual(config.contextWordCount, 30)
    }
    
    // MARK: - TranscriptUpdate Tests
    
    func testTranscriptUpdateFormatting() {
        let update = TranscriptUpdate(
            text: "Hello world",
            timestamp: 3661,  // 1:01:01
            audioDuration: 10
        )
        
        XCTAssertEqual(update.formattedTimestamp, "[01:01:01]")
        XCTAssertFalse(update.isEmpty)
    }
    
    func testTranscriptUpdateShortTimestamp() {
        let update = TranscriptUpdate(
            text: "Test",
            timestamp: 75  // 1:15
        )
        
        XCTAssertEqual(update.formattedTimestamp, "[01:15]")
    }
    
    func testTranscriptUpdateEmpty() {
        let update = TranscriptUpdate(text: "   ", timestamp: 0)
        XCTAssertTrue(update.isEmpty)
    }
    
    func testTranscriptUpdateLastWords() {
        let update = TranscriptUpdate(
            text: "The quick brown fox jumps over the lazy dog",
            timestamp: 0
        )
        
        let last3 = update.lastWords(3)
        XCTAssertEqual(last3, "the lazy dog")
    }
    
    func testTranscriptUpdatePlaceholder() {
        let placeholder = TranscriptUpdate.placeholder(at: 30)
        
        XCTAssertEqual(placeholder.text, "...")
        XCTAssertEqual(placeholder.timestamp, 30)
    }
    
    // MARK: - Processor Initialization Tests
    
    @MainActor
    func testProcessorInitialState() {
        let processor = StreamingWhisperProcessor()
        
        XCTAssertFalse(processor.isRunning)
        XCTAssertFalse(processor.isProcessing)
        XCTAssertTrue(processor.transcriptUpdates.isEmpty)
        XCTAssertNil(processor.latestUpdate)
    }
    
    @MainActor
    func testProcessorStartSetsRunning() {
        let processor = StreamingWhisperProcessor()
        
        processor.start()
        XCTAssertTrue(processor.isRunning)
        
        processor.stop()
        XCTAssertFalse(processor.isRunning)
    }
    
    @MainActor
    func testProcessorClear() {
        let processor = StreamingWhisperProcessor()
        
        // Manually inject updates for testing
        processor.start()
        processor.stop()
        
        processor.clear()
        
        XCTAssertTrue(processor.transcriptUpdates.isEmpty)
        XCTAssertNil(processor.latestUpdate)
    }
    
    // MARK: - Buffer Accumulation Tests
    
    func testBufferAccumulationTiming() {
        // Verify configuration values
        let config = StreamingProcessorConfig.default
        
        // 10 seconds at 16kHz = 160,000 samples
        let expectedSamples = Int(config.bufferDuration * Constants.Audio.meetingSampleRate)
        XCTAssertEqual(expectedSamples, 160000)
        
        // Processing every 5 seconds
        XCTAssertEqual(config.processingInterval, 5.0)
    }
    
    // MARK: - Full Transcript Tests
    
    @MainActor
    func testFullTranscript() {
        let processor = StreamingWhisperProcessor()
        
        // This tests the fullTranscript property without actual processing
        // Since we can't easily inject mock updates, we verify the empty state
        XCTAssertEqual(processor.fullTranscript, "")
    }
    
    // MARK: - Subscription Tests
    
    @MainActor
    func testSubscribeToUpdates() {
        let processor = StreamingWhisperProcessor()
        var receivedUpdates: [TranscriptUpdate] = []
        
        let cancellable = processor.subscribeToUpdates { update in
            receivedUpdates.append(update)
        }
        
        // Store cancellable
        cancellables.insert(cancellable)
        
        // Subscription should be active
        XCTAssertNotNil(cancellable)
    }
}
