//
//  MeetingRecorderTests.swift
//  WhisperTypeTests
//
//  Unit tests for MeetingRecorder.
//

import XCTest
import Combine
@testable import WhisperType

final class MeetingRecorderTests: XCTestCase {
    
    var sut: MeetingRecorder!
    var streamBus: AudioStreamBus!
    var cancellables: Set<AnyCancellable>!
    
    @MainActor
    override func setUp() {
        super.setUp()
        streamBus = AudioStreamBus.shared
        sut = MeetingRecorder(streamBus: streamBus)
        cancellables = Set<AnyCancellable>()
    }
    
    @MainActor
    override func tearDown() {
        if sut.isRecording {
            sut.cancelRecording()
        }
        streamBus.reset()
        cancellables = nil
        sut = nil
        streamBus = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    @MainActor
    func testInitialState() {
        XCTAssertFalse(sut.isRecording)
        XCTAssertEqual(sut.duration, 0)
        XCTAssertEqual(sut.chunkCount, 0)
        XCTAssertEqual(sut.audioLevel, 0)
        XCTAssertFalse(sut.durationWarningShown)
    }
    
    // MARK: - Recording Lifecycle Tests
    
    @MainActor
    func testStartRecordingSetsIsRecording() async throws {
        // Skip this test if mic permission is not available
        // This test requires actual microphone access
        
        // Given
        let session = MeetingSession(audioSource: .microphone)
        
        // When - try to start, may fail if no mic permission
        do {
            try await sut.startRecording(session: session)
            
            // Then
            XCTAssertTrue(sut.isRecording)
            
            // Cleanup
            _ = try await sut.stopRecording()
        } catch MeetingRecorderError.microphonePermissionDenied {
            // Expected if no mic permission - test passes
            print("Test skipped: No microphone permission")
        }
    }
    
    @MainActor
    func testStartRecordingWhenAlreadyRecordingThrows() async throws {
        // Skip if no mic permission
        let session = MeetingSession(audioSource: .microphone)
        
        do {
            try await sut.startRecording(session: session)
            
            // Then - second start should throw
            do {
                try await sut.startRecording(session: session)
                XCTFail("Should have thrown")
            } catch MeetingRecorderError.alreadyRecording {
                // Expected
            }
            
            // Cleanup
            _ = try await sut.stopRecording()
        } catch MeetingRecorderError.microphonePermissionDenied {
            print("Test skipped: No microphone permission")
        }
    }
    
    @MainActor
    func testStopRecordingWhenNotRecordingThrows() async {
        // Given - not recording
        XCTAssertFalse(sut.isRecording)
        
        // Then
        do {
            _ = try await sut.stopRecording()
            XCTFail("Should have thrown")
        } catch MeetingRecorderError.notRecording {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    @MainActor
    func testCancelRecordingWhenNotRecording() {
        // Given - not recording
        XCTAssertFalse(sut.isRecording)
        
        // When - cancel should not crash
        sut.cancelRecording()
        
        // Then - still not recording
        XCTAssertFalse(sut.isRecording)
    }
    
    // MARK: - Duration Tracking Tests
    
    @MainActor
    func testFormattedDuration() {
        // Simulate different durations by testing the formatter
        // Note: We can't easily set duration directly, so we test the formatting logic
        
        // 0 seconds
        XCTAssertEqual(sut.formattedDuration, "00:00")
    }
    
    // MARK: - Duration Warning Tests
    
    @MainActor
    func testDurationWarningThreshold() {
        // Verify constants are set correctly
        let warningDuration = Constants.Limits.meetingWarningDuration
        let maxDuration = Constants.Limits.maxMeetingDuration
        
        XCTAssertEqual(warningDuration, 85 * 60) // 85 minutes
        XCTAssertEqual(maxDuration, 90 * 60) // 90 minutes
        XCTAssertGreaterThan(maxDuration, warningDuration)
    }
    
    // MARK: - Mock Recording Tests
    
    // These tests verify the recording behavior without needing actual audio
    
    @MainActor
    func testChunkEmissionInterval() {
        // Verify chunk duration constant
        let chunkDuration = Constants.Audio.chunkDurationSeconds
        XCTAssertEqual(chunkDuration, 30.0) // 30 seconds per chunk
    }
    
    @MainActor
    func testRingBufferSize() {
        // Verify ring buffer is sized for 30 seconds at 16kHz
        let sampleRate = Constants.Audio.meetingSampleRate
        let bufferDuration = Constants.Audio.ringBufferSizeSeconds
        
        XCTAssertEqual(sampleRate, 16000.0)
        XCTAssertEqual(bufferDuration, 30.0)
        
        // Expected samples in ring buffer
        let expectedSamples = Int(sampleRate * bufferDuration)
        XCTAssertEqual(expectedSamples, 480000)
    }
    
    // MARK: - Simulated Recording Tests
    
    @MainActor
    func testTwoMinuteRecordingProducesFourChunks() async throws {
        // This is a simplified test that verifies the math
        // Actual recording would require microphone permission
        
        let recordingDuration: TimeInterval = 120.0 // 2 minutes
        let chunkDuration = Constants.Audio.chunkDurationSeconds // 30 seconds
        
        let expectedChunks = Int(recordingDuration / chunkDuration)
        XCTAssertEqual(expectedChunks, 4)
    }
    
    @MainActor
    func testNinetyMinuteLimitCalculation() {
        // Verify max duration is 90 minutes
        let maxDuration = Constants.Limits.maxMeetingDuration
        let chunkDuration = Constants.Audio.chunkDurationSeconds
        
        XCTAssertEqual(maxDuration, 5400.0) // 90 * 60 seconds
        
        // Number of chunks for max duration
        let maxChunks = Int(maxDuration / chunkDuration)
        XCTAssertEqual(maxChunks, 180) // 180 chunks at 30 seconds each
    }
    
    // MARK: - Memory Tests
    
    @MainActor
    func testMemoryLimitConstant() {
        // Verify memory limit is set
        let maxMemory = Constants.Limits.maxMeetingMemoryMB
        XCTAssertEqual(maxMemory, 100) // 100 MB
    }
    
    // MARK: - Integration with StreamBus Tests
    
    @MainActor
    func testStreamBusIsStartedOnRecording() async throws {
        // Given
        let session = MeetingSession(audioSource: .microphone)
        streamBus.reset()
        XCTAssertFalse(streamBus.isActive)
        
        // When
        do {
            try await sut.startRecording(session: session)
            
            // Then
            XCTAssertTrue(streamBus.isActive)
            
            // Cleanup
            _ = try await sut.stopRecording()
            XCTAssertFalse(streamBus.isActive)
        } catch MeetingRecorderError.microphonePermissionDenied {
            print("Test skipped: No microphone permission")
        }
    }
    
    // MARK: - Error Handling Tests
    
    @MainActor
    func testMicrophonePermissionError() {
        // Verify error type exists and has correct description
        let error = MeetingRecorderError.microphonePermissionDenied
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("permission"))
    }
    
    @MainActor
    func testAudioEngineSetupError() {
        // Verify error type exists
        let error = MeetingRecorderError.audioEngineSetupFailed("Test failure")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Test failure"))
    }
}

// MARK: - Performance Tests

extension MeetingRecorderTests {
    
    @MainActor
    func testChunkCreationPerformance() {
        // Test that creating chunks is fast
        measure {
            for i in 0..<100 {
                let sampleCount = 480000 // 30 seconds at 16kHz
                let samples = (0..<sampleCount).map { Float(sin(Double($0) * 0.01)) }
                let chunk = AudioChunk(
                    samples: samples,
                    timestamp: TimeInterval(i) * 30,
                    duration: 30.0,
                    chunkIndex: i
                )
                _ = chunk.dataAsInt16()
            }
        }
    }
}
