//
//  AudioMixer.swift
//  WhisperType
//
//  Mixes microphone and system audio streams.
//  Handles normalization to prevent clipping.
//

import Foundation
import Accelerate

/// Audio mixing errors
enum AudioMixerError: LocalizedError {
    case emptyInput
    case invalidSampleRate
    
    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Cannot mix empty audio arrays"
        case .invalidSampleRate:
            return "Invalid sample rate for conversion"
        }
    }
}

/// Mixes multiple audio sources into a single output
struct AudioMixer {
    
    // MARK: - Configuration
    
    /// Default peak target for normalization (0.9 = 90% of max)
    static let defaultPeakTarget: Float = 0.9
    
    /// Mixing weight for each source (0.5 = equal weight)
    static let defaultMixWeight: Float = 0.5
    
    // MARK: - Public Methods
    
    /// Mix two audio sources together
    /// - Parameters:
    ///   - source1: First audio source samples
    ///   - source2: Second audio source samples
    ///   - weight1: Weight for source1 (0.0 - 1.0)
    ///   - weight2: Weight for source2 (0.0 - 1.0)
    ///   - normalize: Whether to normalize to prevent clipping
    /// - Returns: Mixed audio samples
    static func mix(
        _ source1: [Float],
        _ source2: [Float],
        weight1: Float = defaultMixWeight,
        weight2: Float = defaultMixWeight,
        normalize: Bool = true
    ) -> [Float] {
        // Handle empty inputs
        if source1.isEmpty && source2.isEmpty {
            return []
        }
        if source1.isEmpty {
            return normalize ? Self.normalize(source2) : source2
        }
        if source2.isEmpty {
            return normalize ? Self.normalize(source1) : source1
        }
        
        // Pad shorter array with zeros
        let maxLength = max(source1.count, source2.count)
        var padded1 = source1
        var padded2 = source2
        
        if padded1.count < maxLength {
            padded1.append(contentsOf: Array(repeating: 0, count: maxLength - padded1.count))
        }
        if padded2.count < maxLength {
            padded2.append(contentsOf: Array(repeating: 0, count: maxLength - padded2.count))
        }
        
        // Apply weights and add using vDSP for performance
        var weighted1 = [Float](repeating: 0, count: maxLength)
        var weighted2 = [Float](repeating: 0, count: maxLength)
        var mixed = [Float](repeating: 0, count: maxLength)
        
        var w1 = weight1
        var w2 = weight2
        
        // Scale source1 by weight1
        vDSP_vsmul(padded1, 1, &w1, &weighted1, 1, vDSP_Length(maxLength))
        
        // Scale source2 by weight2
        vDSP_vsmul(padded2, 1, &w2, &weighted2, 1, vDSP_Length(maxLength))
        
        // Add weighted arrays
        vDSP_vadd(weighted1, 1, weighted2, 1, &mixed, 1, vDSP_Length(maxLength))
        
        // Normalize if requested
        if normalize {
            return Self.normalize(mixed)
        }
        
        return mixed
    }
    
    /// Mix microphone and system audio for meeting recording
    /// - Parameters:
    ///   - mic: Microphone audio samples
    ///   - system: System audio samples
    ///   - normalize: Whether to normalize output
    /// - Returns: Mixed audio samples
    static func mixMicAndSystem(
        mic: [Float],
        system: [Float],
        normalize: Bool = true
    ) -> [Float] {
        // Equal weights for both sources
        return mix(mic, system, weight1: 0.5, weight2: 0.5, normalize: normalize)
    }
    
    /// Normalize audio samples to prevent clipping
    /// - Parameters:
    ///   - samples: Input audio samples
    ///   - peakTarget: Target peak level (0.0 - 1.0)
    /// - Returns: Normalized samples
    static func normalize(_ samples: [Float], peakTarget: Float = defaultPeakTarget) -> [Float] {
        guard !samples.isEmpty else { return [] }
        
        // Find peak value using vDSP
        var peak: Float = 0
        vDSP_maxmgv(samples, 1, &peak, vDSP_Length(samples.count))
        
        // If peak is already below target, return as-is
        guard peak > peakTarget else { return samples }
        
        // Calculate scale factor
        let scale = peakTarget / peak
        
        // Apply scaling using vDSP
        var scaled = [Float](repeating: 0, count: samples.count)
        var s = scale
        vDSP_vsmul(samples, 1, &s, &scaled, 1, vDSP_Length(samples.count))
        
        return scaled
    }
    
    /// Soft clip samples to prevent hard clipping
    /// Uses tanh for smooth compression
    /// - Parameters:
    ///   - samples: Input audio samples
    ///   - threshold: Threshold above which to apply soft clipping
    /// - Returns: Soft-clipped samples
    static func softClip(_ samples: [Float], threshold: Float = 0.8) -> [Float] {
        guard !samples.isEmpty else { return [] }
        
        return samples.map { sample in
            let absVal = abs(sample)
            if absVal <= threshold {
                return sample
            } else {
                // Use tanh for soft saturation above threshold
                let sign: Float = sample >= 0 ? 1 : -1
                let compressed = threshold + (1 - threshold) * tanh((absVal - threshold) / (1 - threshold))
                return sign * compressed
            }
        }
    }
    
    /// Calculate RMS (Root Mean Square) level
    /// - Parameter samples: Audio samples
    /// - Returns: RMS level in dB
    static func rmsLevel(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return -Float.infinity }
        
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        
        let dB = 20 * log10(max(rms, 1e-7))
        return dB
    }
    
    /// Calculate peak level
    /// - Parameter samples: Audio samples
    /// - Returns: Peak level in dB
    static func peakLevel(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return -Float.infinity }
        
        var peak: Float = 0
        vDSP_maxmgv(samples, 1, &peak, vDSP_Length(samples.count))
        
        let dB = 20 * log10(max(peak, 1e-7))
        return dB
    }
    
    // MARK: - Sample Rate Conversion
    
    /// Resample audio to a target sample rate (basic linear interpolation)
    /// For high-quality resampling, use AVAudioConverter
    /// - Parameters:
    ///   - samples: Input samples
    ///   - sourceSampleRate: Original sample rate
    ///   - targetSampleRate: Desired sample rate
    /// - Returns: Resampled audio
    static func resample(
        _ samples: [Float],
        from sourceSampleRate: Double,
        to targetSampleRate: Double
    ) -> [Float] {
        guard !samples.isEmpty else { return [] }
        guard sourceSampleRate > 0 && targetSampleRate > 0 else { return samples }
        
        // If same rate, return as-is
        if abs(sourceSampleRate - targetSampleRate) < 1 {
            return samples
        }
        
        let ratio = targetSampleRate / sourceSampleRate
        let outputLength = Int(Double(samples.count) * ratio)
        
        guard outputLength > 0 else { return [] }
        
        var output = [Float](repeating: 0, count: outputLength)
        
        // Linear interpolation resampling
        for i in 0..<outputLength {
            let sourceIndex = Double(i) / ratio
            let lowerIndex = Int(sourceIndex)
            let upperIndex = min(lowerIndex + 1, samples.count - 1)
            let fraction = Float(sourceIndex - Double(lowerIndex))
            
            output[i] = samples[lowerIndex] * (1 - fraction) + samples[upperIndex] * fraction
        }
        
        return output
    }
}
