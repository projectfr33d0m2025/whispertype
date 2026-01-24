// AudioFeatureExtractor.swift
// Speaker Diarization Spike - Swift-only approach validation
//
// Purpose: Extract simple audio features for speaker clustering
// Features: Energy, ZCR, Spectral Centroid, Spectral Rolloff, Spectral Flatness, Pitch

import Foundation
import Accelerate

/// Represents a segment of audio with extracted features
struct AudioSegment {
    let startTime: Double
    let endTime: Double
    let features: [Float]  // Feature vector for this segment
}

/// Extracts audio features for speaker diarization
class AudioFeatureExtractor {
    
    // MARK: - Configuration
    
    private let sampleRate: Float = 16000
    private let windowSize: Int = 512          // 32ms window
    private let hopSize: Int = 256             // 16ms hop
    private let segmentDuration: Double = 1.0  // 1-second segments for clustering
    private let silenceThreshold: Float = 0.001
    
    // MARK: - Public API
    
    /// Load WAV file and return raw samples
    /// Assumes 16-bit PCM mono WAV at 16kHz
    func loadWAV(url: URL) throws -> [Float] {
        let data = try Data(contentsOf: url)
        
        // Parse WAV header to get format info
        guard data.count > 44 else {
            throw AudioFeatureError.invalidWAVFile("File too small to be valid WAV")
        }
        
        // Verify RIFF header
        let riff = String(data: data[0..<4], encoding: .ascii)
        guard riff == "RIFF" else {
            throw AudioFeatureError.invalidWAVFile("Missing RIFF header")
        }
        
        // Verify WAVE format
        let wave = String(data: data[8..<12], encoding: .ascii)
        guard wave == "WAVE" else {
            throw AudioFeatureError.invalidWAVFile("Missing WAVE format")
        }
        
        // Find data chunk (skip header, may have extra chunks)
        var dataOffset = 12
        var dataSize = 0
        
        while dataOffset < data.count - 8 {
            let chunkID = String(data: data[dataOffset..<dataOffset+4], encoding: .ascii)
            let chunkSize = data[dataOffset+4..<dataOffset+8].withUnsafeBytes { 
                $0.load(as: UInt32.self) 
            }
            
            if chunkID == "data" {
                dataOffset += 8
                dataSize = Int(chunkSize)
                break
            }
            
            dataOffset += 8 + Int(chunkSize)
        }
        
        guard dataSize > 0 else {
            throw AudioFeatureError.invalidWAVFile("No data chunk found")
        }
        
        // Convert 16-bit samples to Float
        let sampleData = data[dataOffset..<dataOffset+dataSize]
        let samples = sampleData.withUnsafeBytes { buffer -> [Float] in
            let int16Samples = buffer.bindMemory(to: Int16.self)
            return int16Samples.map { Float($0) / Float(Int16.max) }
        }
        
        return samples
    }
    
    /// Extract features for each segment (1-second by default)
    /// Skips silent segments automatically
    func extractSegmentFeatures(samples: [Float]) -> [AudioSegment] {
        let samplesPerSegment = Int(segmentDuration * Double(sampleRate))
        let totalSegments = samples.count / samplesPerSegment
        
        var segments: [AudioSegment] = []
        
        for i in 0..<totalSegments {
            let startSample = i * samplesPerSegment
            let endSample = min(startSample + samplesPerSegment, samples.count)
            let segmentSamples = Array(samples[startSample..<endSample])
            
            // Skip silent segments
            let energy = computeEnergy(segmentSamples)
            if energy < silenceThreshold {
                continue
            }
            
            let features = extractFeatures(segmentSamples)
            
            let segment = AudioSegment(
                startTime: Double(startSample) / Double(sampleRate),
                endTime: Double(endSample) / Double(sampleRate),
                features: features
            )
            segments.append(segment)
        }
        
        return segments
    }
    
    // MARK: - Feature Extraction
    
    /// Extract all features from an audio segment
    /// Returns: [energy, zcr, spectralCentroid, spectralRolloff, spectralFlatness, pitch]
    private func extractFeatures(_ samples: [Float]) -> [Float] {
        var features: [Float] = []
        
        // 1. Energy (RMS)
        let energy = computeEnergy(samples)
        features.append(energy)
        
        // 2. Zero Crossing Rate
        let zcr = computeZeroCrossingRate(samples)
        features.append(zcr)
        
        // 3. Spectral features (from FFT)
        let spectrum = computeSpectrum(samples)
        
        // Spectral Centroid - "brightness" of sound
        let centroid = computeSpectralCentroid(spectrum)
        features.append(centroid)
        
        // Spectral Rolloff - frequency below which 85% of energy is contained
        let rolloff = computeSpectralRolloff(spectrum, percentile: 0.85)
        features.append(rolloff)
        
        // Spectral Flatness - how "noisy" vs "tonal" the sound is
        let flatness = computeSpectralFlatness(spectrum)
        features.append(flatness)
        
        // 4. Simple pitch estimate (dominant frequency)
        let pitch = estimatePitch(samples)
        features.append(pitch)
        
        return features
    }
    
    // MARK: - Feature Computation Helpers
    
    /// Compute RMS energy of samples
    private func computeEnergy(_ samples: [Float]) -> Float {
        var sumSquares: Float = 0
        vDSP_svesq(samples, 1, &sumSquares, vDSP_Length(samples.count))
        return sqrt(sumSquares / Float(samples.count))
    }
    
    /// Compute zero crossing rate (useful for voiced/unvoiced detection)
    private func computeZeroCrossingRate(_ samples: [Float]) -> Float {
        var crossings = 0
        for i in 1..<samples.count {
            if (samples[i] >= 0) != (samples[i-1] >= 0) {
                crossings += 1
            }
        }
        return Float(crossings) / Float(samples.count)
    }
    
    /// Compute magnitude spectrum using FFT
    private func computeSpectrum(_ samples: [Float]) -> [Float] {
        let fftSize = 512
        var paddedSamples = samples
        
        // Pad or truncate to FFT size
        if paddedSamples.count < fftSize {
            paddedSamples.append(contentsOf: [Float](repeating: 0, count: fftSize - paddedSamples.count))
        } else if paddedSamples.count > fftSize {
            paddedSamples = Array(paddedSamples.prefix(fftSize))
        }
        
        // Apply Hann window to reduce spectral leakage
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        var windowedSamples = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(paddedSamples, 1, window, 1, &windowedSamples, vDSP_Length(fftSize))
        
        // FFT setup
        let log2n = vDSP_Length(log2(Float(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return []
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        // Convert to split complex format
        var realPart = [Float](repeating: 0, count: fftSize/2)
        var imagPart = [Float](repeating: 0, count: fftSize/2)
        
        windowedSamples.withUnsafeBufferPointer { inputPtr in
            realPart.withUnsafeMutableBufferPointer { realPtr in
                imagPart.withUnsafeMutableBufferPointer { imagPtr in
                    var splitComplex = DSPSplitComplex(
                        realp: realPtr.baseAddress!,
                        imagp: imagPtr.baseAddress!
                    )
                    
                    // Pack input into split complex
                    inputPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize/2) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize/2))
                    }
                    
                    // Perform FFT
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                }
            }
        }
        
        // Compute magnitudes
        var magnitudes = [Float](repeating: 0, count: fftSize/2)
        realPart.withUnsafeMutableBufferPointer { realPtr in
            imagPart.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(
                    realp: realPtr.baseAddress!,
                    imagp: imagPtr.baseAddress!
                )
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize/2))
            }
        }
        
        // Convert to dB scale for better dynamic range
        var one: Float = 1e-10  // Small value to avoid log(0)
        vDSP_vsadd(magnitudes, 1, &one, &magnitudes, 1, vDSP_Length(fftSize/2))
        var twentyOverLog10: Float = 20.0 / log(10.0)
        vDSP_vdbcon(magnitudes, 1, &one, &magnitudes, 1, vDSP_Length(fftSize/2), 1)
        
        return magnitudes
    }
    
    /// Compute spectral centroid (center of mass of spectrum)
    private func computeSpectralCentroid(_ spectrum: [Float]) -> Float {
        guard !spectrum.isEmpty else { return 0 }
        
        var weightedSum: Float = 0
        var totalEnergy: Float = 0
        
        for (i, magnitude) in spectrum.enumerated() {
            let linearMag = pow(10, magnitude / 20)  // Convert from dB
            weightedSum += Float(i) * linearMag
            totalEnergy += linearMag
        }
        
        return totalEnergy > 0 ? weightedSum / totalEnergy : 0
    }
    
    /// Compute spectral rolloff point
    private func computeSpectralRolloff(_ spectrum: [Float], percentile: Float) -> Float {
        guard !spectrum.isEmpty else { return 0 }
        
        let linearSpectrum = spectrum.map { pow(10, $0 / 20) }
        let totalEnergy = linearSpectrum.reduce(0, +)
        let threshold = totalEnergy * percentile
        
        var cumulative: Float = 0
        for (i, energy) in linearSpectrum.enumerated() {
            cumulative += energy
            if cumulative >= threshold {
                return Float(i) / Float(spectrum.count)
            }
        }
        return 1.0
    }
    
    /// Compute spectral flatness (Wiener entropy)
    private func computeSpectralFlatness(_ spectrum: [Float]) -> Float {
        guard !spectrum.isEmpty else { return 0 }
        
        let linearSpectrum = spectrum.map { max(pow(10, $0 / 20), 1e-10) }
        let sum = linearSpectrum.reduce(0, +)
        let arithmeticMean = sum / Float(linearSpectrum.count)
        
        // Geometric mean (use log to avoid overflow)
        let logSum = linearSpectrum.map { log($0) }.reduce(0, +)
        let geometricMean = exp(logSum / Float(linearSpectrum.count))
        
        return arithmeticMean > 0 ? geometricMean / arithmeticMean : 0
    }
    
    /// Estimate fundamental frequency using autocorrelation
    private func estimatePitch(_ samples: [Float]) -> Float {
        // Pitch range: 50 Hz to 500 Hz
        let minLag = Int(sampleRate / 500)   // Max pitch 500 Hz
        let maxLag = Int(sampleRate / 50)    // Min pitch 50 Hz
        
        guard maxLag < samples.count / 2 else { return 0 }
        
        var maxCorrelation: Float = 0
        var bestLag = 0
        
        // Simple autocorrelation
        for lag in minLag..<min(maxLag, samples.count / 2) {
            var correlation: Float = 0
            let length = samples.count - lag
            
            vDSP_dotpr(
                samples, 1,
                Array(samples[lag..<samples.count]), 1,
                &correlation,
                vDSP_Length(length)
            )
            
            // Normalize by length
            correlation /= Float(length)
            
            if correlation > maxCorrelation {
                maxCorrelation = correlation
                bestLag = lag
            }
        }
        
        return bestLag > 0 ? sampleRate / Float(bestLag) : 0
    }
}

// MARK: - Errors

enum AudioFeatureError: Error, LocalizedError {
    case invalidWAVFile(String)
    case processingError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidWAVFile(let message):
            return "Invalid WAV file: \(message)"
        case .processingError(let message):
            return "Processing error: \(message)"
        }
    }
}
