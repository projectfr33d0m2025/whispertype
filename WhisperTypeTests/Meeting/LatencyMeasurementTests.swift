//
//  LatencyMeasurementTests.swift
//  WhisperTypeTests
//
//  Unit tests for LatencyMeasurement.
//

import XCTest
@testable import WhisperType

final class LatencyMeasurementTests: XCTestCase {
    
    var sut: LatencyMeasurement!
    
    override func setUp() {
        super.setUp()
        sut = LatencyMeasurement(targetLatency: 5.0)
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Basic Recording Tests
    
    func testRecordLatency() {
        // Given
        let now = Date()
        let captureTime = now.addingTimeInterval(-2.5)
        
        // When
        sut.record(audioTimestamp: 0, audioCaptureTime: captureTime, transcriptReceiveTime: now)
        
        // Then
        XCTAssertEqual(sut.records.count, 1)
        XCTAssertEqual(sut.averageLatency, 2.5, accuracy: 0.01)
    }
    
    func testRecordLatencyDirect() {
        // When
        sut.recordLatency(3.0, audioTimestamp: 0)
        
        // Then
        XCTAssertEqual(sut.records.count, 1)
        XCTAssertEqual(sut.averageLatency, 3.0, accuracy: 0.1)
    }
    
    // MARK: - Statistics Tests
    
    func testAverageLatency() {
        // Given
        sut.recordLatency(2.0)
        sut.recordLatency(4.0)
        sut.recordLatency(6.0)
        
        // Then
        XCTAssertEqual(sut.averageLatency, 4.0, accuracy: 0.1)
    }
    
    func testMinMaxLatency() {
        // Given
        sut.recordLatency(2.0)
        sut.recordLatency(8.0)
        sut.recordLatency(5.0)
        
        // Then
        XCTAssertEqual(sut.minLatency, 2.0, accuracy: 0.1)
        XCTAssertEqual(sut.maxLatency, 8.0, accuracy: 0.1)
    }
    
    // MARK: - Target Compliance Tests
    
    func testMeetsTargetTrue() {
        // Given - all under 5 seconds
        sut.recordLatency(2.0)
        sut.recordLatency(3.0)
        sut.recordLatency(4.0)
        
        // Then
        XCTAssertTrue(sut.meetsTarget)
    }
    
    func testMeetsTargetFalse() {
        // Given - average over 5 seconds
        sut.recordLatency(6.0)
        sut.recordLatency(7.0)
        sut.recordLatency(8.0)
        
        // Then
        XCTAssertFalse(sut.meetsTarget)
    }
    
    func testTargetComplianceRate() {
        // Given - 2 out of 4 meet target
        sut.recordLatency(2.0)  // pass
        sut.recordLatency(3.0)  // pass
        sut.recordLatency(6.0)  // fail
        sut.recordLatency(7.0)  // fail
        
        // Then
        XCTAssertEqual(sut.targetComplianceRate, 0.5, accuracy: 0.01)
    }
    
    func testLatencyUnderFiveSeconds() {
        // Given - simulate realistic latencies
        sut.recordLatency(2.5)
        sut.recordLatency(3.2)
        sut.recordLatency(4.1)
        sut.recordLatency(3.8)
        sut.recordLatency(2.9)
        
        // Then
        XCTAssertLessThan(sut.averageLatency, 5.0, "Average latency should be under 5 seconds")
        XCTAssertTrue(sut.meetsTarget)
        XCTAssertEqual(sut.targetComplianceRate, 1.0, accuracy: 0.01)
    }
    
    // MARK: - Reset Tests
    
    func testReset() {
        // Given
        sut.recordLatency(3.0)
        sut.recordLatency(4.0)
        XCTAssertEqual(sut.records.count, 2)
        
        // When
        sut.reset()
        
        // Then
        XCTAssertEqual(sut.records.count, 0)
        XCTAssertEqual(sut.averageLatency, 0)
        XCTAssertEqual(sut.maxLatency, 0)
        XCTAssertEqual(sut.minLatency, Double.infinity)
    }
    
    // MARK: - Summary Tests
    
    func testSummary() {
        // Given
        sut.recordLatency(3.0)
        sut.recordLatency(4.0)
        
        // When
        let summary = sut.summary
        
        // Then
        XCTAssertTrue(summary.contains("Measurements: 2"))
        XCTAssertTrue(summary.contains("Average:"))
        XCTAssertTrue(summary.contains("PASS"))
    }
    
    func testSummaryEmpty() {
        // When
        let summary = sut.summary
        
        // Then
        XCTAssertEqual(summary, "No latency measurements recorded")
    }
    
    // MARK: - Edge Cases
    
    func testEmptyRecords() {
        XCTAssertEqual(sut.averageLatency, 0)
        XCTAssertTrue(sut.meetsTarget) // No failures
        XCTAssertEqual(sut.targetComplianceRate, 1.0) // 100% of 0 is 100%
    }
}
