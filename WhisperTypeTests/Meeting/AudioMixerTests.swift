//
//  AudioMixerTests.swift
//  WhisperTypeTests
//
//  Unit tests for AudioMixer functionality.
//

import XCTest
@testable import WhisperType

final class AudioMixerTests: XCTestCase {
    
    // MARK: - Mixing Tests
    
    func testMixingTwoEqualLengthArrays() {
        // Given
        let source1: [Float] = [0.5, 0.5, 0.5, 0.5]
        let source2: [Float] = [0.3, 0.3, 0.3, 0.3]
        
        // When
        let mixed = AudioMixer.mix(source1, source2, normalize: false)
        
        // Then
        XCTAssertEqual(mixed.count, 4)
        // With equal weights (0.5 each): 0.5*0.5 + 0.3*0.5 = 0.4
        for sample in mixed {
            XCTAssertEqual(sample, 0.4, accuracy: 0.01)
        }
    }
    
    func testMixingDifferentLengthArrays() {
        // Given - source1 is shorter
        let source1: [Float] = [1.0, 1.0]
        let source2: [Float] = [0.5, 0.5, 0.5, 0.5]
        
        // When
        let mixed = AudioMixer.mix(source1, source2, normalize: false)
        
        // Then - should pad shorter array
        XCTAssertEqual(mixed.count, 4)
        // First two samples: (1.0*0.5 + 0.5*0.5) = 0.75
        XCTAssertEqual(mixed[0], 0.75, accuracy: 0.01)
        XCTAssertEqual(mixed[1], 0.75, accuracy: 0.01)
        // Last two samples: (0*0.5 + 0.5*0.5) = 0.25
        XCTAssertEqual(mixed[2], 0.25, accuracy: 0.01)
        XCTAssertEqual(mixed[3], 0.25, accuracy: 0.01)
    }
    
    func testMixingEmptyArrays() {
        // Given
        let empty: [Float] = []
        let source: [Float] = [0.5, 0.5]
        
        // When
        let result1 = AudioMixer.mix(empty, empty)
        let result2 = AudioMixer.mix(empty, source)
        let result3 = AudioMixer.mix(source, empty)
        
        // Then
        XCTAssertTrue(result1.isEmpty)
        XCTAssertEqual(result2.count, 2)
        XCTAssertEqual(result3.count, 2)
    }
    
    func testMixMicAndSystem() {
        // Given
        let mic: [Float] = [0.4, 0.4, 0.4]
        let system: [Float] = [0.4, 0.4, 0.4]
        
        // When
        let mixed = AudioMixer.mixMicAndSystem(mic: mic, system: system, normalize: false)
        
        // Then
        XCTAssertEqual(mixed.count, 3)
        // Equal weights: 0.4*0.5 + 0.4*0.5 = 0.4
        for sample in mixed {
            XCTAssertEqual(sample, 0.4, accuracy: 0.01)
        }
    }
    
    // MARK: - Normalization Tests
    
    func testNormalizationPreventsClipping() {
        // Given - samples that would clip
        let samples: [Float] = [1.5, -1.5, 1.2, -1.2]
        
        // When
        let normalized = AudioMixer.normalize(samples, peakTarget: 0.9)
        
        // Then - all samples should be within [-0.9, 0.9]
        for sample in normalized {
            XCTAssertLessThanOrEqual(abs(sample), 0.9 + 0.001)
        }
    }
    
    func testNormalizationPreservesLowLevelSignal() {
        // Given - low level signal
        let samples: [Float] = [0.3, -0.3, 0.2, -0.2]
        
        // When
        let normalized = AudioMixer.normalize(samples, peakTarget: 0.9)
        
        // Then - signal should be unchanged (peak 0.3 < 0.9)
        XCTAssertEqual(normalized, samples)
    }
    
    func testNormalizationEmptyArray() {
        // Given
        let empty: [Float] = []
        
        // When
        let normalized = AudioMixer.normalize(empty)
        
        // Then
        XCTAssertTrue(normalized.isEmpty)
    }
    
    // MARK: - Soft Clipping Tests
    
    func testSoftClipBelowThreshold() {
        // Given - samples below threshold
        let samples: [Float] = [0.5, -0.5, 0.7, -0.7]
        
        // When
        let clipped = AudioMixer.softClip(samples, threshold: 0.8)
        
        // Then - should be unchanged
        XCTAssertEqual(clipped, samples)
    }
    
    func testSoftClipAboveThreshold() {
        // Given - samples above threshold
        let samples: [Float] = [1.0, -1.0, 1.5, -1.5]
        
        // When
        let clipped = AudioMixer.softClip(samples, threshold: 0.8)
        
        // Then - should be compressed but maintain sign
        XCTAssertGreaterThan(clipped[0], 0.8)
        XCTAssertLessThan(clipped[0], 1.0)
        XCTAssertLessThan(clipped[1], -0.8)
        XCTAssertGreaterThan(clipped[1], -1.0)
    }
    
    // MARK: - Level Calculation Tests
    
    func testRMSLevel() {
        // Given - known signal
        let samples: [Float] = [1.0, 1.0, 1.0, 1.0]
        
        // When
        let dB = AudioMixer.rmsLevel(samples)
        
        // Then - RMS of [1,1,1,1] = 1.0, dB = 0
        XCTAssertEqual(dB, 0.0, accuracy: 0.1)
    }
    
    func testPeakLevel() {
        // Given
        let samples: [Float] = [0.5, -0.8, 0.3, -0.2]
        
        // When
        let dB = AudioMixer.peakLevel(samples)
        
        // Then - peak is 0.8, dB = 20*log10(0.8) ≈ -1.94
        XCTAssertEqual(dB, -1.94, accuracy: 0.1)
    }
    
    func testRMSLevelEmpty() {
        // Given
        let empty: [Float] = []
        
        // When
        let dB = AudioMixer.rmsLevel(empty)
        
        // Then
        XCTAssertEqual(dB, -Float.infinity)
    }
    
    // MARK: - Resampling Tests
    
    func testResampleSameRate() {
        // Given
        let samples: [Float] = [1.0, 2.0, 3.0, 4.0]
        
        // When
        let resampled = AudioMixer.resample(samples, from: 16000, to: 16000)
        
        // Then - should be unchanged
        XCTAssertEqual(resampled, samples)
    }
    
    func testResampleUpsample() {
        // Given
        let samples: [Float] = [0.0, 1.0]
        
        // When - 2x upsample
        let resampled = AudioMixer.resample(samples, from: 8000, to: 16000)
        
        // Then - should have 4 samples (interpolated)
        XCTAssertEqual(resampled.count, 4)
        XCTAssertEqual(resampled[0], 0.0, accuracy: 0.01)
        XCTAssertEqual(resampled[3], 1.0, accuracy: 0.01)
    }
    
    func testResampleDownsample() {
        // Given
        let samples: [Float] = [0.0, 0.25, 0.5, 0.75, 1.0]
        
        // When - 2x downsample
        let resampled = AudioMixer.resample(samples, from: 16000, to: 8000)
        
        // Then - should have fewer samples
        XCTAssertLessThan(resampled.count, samples.count)
    }
    
    func testResampleEmpty() {
        // Given
        let empty: [Float] = []
        
        // When
        let resampled = AudioMixer.resample(empty, from: 16000, to: 8000)
        
        // Then
        XCTAssertTrue(resampled.isEmpty)
    }
    
    // MARK: - Custom Weight Tests
    
    func testMixingWithCustomWeights() {
        // Given
        let source1: [Float] = [1.0, 1.0]
        let source2: [Float] = [1.0, 1.0]
        
        // When - 70% source1, 30% source2
        let mixed = AudioMixer.mix(source1, source2, weight1: 0.7, weight2: 0.3, normalize: false)
        
        // Then
        XCTAssertEqual(mixed[0], 1.0, accuracy: 0.01) // 0.7 + 0.3 = 1.0
    }
}
