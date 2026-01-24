// SpeakerDiarizationSpikeTests.swift
// XCTest wrapper for running the speaker diarization spike
//
// Add this file to your test target to run the spike via Xcode

import XCTest
@testable import WhisperType  // Adjust to your module name

/// XCTest wrapper for the speaker diarization spike
/// Run these tests to validate the Swift-only approach
class SpeakerDiarizationSpikeTests: XCTestCase {
    
    var spike: SpeakerDiarizationSpike!
    var testDirectory: URL!
    
    override func setUpWithError() throws {
        spike = SpeakerDiarizationSpike()
        
        // Find test assets directory
        // Adjust this path based on your project structure
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // WhisperType/
        
        testDirectory = projectRoot
            .appendingPathComponent("TestAssets")
            .appendingPathComponent("SpikeAudio")
        
        // Verify test directory exists
        guard FileManager.default.fileExists(atPath: testDirectory.path) else {
            throw XCTSkip("Test audio directory not found. Create test files in: \(testDirectory.path)")
        }
    }
    
    override func tearDownWithError() throws {
        spike = nil
    }
    
    // MARK: - Single File Tests
    
    /// Test with clear recording (if available)
    func testClearRecording() throws {
        let audioFile = testDirectory.appendingPathComponent("two_speakers_clear.wav")
        let labelsFile = testDirectory.appendingPathComponent("two_speakers_clear_labels.json")
        
        guard FileManager.default.fileExists(atPath: audioFile.path),
              FileManager.default.fileExists(atPath: labelsFile.path) else {
            throw XCTSkip("Clear recording test files not found. See README.md for setup instructions.")
        }
        
        let result = try spike.runSpike(audioURL: audioFile, groundTruthURL: labelsFile, verbose: true)
        
        // Assert minimum accuracy for clear audio
        XCTAssertGreaterThanOrEqual(
            result.accuracy,
            0.75,
            "Clear recording accuracy should be >= 75%"
        )
    }
    
    /// Test with Zoom/Teams recording (if available)
    func testZoomRecording() throws {
        let audioFile = testDirectory.appendingPathComponent("two_speakers_zoom.wav")
        let labelsFile = testDirectory.appendingPathComponent("two_speakers_zoom_labels.json")
        
        guard FileManager.default.fileExists(atPath: audioFile.path),
              FileManager.default.fileExists(atPath: labelsFile.path) else {
            throw XCTSkip("Zoom recording test files not found. See README.md for setup instructions.")
        }
        
        let result = try spike.runSpike(audioURL: audioFile, groundTruthURL: labelsFile, verbose: true)
        
        // Lower threshold for compressed audio
        XCTAssertGreaterThanOrEqual(
            result.accuracy,
            0.65,
            "Zoom recording accuracy should be >= 65%"
        )
    }
    
    // MARK: - Batch Test
    
    /// Run spike on all available test files
    func testAllAvailableAudio() throws {
        let results = try spike.runAllSpikes(in: testDirectory, verbose: false)
        
        guard !results.isEmpty else {
            throw XCTSkip("No test audio files found. See README.md for setup instructions.")
        }
        
        // Check that at least one file passes
        let passingResults = results.filter { $0.accuracy >= 0.65 }
        XCTAssertFalse(passingResults.isEmpty, "At least one test should pass (>= 65% accuracy)")
        
        // Report average
        let avgAccuracy = results.map { $0.accuracy }.reduce(0, +) / Double(results.count)
        print("📊 Average accuracy across \(results.count) tests: \(String(format: "%.1f%%", avgAccuracy * 100))")
    }
    
    // MARK: - Component Tests
    
    /// Test audio feature extraction
    func testFeatureExtraction() throws {
        let extractor = AudioFeatureExtractor()
        
        // Find any WAV file
        let contents = try FileManager.default.contentsOfDirectory(at: testDirectory, includingPropertiesForKeys: nil)
        guard let wavFile = contents.first(where: { $0.pathExtension.lowercased() == "wav" }) else {
            throw XCTSkip("No WAV files found for feature extraction test")
        }
        
        let samples = try extractor.loadWAV(url: wavFile)
        XCTAssertFalse(samples.isEmpty, "Should load samples from WAV file")
        
        let segments = extractor.extractSegmentFeatures(samples: samples)
        XCTAssertFalse(segments.isEmpty, "Should extract features from audio")
        
        // Check feature vector size (6 features: energy, zcr, centroid, rolloff, flatness, pitch)
        if let firstSegment = segments.first {
            XCTAssertEqual(firstSegment.features.count, 6, "Should have 6 features per segment")
        }
        
        print("✅ Extracted \(segments.count) segments with \(segments.first?.features.count ?? 0) features each")
    }
    
    /// Test k-means clustering
    func testKMeansClustering() throws {
        let kmeans = SimpleKMeans()
        
        // Create simple test data
        let data: [[Float]] = [
            // Cluster 1 (around [1, 1])
            [0.9, 1.1], [1.1, 0.9], [1.0, 1.0], [0.8, 1.2],
            // Cluster 2 (around [5, 5])
            [4.9, 5.1], [5.1, 4.9], [5.0, 5.0], [4.8, 5.2]
        ]
        
        let result = kmeans.cluster(data: data, k: 2)
        
        XCTAssertEqual(result.labels.count, 8, "Should have label for each data point")
        XCTAssertEqual(result.centroids.count, 2, "Should have 2 centroids")
        
        // Check that points are separated correctly
        let cluster0 = result.labels.prefix(4)
        let cluster1 = result.labels.suffix(4)
        
        // All points in first group should be same cluster
        XCTAssertEqual(Set(cluster0).count, 1, "First 4 points should be in same cluster")
        // All points in second group should be same cluster
        XCTAssertEqual(Set(cluster1).count, 1, "Last 4 points should be in same cluster")
        // The two groups should be different clusters
        XCTAssertNotEqual(cluster0.first, cluster1.first, "Two groups should be in different clusters")
        
        print("✅ K-means correctly separated two clusters in \(result.iterations) iterations")
    }
    
    // MARK: - Performance Test
    
    /// Measure processing time
    func testPerformance() throws {
        let contents = try FileManager.default.contentsOfDirectory(at: testDirectory, includingPropertiesForKeys: nil)
        guard let wavFile = contents.first(where: { $0.pathExtension.lowercased() == "wav" }),
              let labelsFile = contents.first(where: { $0.pathExtension.lowercased() == "json" && $0.lastPathComponent.contains("labels") }) else {
            throw XCTSkip("No test files found for performance test")
        }
        
        measure {
            _ = try? spike.runSpike(audioURL: wavFile, groundTruthURL: labelsFile, verbose: false)
        }
    }
}

// MARK: - Test Helpers

extension SpeakerDiarizationSpikeTests {
    
    /// Helper to create a simple test WAV file (for unit testing without real audio)
    private func createTestWAV(duration: Double, at url: URL) throws {
        // Generate simple sine wave test audio
        let sampleRate: Float = 16000
        let numSamples = Int(duration * Double(sampleRate))
        
        var samples = [Int16]()
        for i in 0..<numSamples {
            // Alternate between two frequencies to simulate two speakers
            let frequency: Float = (i / Int(sampleRate * 2)) % 2 == 0 ? 200 : 300
            let sample = sin(2 * .pi * frequency * Float(i) / sampleRate)
            samples.append(Int16(sample * Float(Int16.max - 1)))
        }
        
        // Write WAV file
        var data = Data()
        
        // WAV header
        data.append(contentsOf: "RIFF".utf8)
        let fileSize = UInt32(36 + samples.count * 2)
        data.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // PCM
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // Mono
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16000).littleEndian) { Array($0) })  // Sample rate
        data.append(contentsOf: withUnsafeBytes(of: UInt32(32000).littleEndian) { Array($0) })  // Byte rate
        data.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })  // Block align
        data.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) })  // Bits per sample
        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(samples.count * 2).littleEndian) { Array($0) })
        
        // Audio data
        for sample in samples {
            data.append(contentsOf: withUnsafeBytes(of: sample.littleEndian) { Array($0) })
        }
        
        try data.write(to: url)
    }
}
