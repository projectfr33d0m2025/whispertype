//
//  AudioQualityValidatorTests.swift
//  WhisperTypeTests
//
//  Unit tests for AudioQualityValidator.
//

import XCTest
@testable import WhisperType

final class AudioQualityValidatorTests: XCTestCase {
    
    // MARK: - Test Tone Generation
    
    func testGenerateTestTone() {
        // Given
        let frequency: Float = 1000
        let sampleRate: Float = 16000
        let duration: Float = 0.1 // 100ms
        
        // When
        let samples = AudioQualityValidator.generateTestTone(
            frequency: frequency,
            sampleRate: sampleRate,
            duration: duration
        )
        
        // Then
        let expectedCount = Int(sampleRate * duration)
        XCTAssertEqual(samples.count, expectedCount)
        
        // Should be sine wave - check it oscillates
        XCTAssertEqual(samples[0], 0.0, accuracy: 0.01) // sin(0) = 0
    }
    
    // MARK: - Cross-Correlation Tests
    
    func testIdenticalSignalsHaveCorrelation1() {
        // Given
        let signal: [Float] = AudioQualityValidator.generateTestTone(
            frequency: 440,
            sampleRate: 16000,
            duration: 0.5
        )
        
        // When
        let result = AudioQualityValidator.validate(
            reference: signal,
            captured: signal
        )
        
        // Then - identical signals should have correlation very close to 1
        XCTAssertGreaterThan(result.correlation, 0.99)
        XCTAssertTrue(result.passesThreshold)
    }
    
    func testDifferentFrequenciesHaveLowCorrelation() {
        // Given
        let reference = AudioQualityValidator.generateTestTone(
            frequency: 440,
            sampleRate: 16000,
            duration: 0.5
        )
        let captured = AudioQualityValidator.generateTestTone(
            frequency: 880, // Octave higher
            sampleRate: 16000,
            duration: 0.5
        )
        
        // When
        let result = AudioQualityValidator.validate(
            reference: reference,
            captured: captured
        )
        
        // Then - different frequencies should have lower correlation
        XCTAssertLessThan(result.correlation, 0.5)
    }
    
    func testScaledSignalStillCorrelates() {
        // Given
        let reference = AudioQualityValidator.generateTestTone(
            frequency: 440,
            sampleRate: 16000,
            duration: 0.5
        )
        let captured = reference.map { $0 * 0.5 } // Half amplitude
        
        // When
        let result = AudioQualityValidator.validate(
            reference: reference,
            captured: captured
        )
        
        // Then - normalized correlation should still be high
        XCTAssertGreaterThan(result.correlation, 0.99)
    }
    
    func testEmptySignalsValidation() {
        // Given
        let empty: [Float] = []
        let signal: [Float] = [1.0, 2.0, 3.0]
        
        // When
        let result1 = AudioQualityValidator.validate(reference: empty, captured: signal)
        let result2 = AudioQualityValidator.validate(reference: signal, captured: empty)
        let result3 = AudioQualityValidator.validate(reference: empty, captured: empty)
        
        // Then
        XCTAssertEqual(result1.correlation, 0)
        XCTAssertFalse(result1.passesThreshold)
        XCTAssertEqual(result2.correlation, 0)
        XCTAssertEqual(result3.correlation, 0)
    }
    
    // MARK: - Threshold Tests
    
    func testDefaultThreshold() {
        XCTAssertEqual(AudioQualityValidator.defaultThreshold, 0.8)
    }
    
    func testCustomThreshold() {
        // Given
        let signal = AudioQualityValidator.generateTestTone(
            frequency: 440,
            sampleRate: 16000,
            duration: 0.1
        )
        
        // When
        let result = AudioQualityValidator.validate(
            reference: signal,
            captured: signal,
            threshold: 0.95
        )
        
        // Then
        XCTAssertEqual(result.threshold, 0.95)
        XCTAssertTrue(result.passesThreshold)
    }
    
    func testPassesQualityCheck() {
        // Given
        let signal = AudioQualityValidator.generateTestTone(
            frequency: 440,
            sampleRate: 16000,
            duration: 0.5
        )
        
        // When
        let passes = AudioQualityValidator.passesQualityCheck(
            reference: signal,
            captured: signal
        )
        
        // Then
        XCTAssertTrue(passes)
    }
    
    // MARK: - Quality Description Tests
    
    func testQualityDescriptionExcellent() {
        // Given
        let signal: [Float] = [1, 2, 3, 4, 5]
        let result = AudioQualityValidator.validate(reference: signal, captured: signal)
        
        // Then
        XCTAssertEqual(result.qualityDescription, "Excellent")
    }
    
    func testQualityDescriptionLevels() {
        // Create mock results with different correlation levels
        let excellent = AudioQualityResult(
            correlation: 0.96,
            peakOffset: 0,
            referencePeak: 1.0,
            capturedPeak: 1.0,
            passesThreshold: true,
            threshold: 0.8
        )
        XCTAssertEqual(excellent.qualityDescription, "Excellent")
        
        let good = AudioQualityResult(
            correlation: 0.87,
            peakOffset: 0,
            referencePeak: 1.0,
            capturedPeak: 1.0,
            passesThreshold: true,
            threshold: 0.8
        )
        XCTAssertEqual(good.qualityDescription, "Good")
        
        let acceptable = AudioQualityResult(
            correlation: 0.75,
            peakOffset: 0,
            referencePeak: 1.0,
            capturedPeak: 1.0,
            passesThreshold: false,
            threshold: 0.8
        )
        XCTAssertEqual(acceptable.qualityDescription, "Acceptable")
        
        let poor = AudioQualityResult(
            correlation: 0.55,
            peakOffset: 0,
            referencePeak: 1.0,
            capturedPeak: 1.0,
            passesThreshold: false,
            threshold: 0.8
        )
        XCTAssertEqual(poor.qualityDescription, "Poor")
        
        let failed = AudioQualityResult(
            correlation: 0.3,
            peakOffset: 0,
            referencePeak: 1.0,
            capturedPeak: 1.0,
            passesThreshold: false,
            threshold: 0.8
        )
        XCTAssertEqual(failed.qualityDescription, "Failed")
    }
    
    // MARK: - Peak Detection Tests
    
    func testResultContainsPeakValues() {
        // Given
        let reference: [Float] = [0.5, 0.8, 0.3]
        let captured: [Float] = [0.4, 0.6, 0.2]
        
        // When
        let result = AudioQualityValidator.validate(
            reference: reference,
            captured: captured
        )
        
        // Then
        XCTAssertEqual(result.referencePeak, 0.8, accuracy: 0.01)
        XCTAssertEqual(result.capturedPeak, 0.6, accuracy: 0.01)
    }
    
    // MARK: - Offset Tests
    
    func testShiftedSignalDetection() {
        // Given - create pulses with significant overlap
        var reference: [Float] = Array(repeating: 0, count: 100)
        var captured: [Float] = Array(repeating: 0, count: 100)
        
        // Add a pulse in reference at position 30-50
        for i in 30..<50 {
            reference[i] = 1.0
        }
        
        // Add same pulse in captured at position 32-52 (2 sample shift, mostly overlapping)
        for i in 32..<52 {
            captured[i] = 1.0
        }
        
        // When
        let result = AudioQualityValidator.validate(
            reference: reference,
            captured: captured
        )
        
        // Then - should have reasonable correlation (pulses mostly overlap)
        XCTAssertGreaterThan(result.correlation, 0.4)
    }
}
