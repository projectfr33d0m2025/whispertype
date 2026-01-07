//
//  MeetingSessionTests.swift
//  WhisperTypeTests
//
//  Unit tests for MeetingSession state machine.
//

import XCTest
@testable import WhisperType

final class MeetingSessionTests: XCTestCase {
    
    var sut: MeetingSession!
    
    override func setUp() {
        super.setUp()
        sut = MeetingSession(audioSource: .microphone)
    }
    
    override func tearDown() {
        // Clean up session directory if created
        if FileManager.default.fileExists(atPath: sut.sessionDirectory.path) {
            try? FileManager.default.removeItem(at: sut.sessionDirectory)
        }
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitializationWithDefaults() {
        // Given/When
        let session = MeetingSession()
        
        // Then
        XCTAssertEqual(session.state, .idle)
        XCTAssertEqual(session.processingStage, .none)
        XCTAssertEqual(session.audioSource, .both)
        XCTAssertEqual(session.duration, 0)
        XCTAssertEqual(session.speakerCount, 0)
        XCTAssertNil(session.errorMessage)
        XCTAssertFalse(session.title.isEmpty)
    }
    
    func testInitializationWithCustomValues() {
        // Given
        let title = "Test Meeting"
        let audioSource: AudioSource = .system
        
        // When
        let session = MeetingSession(title: title, audioSource: audioSource)
        
        // Then
        XCTAssertEqual(session.title, title)
        XCTAssertEqual(session.audioSource, audioSource)
    }
    
    // MARK: - Valid State Transitions
    
    func testTransitionIdleToRecording() throws {
        // Given
        XCTAssertEqual(sut.state, .idle)
        
        // When
        try sut.transition(to: .recording)
        
        // Then
        XCTAssertEqual(sut.state, .recording)
    }
    
    func testTransitionRecordingToPaused() throws {
        // Given
        try sut.transition(to: .recording)
        
        // When
        try sut.transition(to: .paused)
        
        // Then
        XCTAssertEqual(sut.state, .paused)
    }
    
    func testTransitionRecordingToProcessing() throws {
        // Given
        try sut.transition(to: .recording)
        
        // When
        try sut.transition(to: .processing)
        
        // Then
        XCTAssertEqual(sut.state, .processing)
    }
    
    func testTransitionPausedToRecording() throws {
        // Given
        try sut.transition(to: .recording)
        try sut.transition(to: .paused)
        
        // When
        try sut.transition(to: .recording)
        
        // Then
        XCTAssertEqual(sut.state, .recording)
    }
    
    func testTransitionPausedToProcessing() throws {
        // Given
        try sut.transition(to: .recording)
        try sut.transition(to: .paused)
        
        // When
        try sut.transition(to: .processing)
        
        // Then
        XCTAssertEqual(sut.state, .processing)
    }
    
    func testTransitionProcessingToComplete() throws {
        // Given
        try sut.transition(to: .recording)
        try sut.transition(to: .processing)
        
        // When
        try sut.transition(to: .complete)
        
        // Then
        XCTAssertEqual(sut.state, .complete)
    }
    
    func testTransitionRecordingToError() throws {
        // Given
        try sut.transition(to: .recording)
        
        // When
        try sut.transition(to: .error)
        
        // Then
        XCTAssertEqual(sut.state, .error)
    }
    
    func testTransitionErrorToIdle() throws {
        // Given
        try sut.transition(to: .recording)
        try sut.transition(to: .error)
        
        // When
        try sut.transition(to: .idle)
        
        // Then
        XCTAssertEqual(sut.state, .idle)
    }
    
    func testTransitionErrorToRecording() throws {
        // Given
        try sut.transition(to: .recording)
        try sut.transition(to: .error)
        
        // When
        try sut.transition(to: .recording)
        
        // Then
        XCTAssertEqual(sut.state, .recording)
    }
    
    func testTransitionCompleteToIdle() throws {
        // Given
        try sut.transition(to: .recording)
        try sut.transition(to: .processing)
        try sut.transition(to: .complete)
        
        // When
        try sut.transition(to: .idle)
        
        // Then
        XCTAssertEqual(sut.state, .idle)
    }
    
    // MARK: - Invalid State Transitions
    
    func testInvalidTransitionIdleToPaused() {
        // Given
        XCTAssertEqual(sut.state, .idle)
        
        // Then
        XCTAssertThrowsError(try sut.transition(to: .paused)) { error in
            XCTAssertTrue(error is MeetingStateError)
            if case .invalidTransition(let from, let to) = error as! MeetingStateError {
                XCTAssertEqual(from, .idle)
                XCTAssertEqual(to, .paused)
            }
        }
    }
    
    func testInvalidTransitionIdleToProcessing() {
        // Given
        XCTAssertEqual(sut.state, .idle)
        
        // Then
        XCTAssertThrowsError(try sut.transition(to: .processing)) { error in
            XCTAssertTrue(error is MeetingStateError)
        }
    }
    
    func testInvalidTransitionIdleToComplete() {
        // Given
        XCTAssertEqual(sut.state, .idle)
        
        // Then
        XCTAssertThrowsError(try sut.transition(to: .complete)) { error in
            XCTAssertTrue(error is MeetingStateError)
        }
    }
    
    func testInvalidTransitionProcessingToPaused() throws {
        // Given
        try sut.transition(to: .recording)
        try sut.transition(to: .processing)
        
        // Then
        XCTAssertThrowsError(try sut.transition(to: .paused)) { error in
            XCTAssertTrue(error is MeetingStateError)
        }
    }
    
    func testInvalidTransitionCompleteToRecording() throws {
        // Given
        try sut.transition(to: .recording)
        try sut.transition(to: .processing)
        try sut.transition(to: .complete)
        
        // Then
        XCTAssertThrowsError(try sut.transition(to: .recording)) { error in
            XCTAssertTrue(error is MeetingStateError)
        }
    }
    
    func testTransitionToSameStateThrows() throws {
        // Given
        try sut.transition(to: .recording)
        
        // Then
        XCTAssertThrowsError(try sut.transition(to: .recording)) { error in
            if case .alreadyInState(let state) = error as! MeetingStateError {
                XCTAssertEqual(state, .recording)
            }
        }
    }
    
    // MARK: - canTransition Tests
    
    func testCanTransitionReturnsCorrectValues() throws {
        // Idle state
        XCTAssertTrue(sut.canTransition(to: .recording))
        XCTAssertFalse(sut.canTransition(to: .paused))
        XCTAssertFalse(sut.canTransition(to: .processing))
        XCTAssertFalse(sut.canTransition(to: .complete))
        XCTAssertFalse(sut.canTransition(to: .idle)) // Same state
        
        // Recording state
        try sut.transition(to: .recording)
        XCTAssertTrue(sut.canTransition(to: .paused))
        XCTAssertTrue(sut.canTransition(to: .processing))
        XCTAssertTrue(sut.canTransition(to: .error))
        XCTAssertFalse(sut.canTransition(to: .idle))
        XCTAssertFalse(sut.canTransition(to: .complete))
    }
    
    // MARK: - Processing Stage Tests
    
    func testSetProcessingStageOnlyWorksInProcessingState() throws {
        // Given - not in processing state
        XCTAssertEqual(sut.processingStage, .none)
        
        // When - try to set stage
        sut.setProcessingStage(.transcribing)
        
        // Then - should not change
        XCTAssertEqual(sut.processingStage, .none)
        
        // Given - in processing state
        try sut.transition(to: .recording)
        try sut.transition(to: .processing)
        
        // When
        sut.setProcessingStage(.transcribing)
        
        // Then
        XCTAssertEqual(sut.processingStage, .transcribing)
    }
    
    func testProcessingStageSequence() throws {
        // Given
        try sut.transition(to: .recording)
        try sut.transition(to: .processing)
        
        // When/Then
        sut.setProcessingStage(.transcribing)
        XCTAssertEqual(sut.processingStage, .transcribing)
        XCTAssertEqual(sut.processingStage.progress, 0.25)
        
        sut.setProcessingStage(.diarizing)
        XCTAssertEqual(sut.processingStage, .diarizing)
        XCTAssertEqual(sut.processingStage.progress, 0.50)
        
        sut.setProcessingStage(.summarizing)
        XCTAssertEqual(sut.processingStage, .summarizing)
        XCTAssertEqual(sut.processingStage.progress, 0.75)
        
        sut.setProcessingStage(.complete)
        XCTAssertEqual(sut.processingStage, .complete)
        XCTAssertEqual(sut.processingStage.progress, 1.0)
    }
    
    // MARK: - Duration Tests
    
    func testUpdateDuration() {
        // Given
        XCTAssertEqual(sut.duration, 0)
        
        // When
        sut.updateDuration(60.0)
        
        // Then
        XCTAssertEqual(sut.duration, 60.0)
    }
    
    func testFormattedDuration() {
        // Given/When/Then
        sut.updateDuration(65.0) // 1:05
        XCTAssertEqual(sut.formattedDuration, "01:05")
        
        sut.updateDuration(3665.0) // 1:01:05
        XCTAssertEqual(sut.formattedDuration, "1:01:05")
    }
    
    func testTimeRemaining() {
        // Given
        let maxDuration = Constants.Limits.maxMeetingDuration // 90 minutes
        
        // When at 0 duration
        sut.updateDuration(0)
        XCTAssertEqual(sut.timeRemaining, maxDuration)
        
        // When at 85 minutes (5 min remaining)
        sut.updateDuration(85 * 60)
        XCTAssertEqual(sut.timeRemaining, 5 * 60, accuracy: 1.0)
        
        // When at 90 minutes
        sut.updateDuration(90 * 60)
        XCTAssertEqual(sut.timeRemaining, 0)
    }
    
    func testShouldShowDurationWarning() {
        // Given - before 85 minutes
        sut.updateDuration(84 * 60)
        XCTAssertFalse(sut.shouldShowDurationWarning)
        
        // When - at 85 minutes
        sut.updateDuration(85 * 60)
        XCTAssertTrue(sut.shouldShowDurationWarning)
        
        // When - between 85 and 90 minutes
        sut.updateDuration(87 * 60)
        XCTAssertTrue(sut.shouldShowDurationWarning)
        
        // When - at 90 minutes (max reached)
        sut.updateDuration(90 * 60)
        XCTAssertFalse(sut.shouldShowDurationWarning) // No warning needed, already at max
    }
    
    func testHasReachedMaxDuration() {
        // Given - before max
        sut.updateDuration(89 * 60)
        XCTAssertFalse(sut.hasReachedMaxDuration)
        
        // When - at max
        sut.updateDuration(90 * 60)
        XCTAssertTrue(sut.hasReachedMaxDuration)
        
        // When - over max
        sut.updateDuration(91 * 60)
        XCTAssertTrue(sut.hasReachedMaxDuration)
    }
    
    // MARK: - Error Handling Tests
    
    func testSetErrorTransitionsToErrorState() throws {
        // Given
        try sut.transition(to: .recording)
        
        // When
        sut.setError("Test error message")
        
        // Then
        XCTAssertEqual(sut.state, .error)
        XCTAssertEqual(sut.errorMessage, "Test error message")
    }
    
    func testErrorMessageClearedOnTransition() throws {
        // Given
        try sut.transition(to: .recording)
        sut.setError("Test error")
        XCTAssertEqual(sut.state, .error)
        XCTAssertEqual(sut.errorMessage, "Test error")
        
        // When
        try sut.transition(to: .idle)
        
        // Then
        XCTAssertNil(sut.errorMessage)
    }
    
    // MARK: - isActive Tests
    
    func testIsActiveForDifferentStates() throws {
        // Idle is not active
        XCTAssertFalse(sut.state.isActive)
        
        // Recording is active
        try sut.transition(to: .recording)
        XCTAssertTrue(sut.state.isActive)
        
        // Paused is active
        try sut.transition(to: .paused)
        XCTAssertTrue(sut.state.isActive)
        
        // Processing is active
        try sut.transition(to: .processing)
        XCTAssertTrue(sut.state.isActive)
        
        // Complete is not active
        try sut.transition(to: .complete)
        XCTAssertFalse(sut.state.isActive)
    }
    
    // MARK: - Codable Tests
    
    func testEncodeDecode() throws {
        // Given
        try sut.transition(to: .recording)
        sut.updateDuration(120.0)
        sut.speakerCount = 3
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(sut)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MeetingSession.self, from: data)
        
        // Then
        XCTAssertEqual(decoded.id, sut.id)
        XCTAssertEqual(decoded.title, sut.title)
        XCTAssertEqual(decoded.state, sut.state)
        XCTAssertEqual(decoded.duration, sut.duration)
        XCTAssertEqual(decoded.speakerCount, sut.speakerCount)
        XCTAssertEqual(decoded.audioSource, sut.audioSource)
    }
}
