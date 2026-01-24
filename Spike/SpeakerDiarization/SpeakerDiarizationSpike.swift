// SpeakerDiarizationSpike.swift
// Speaker Diarization Spike - Swift-only approach validation
//
// Purpose: Main entry point to run the spike tests
// Usage: Can be run as a macOS command line tool or integrated into XCTest

import Foundation

/// Main spike runner class
class SpeakerDiarizationSpike {
    
    let extractor = AudioFeatureExtractor()
    let kmeans = SimpleKMeans()
    let evaluator = SpikeEvaluator()
    
    /// Run the spike on a single test case
    func runSpike(audioURL: URL, groundTruthURL: URL, verbose: Bool = false) throws -> SpikeResult {
        print("🎯 Running Speaker Diarization Spike")
        print("   Audio: \(audioURL.lastPathComponent)")
        print("   Ground Truth: \(groundTruthURL.lastPathComponent)")
        print("")
        
        // 1. Load ground truth
        let groundTruth = try evaluator.loadGroundTruth(from: groundTruthURL)
        let uniqueSpeakers = Set(groundTruth.segments.map { $0.speaker }).count
        print("✅ Loaded ground truth: \(groundTruth.segments.count) segments, \(uniqueSpeakers) speakers")
        
        // 2. Load and process audio
        print("⏳ Loading audio...")
        let startLoad = Date()
        let samples = try extractor.loadWAV(url: audioURL)
        let durationSeconds = Double(samples.count) / 16000.0
        let loadTime = Date().timeIntervalSince(startLoad)
        print("✅ Loaded \(String(format: "%.1f", durationSeconds)) seconds of audio in \(String(format: "%.2f", loadTime))s")
        
        // 3. Extract features
        print("⏳ Extracting features...")
        let startExtract = Date()
        let segments = extractor.extractSegmentFeatures(samples: samples)
        let extractTime = Date().timeIntervalSince(startExtract)
        print("✅ Extracted features for \(segments.count) segments in \(String(format: "%.2f", extractTime))s")
        
        if segments.isEmpty {
            print("❌ No non-silent segments found!")
            throw SpikeError.noSegmentsFound
        }
        
        // 4. Cluster
        print("⏳ Clustering (k=\(uniqueSpeakers))...")
        let startCluster = Date()
        let featureVectors = segments.map { $0.features }
        let clusterResult = kmeans.cluster(data: featureVectors, k: uniqueSpeakers)
        let clusterTime = Date().timeIntervalSince(startCluster)
        print("✅ Clustering complete in \(clusterResult.iterations) iterations (\(String(format: "%.2f", clusterTime))s)")
        
        // 5. Evaluate against ground truth
        print("⏳ Evaluating accuracy...")
        let result = evaluator.evaluate(
            segments: segments,
            labels: clusterResult.labels,
            groundTruth: groundTruth,
            verbose: verbose
        )
        
        // 6. Print results
        result.printResults()
        
        // Print timing summary
        let totalTime = loadTime + extractTime + clusterTime
        print("")
        print("⏱️  Timing Summary:")
        print("   Load: \(String(format: "%.2f", loadTime))s")
        print("   Extract: \(String(format: "%.2f", extractTime))s")
        print("   Cluster: \(String(format: "%.2f", clusterTime))s")
        print("   Total: \(String(format: "%.2f", totalTime))s")
        print("   Processing ratio: \(String(format: "%.1f", durationSeconds / totalTime))x realtime")
        print("")
        
        return result
    }
    
    /// Run spike on all test files in a directory
    func runAllSpikes(in directory: URL, verbose: Bool = false) throws -> [SpikeResult] {
        var results: [SpikeResult] = []
        
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        
        // Find all WAV files
        let wavFiles = contents.filter { $0.pathExtension.lowercased() == "wav" }
        
        for wavFile in wavFiles {
            // Look for matching labels file
            let baseName = wavFile.deletingPathExtension().lastPathComponent
            let labelsFile = directory.appendingPathComponent("\(baseName)_labels.json")
            
            guard fileManager.fileExists(atPath: labelsFile.path) else {
                print("⚠️  Skipping \(wavFile.lastPathComponent) - no labels file found")
                continue
            }
            
            print("")
            print("───────────────────────────────────────────────────────────")
            print("Test: \(wavFile.lastPathComponent)")
            print("───────────────────────────────────────────────────────────")
            
            do {
                let result = try runSpike(audioURL: wavFile, groundTruthURL: labelsFile, verbose: verbose)
                results.append(result)
            } catch {
                print("❌ Error processing \(wavFile.lastPathComponent): \(error)")
            }
        }
        
        // Print summary
        printSummary(results)
        
        return results
    }
    
    /// Print summary of all results
    private func printSummary(_ results: [SpikeResult]) {
        guard !results.isEmpty else { return }
        
        print("")
        print("═══════════════════════════════════════════════════════════")
        print("                    OVERALL SUMMARY")
        print("═══════════════════════════════════════════════════════════")
        
        for result in results {
            let status: String
            if result.accuracy >= 0.75 {
                status = "✅"
            } else if result.accuracy >= 0.65 {
                status = "⚠️"
            } else {
                status = "❌"
            }
            print("  \(status) \(result.audioFile): \(String(format: "%.1f%%", result.accuracy * 100))")
        }
        
        let avgAccuracy = results.map { $0.accuracy }.reduce(0, +) / Double(results.count)
        print("")
        print("  Average Accuracy: \(String(format: "%.1f%%", avgAccuracy * 100))")
        
        print("")
        print("═══════════════════════════════════════════════════════════")
        
        // Overall recommendation
        let allPass = results.allSatisfy { $0.accuracy >= 0.75 }
        let allMarginal = results.allSatisfy { $0.accuracy >= 0.65 }
        
        print("")
        print("📋 RECOMMENDATION:")
        if allPass {
            print("   ✅ Swift-only approach is VIABLE")
            print("   Proceed with implementation as primary/fallback solution")
        } else if allMarginal {
            print("   ⚠️  Swift-only approach is MARGINAL")
            print("   Consider improvements or use as fallback only")
        } else {
            print("   ❌ Swift-only approach needs work")
            print("   Review feature extraction or consider PyAnnote")
        }
        print("")
    }
}

// MARK: - Errors

enum SpikeError: Error, LocalizedError {
    case noSegmentsFound
    case fileNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .noSegmentsFound:
            return "No non-silent segments found in audio"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        }
    }
}

// MARK: - Command Line Entry Point

/// Run the spike from command line
func runSpikeFromCommandLine() {
    let spike = SpeakerDiarizationSpike()
    
    // Default test directory
    let homeDir = FileManager.default.homeDirectoryForCurrentUser
    let testDir = homeDir
        .appendingPathComponent("research")
        .appendingPathComponent("whispertype")
        .appendingPathComponent("TestAssets")
        .appendingPathComponent("SpikeAudio")
    
    print("🚀 Speaker Diarization Spike - Swift Only")
    print("=========================================")
    print("")
    print("Test Directory: \(testDir.path)")
    print("")
    
    // Check if directory exists
    guard FileManager.default.fileExists(atPath: testDir.path) else {
        print("❌ Test directory not found!")
        print("")
        print("Please create test audio files in:")
        print("  \(testDir.path)")
        print("")
        print("Required files:")
        print("  - <name>.wav           (16kHz mono WAV file)")
        print("  - <name>_labels.json   (ground truth labels)")
        print("")
        print("See README.md for format details.")
        return
    }
    
    do {
        _ = try spike.runAllSpikes(in: testDir, verbose: false)
    } catch {
        print("❌ Error: \(error)")
    }
}

// Uncomment to run from command line:
// runSpikeFromCommandLine()
