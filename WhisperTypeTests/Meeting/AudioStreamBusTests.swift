//
//  AudioStreamBusTests.swift
//  WhisperTypeTests
//
//  Unit tests for AudioStreamBus.
//

import XCTest
import Combine
@testable import WhisperType

final class AudioStreamBusTests: XCTestCase {
    
    var sut: AudioStreamBus!
    var cancellables: Set<AnyCancellable>!
    
    @MainActor
    override func setUp() {
        super.setUp()
        // Create a fresh instance for testing (can't use singleton in tests)
        // Note: In production, use AudioStreamBus.shared
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Test Helpers
    
    private func createTestChunk(index: Int = 0, sampleCount: Int = 1000) -> AudioChunk {
        let samples = (0..<sampleCount).map { Float(sin(Double($0) * 0.01)) }
        return AudioChunk(
            samples: samples,
            timestamp: TimeInterval(index) * 30.0,
            duration: 30.0,
            sampleRate: 16000.0,
            chunkIndex: index
        )
    }
    
    // MARK: - SingleSubscriber Tests
    
    @MainActor
    func testSingleSubscriberReceivesChunks() async {
        // Given
        let sut = AudioStreamBus.shared
        let expectation = XCTestExpectation(description: "Subscriber receives chunk")
        var receivedChunk: AudioChunk?
        
        sut.start()
        
        let subscription = sut.subscribeToChunks { chunk in
            receivedChunk = chunk
            expectation.fulfill()
        }
        
        // When
        let testChunk = createTestChunk()
        sut.publish(chunk: testChunk)
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        
        XCTAssertNotNil(receivedChunk)
        XCTAssertEqual(receivedChunk?.id, testChunk.id)
        XCTAssertEqual(receivedChunk?.sampleCount, testChunk.sampleCount)
        
        subscription.cancel()
        sut.stop()
    }
    
    // MARK: - Multiple Subscribers Tests
    
    @MainActor
    func testMultipleSubscribersReceiveSameChunks() async {
        // Given
        let sut = AudioStreamBus.shared
        let expectation1 = XCTestExpectation(description: "Subscriber 1 receives chunk")
        let expectation2 = XCTestExpectation(description: "Subscriber 2 receives chunk")
        
        var receivedChunk1: AudioChunk?
        var receivedChunk2: AudioChunk?
        
        sut.start()
        
        let subscription1 = sut.subscribeToChunks { chunk in
            receivedChunk1 = chunk
            expectation1.fulfill()
        }
        
        let subscription2 = sut.subscribeToChunks { chunk in
            receivedChunk2 = chunk
            expectation2.fulfill()
        }
        
        // When
        let testChunk = createTestChunk()
        sut.publish(chunk: testChunk)
        
        // Then
        await fulfillment(of: [expectation1, expectation2], timeout: 1.0)
        
        XCTAssertNotNil(receivedChunk1)
        XCTAssertNotNil(receivedChunk2)
        XCTAssertEqual(receivedChunk1?.id, receivedChunk2?.id)
        XCTAssertEqual(receivedChunk1?.id, testChunk.id)
        
        subscription1.cancel()
        subscription2.cancel()
        sut.stop()
    }
    
    // MARK: - Unsubscribe Tests
    
    @MainActor
    func testUnsubscribeStopsReceiving() async {
        // Given
        let sut = AudioStreamBus.shared
        var receivedCount = 0
        
        sut.start()
        
        let subscription = sut.subscribeToChunks { _ in
            receivedCount += 1
        }
        
        // When - publish first chunk
        sut.publish(chunk: createTestChunk(index: 0))
        
        // Wait for delivery
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Cancel subscription
        subscription.cancel()
        
        // Publish second chunk
        sut.publish(chunk: createTestChunk(index: 1))
        
        // Wait for potential delivery
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Then - should only have received 1 chunk
        XCTAssertEqual(receivedCount, 1)
        
        sut.stop()
    }
    
    // MARK: - Level Publishing Tests
    
    @MainActor
    func testLevelPublishing() async {
        // Given
        let sut = AudioStreamBus.shared
        let expectation = XCTestExpectation(description: "Level received")
        var receivedLevel: AudioLevel?
        
        sut.start()
        
        let subscription = sut.subscribeToLevels { level in
            receivedLevel = level
            expectation.fulfill()
        }
        
        // When
        let testLevel = AudioLevel.microphone(-20.0)
        sut.publish(level: testLevel)
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        
        XCTAssertNotNil(receivedLevel)
        XCTAssertEqual(receivedLevel?.microphoneLevel, -20.0)
        
        subscription.cancel()
        sut.stop()
    }
    
    // MARK: - State Tests
    
    @MainActor
    func testChunkCountIncrementsOnPublish() async {
        // Given
        let sut = AudioStreamBus.shared
        sut.reset()
        sut.start()
        
        XCTAssertEqual(sut.chunkCount, 0)
        
        // When
        sut.publish(chunk: createTestChunk(index: 0))
        sut.publish(chunk: createTestChunk(index: 1))
        sut.publish(chunk: createTestChunk(index: 2))
        
        // Then
        XCTAssertEqual(sut.chunkCount, 3)
        
        sut.stop()
    }
    
    @MainActor
    func testStartSetsIsActive() {
        let sut = AudioStreamBus.shared
        sut.reset()
        
        XCTAssertFalse(sut.isActive)
        
        sut.start()
        XCTAssertTrue(sut.isActive)
        
        sut.stop()
        XCTAssertFalse(sut.isActive)
    }
    
    @MainActor
    func testPublishWhenInactiveDoesNothing() {
        let sut = AudioStreamBus.shared
        sut.reset()
        
        // Ensure not active
        XCTAssertFalse(sut.isActive)
        
        // Publish without starting
        sut.publish(chunk: createTestChunk())
        
        // Chunk count should remain 0
        XCTAssertEqual(sut.chunkCount, 0)
    }
}
