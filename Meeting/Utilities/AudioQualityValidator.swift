//
//  AudioQualityValidator.swift
//  WhisperType
//
//  Validates audio quality using cross-correlation.
//  Used to verify system audio capture matches expected content.
//

import Foundation
import Accelerate

/// Results from audio quality validation
struct AudioQualityResult {
    /// Cross-correlation coefficient (0.0 - 1.0)
    let correlation: Float
    
    /// Peak cross-correlation offset (sample shift for best match)
    let peakOffset: Int
    
    /// Peak signal in reference
    let referencePeak: Float
    
    /// Peak signal in captured
    let capturedPeak: Float
    
    /// Whether quality passes threshold
    let passesThreshold: Bool
    
    /// Threshold used for pass/fail
    let threshold: Float
    
    /// Human-readable quality description
    var qualityDescription: String {
        if correlation >= 0.95 {
            return "Excellent"
        } else if correlation >= 0.85 {
            return "Good"
        } else if correlation >= 0.70 {
            return "Acceptable"
        } else if correlation >= 0.50 {
            return "Poor"
        } else {
            return "Failed"
        }
    }
}

/// Validates audio quality through signal comparison
struct AudioQualityValidator {
    
    // MARK: - Configuration
    
    /// Default correlation threshold for passing
    static let defaultThreshold: Float = 0.8
    
    // MARK: - Public Methods
    
    /// Compare captured audio with reference audio
    /// - Parameters:
    ///   - reference: Original/reference audio samples
    ///   - captured: Captured audio samples to validate
    ///   - threshold: Minimum correlation to pass (default 0.8)
    /// - Returns: Validation result with correlation coefficient
    static func validate(
        reference: [Float],
        captured: [Float],
        threshold: Float = defaultThreshold
    ) -> AudioQualityResult {
        guard !reference.isEmpty && !captured.isEmpty else {
            return AudioQualityResult(
                correlation: 0,
                peakOffset: 0,
                referencePeak: 0,
                capturedPeak: 0,
                passesThreshold: false,
                threshold: threshold
            )
        }
        
        // Normalize both signals
        let normalizedRef = normalizeSignal(reference)
        let normalizedCap = normalizeSignal(captured)
        
        // Calculate cross-correlation
        let (correlation, peakOffset) = crossCorrelation(normalizedRef, normalizedCap)
        
        // Get peak levels
        var refPeak: Float = 0
        var capPeak: Float = 0
        vDSP_maxmgv(reference, 1, &refPeak, vDSP_Length(reference.count))
        vDSP_maxmgv(captured, 1, &capPeak, vDSP_Length(captured.count))
        
        return AudioQualityResult(
            correlation: correlation,
            peakOffset: peakOffset,
            referencePeak: refPeak,
            capturedPeak: capPeak,
            passesThreshold: correlation >= threshold,
            threshold: threshold
        )
    }
    
    /// Quick check if audio quality passes threshold
    /// - Parameters:
    ///   - reference: Reference audio
    ///   - captured: Captured audio
    ///   - threshold: Correlation threshold
    /// - Returns: True if correlation >= threshold
    static func passesQualityCheck(
        reference: [Float],
        captured: [Float],
        threshold: Float = defaultThreshold
    ) -> Bool {
        let result = validate(reference: reference, captured: captured, threshold: threshold)
        return result.passesThreshold
    }
    
    // MARK: - Cross-Correlation
    
    /// Calculate normalized cross-correlation
    /// - Parameters:
    ///   - signal1: First signal
    ///   - signal2: Second signal
    /// - Returns: (max correlation coefficient, offset at max)
    private static func crossCorrelation(_ signal1: [Float], _ signal2: [Float]) -> (Float, Int) {
        let n1 = signal1.count
        let n2 = signal2.count
        
        guard n1 > 0 && n2 > 0 else { return (0, 0) }
        
        // Use shorter signal as template, longer as search space
        let template: [Float]
        let search: [Float]
        let isSwapped: Bool
        
        if n1 <= n2 {
            template = signal1
            search = signal2
            isSwapped = false
        } else {
            template = signal2
            search = signal1
            isSwapped = true
        }
        
        let templateLen = template.count
        let searchLen = search.count
        
        // Number of correlation points
        let corrLen = searchLen - templateLen + 1
        guard corrLen > 0 else {
            // Template longer than search - compute single overlap
            return (dotProductNormalized(template, search), 0)
        }
        
        var maxCorr: Float = -1
        var maxOffset = 0
        
        // Slide template across search
        for offset in 0..<corrLen {
            let segment = Array(search[offset..<(offset + templateLen)])
            let corr = dotProductNormalized(template, segment)
            
            if corr > maxCorr {
                maxCorr = corr
                maxOffset = offset
            }
        }
        
        return (max(0, maxCorr), isSwapped ? -maxOffset : maxOffset)
    }
    
    /// Normalized dot product (cosine similarity)
    private static func dotProductNormalized(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count && !a.isEmpty else { return 0 }
        
        var dotProduct: Float = 0
        var magA: Float = 0
        var magB: Float = 0
        
        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        vDSP_dotpr(a, 1, a, 1, &magA, vDSP_Length(a.count))
        vDSP_dotpr(b, 1, b, 1, &magB, vDSP_Length(b.count))
        
        let denominator = sqrt(magA * magB)
        guard denominator > 1e-10 else { return 0 }
        
        return dotProduct / denominator
    }
    
    /// Normalize signal to zero mean and unit variance
    private static func normalizeSignal(_ samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return [] }
        
        // Calculate mean
        var mean: Float = 0
        vDSP_meanv(samples, 1, &mean, vDSP_Length(samples.count))
        
        // Subtract mean
        var centered = [Float](repeating: 0, count: samples.count)
        var negMean = -mean
        vDSP_vsadd(samples, 1, &negMean, &centered, 1, vDSP_Length(samples.count))
        
        // Calculate standard deviation
        var sumOfSquares: Float = 0
        vDSP_dotpr(centered, 1, centered, 1, &sumOfSquares, vDSP_Length(centered.count))
        let stdDev = sqrt(sumOfSquares / Float(samples.count))
        
        // Avoid division by zero
        guard stdDev > 1e-10 else { return centered }
        
        // Divide by stdDev
        var normalized = [Float](repeating: 0, count: samples.count)
        var scale = 1.0 / stdDev
        vDSP_vsmul(centered, 1, &scale, &normalized, 1, vDSP_Length(samples.count))
        
        return normalized
    }
    
    // MARK: - Utility
    
    /// Generate a test tone for validation
    /// - Parameters:
    ///   - frequency: Tone frequency in Hz
    ///   - sampleRate: Sample rate
    ///   - duration: Duration in seconds
    /// - Returns: Audio samples
    static func generateTestTone(frequency: Float, sampleRate: Float, duration: Float) -> [Float] {
        let sampleCount = Int(sampleRate * duration)
        return (0..<sampleCount).map { i in
            sin(2 * .pi * frequency * Float(i) / sampleRate)
        }
    }
}
