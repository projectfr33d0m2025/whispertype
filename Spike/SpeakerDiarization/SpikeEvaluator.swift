// SpikeEvaluator.swift
// Speaker Diarization Spike - Swift-only approach validation
//
// Purpose: Evaluate clustering results against ground truth

import Foundation

// MARK: - Ground Truth Models

struct GroundTruthSegment: Codable {
    let speaker: String
    let start: Double
    let end: Double
}

struct GroundTruth: Codable {
    let audio_file: String
    let segments: [GroundTruthSegment]
}

// MARK: - Evaluation Results

struct SpikeResult {
    let audioFile: String
    let totalSegments: Int
    let correctSegments: Int
    let accuracy: Double
    let confusionMatrix: [[Int]]
    let speakerMapping: [Int: String]  // Cluster index -> Ground truth speaker
}

struct DetailedEvaluation {
    let segment: AudioSegment
    let predictedCluster: Int
    let actualSpeaker: String?
    let isCorrect: Bool
}

// MARK: - Evaluator

class SpikeEvaluator {
    
    /// Evaluate clustering results against ground truth
    func evaluate(
        segments: [AudioSegment],
        labels: [Int],
        groundTruth: GroundTruth,
        verbose: Bool = false
    ) -> SpikeResult {
        
        // Get unique speakers from ground truth
        let speakers = Array(Set(groundTruth.segments.map { $0.speaker })).sorted()
        let speakerToIndex: [String: Int] = Dictionary(uniqueKeysWithValues: speakers.enumerated().map { ($1, $0) })
        
        let numClusters = (labels.max() ?? 0) + 1
        let numSpeakers = speakers.count
        
        // Build confusion matrix: [predicted cluster][actual speaker]
        var confusionMatrix = [[Int]](repeating: [Int](repeating: 0, count: numSpeakers), count: numClusters)
        var evaluations: [DetailedEvaluation] = []
        
        for (i, segment) in segments.enumerated() {
            let segmentMidpoint = (segment.startTime + segment.endTime) / 2
            let predictedCluster = labels[i]
            
            // Find ground truth speaker at this time
            var actualSpeaker: String? = nil
            for gtSegment in groundTruth.segments {
                if segmentMidpoint >= gtSegment.start && segmentMidpoint <= gtSegment.end {
                    actualSpeaker = gtSegment.speaker
                    break
                }
            }
            
            if let speaker = actualSpeaker, let speakerIdx = speakerToIndex[speaker] {
                confusionMatrix[predictedCluster][speakerIdx] += 1
            }
            
            evaluations.append(DetailedEvaluation(
                segment: segment,
                predictedCluster: predictedCluster,
                actualSpeaker: actualSpeaker,
                isCorrect: false  // Will be updated after mapping
            ))
        }
        
        // Find optimal mapping between clusters and speakers
        let (bestMapping, correctCount) = findOptimalMapping(
            confusionMatrix: confusionMatrix,
            numClusters: numClusters,
            numSpeakers: numSpeakers,
            speakers: speakers
        )
        
        // Calculate total evaluated (segments that matched ground truth)
        let totalEvaluated = confusionMatrix.flatMap { $0 }.reduce(0, +)
        let accuracy = totalEvaluated > 0 ? Double(correctCount) / Double(totalEvaluated) : 0
        
        // Reorder confusion matrix according to best mapping for display
        let reorderedMatrix = reorderConfusionMatrix(
            confusionMatrix: confusionMatrix,
            mapping: bestMapping,
            numSpeakers: numSpeakers
        )
        
        if verbose {
            printDetailedEvaluations(
                evaluations: evaluations,
                mapping: bestMapping,
                speakers: speakers
            )
        }
        
        return SpikeResult(
            audioFile: groundTruth.audio_file,
            totalSegments: totalEvaluated,
            correctSegments: correctCount,
            accuracy: accuracy,
            confusionMatrix: reorderedMatrix,
            speakerMapping: bestMapping
        )
    }
    
    /// Load ground truth from JSON file
    func loadGroundTruth(from url: URL) throws -> GroundTruth {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(GroundTruth.self, from: data)
    }
    
    // MARK: - Private Helpers
    
    /// Find optimal mapping between clusters and speakers using Hungarian algorithm approximation
    private func findOptimalMapping(
        confusionMatrix: [[Int]],
        numClusters: Int,
        numSpeakers: Int,
        speakers: [String]
    ) -> (mapping: [Int: String], correct: Int) {
        
        // For 2 speakers, just try both permutations
        if numSpeakers == 2 && numClusters == 2 {
            let mapping1Correct = confusionMatrix[0][0] + confusionMatrix[1][1]
            let mapping2Correct = confusionMatrix[0][1] + confusionMatrix[1][0]
            
            if mapping2Correct > mapping1Correct {
                return ([0: speakers[1], 1: speakers[0]], mapping2Correct)
            } else {
                return ([0: speakers[0], 1: speakers[1]], mapping1Correct)
            }
        }
        
        // For more speakers, use greedy assignment
        var mapping: [Int: String] = [:]
        var usedSpeakers = Set<Int>()
        var totalCorrect = 0
        
        // Sort clusters by total assignments (descending)
        let clusterOrder = (0..<numClusters).sorted { 
            confusionMatrix[$0].reduce(0, +) > confusionMatrix[$1].reduce(0, +) 
        }
        
        for cluster in clusterOrder {
            var bestSpeaker = -1
            var bestCount = -1
            
            for (speakerIdx, count) in confusionMatrix[cluster].enumerated() {
                if !usedSpeakers.contains(speakerIdx) && count > bestCount {
                    bestCount = count
                    bestSpeaker = speakerIdx
                }
            }
            
            if bestSpeaker >= 0 {
                mapping[cluster] = speakers[bestSpeaker]
                usedSpeakers.insert(bestSpeaker)
                totalCorrect += bestCount
            }
        }
        
        return (mapping, totalCorrect)
    }
    
    /// Reorder confusion matrix for display (rows = predicted speakers, cols = actual speakers)
    private func reorderConfusionMatrix(
        confusionMatrix: [[Int]],
        mapping: [Int: String],
        numSpeakers: Int
    ) -> [[Int]] {
        // For display, we want [predicted speaker][actual speaker]
        // where predicted speaker is derived from the mapping
        
        // Simple case: return as-is but with cluster -> speaker mapping applied
        // The caller should interpret row i as "cluster i (mapped to speaker X)"
        return confusionMatrix
    }
    
    /// Print detailed evaluation for debugging
    private func printDetailedEvaluations(
        evaluations: [DetailedEvaluation],
        mapping: [Int: String],
        speakers: [String]
    ) {
        print("")
        print("Detailed Segment Evaluations:")
        print("─────────────────────────────────────────────────────────────")
        print("Time Range       │ Predicted │ Actual │ Match")
        print("─────────────────────────────────────────────────────────────")
        
        for eval in evaluations.prefix(20) {  // Show first 20
            let timeRange = String(format: "%5.1f - %5.1f", eval.segment.startTime, eval.segment.endTime)
            let predicted = mapping[eval.predictedCluster] ?? "Cluster \(eval.predictedCluster)"
            let actual = eval.actualSpeaker ?? "Unknown"
            let match = predicted == actual ? "✅" : "❌"
            
            print("\(timeRange)s │ \(predicted.padding(toLength: 9, withPad: " ", startingAt: 0)) │ \(actual.padding(toLength: 6, withPad: " ", startingAt: 0)) │ \(match)")
        }
        
        if evaluations.count > 20 {
            print("... and \(evaluations.count - 20) more segments")
        }
        print("─────────────────────────────────────────────────────────────")
    }
}

// MARK: - Result Printing

extension SpikeResult {
    
    func printResults() {
        print("")
        print("═══════════════════════════════════════════════════════════")
        print("                    SPIKE RESULTS")
        print("═══════════════════════════════════════════════════════════")
        print("")
        print("  Audio File:      \(audioFile)")
        print("  Total Segments:  \(totalSegments)")
        print("  Correct:         \(correctSegments)")
        print("  Accuracy:        \(String(format: "%.1f%%", accuracy * 100))")
        print("")
        print("  Speaker Mapping:")
        for (cluster, speaker) in speakerMapping.sorted(by: { $0.key < $1.key }) {
            print("    Cluster \(cluster) → \(speaker)")
        }
        print("")
        print("  Confusion Matrix:")
        
        // Header row
        let speakers = speakerMapping.sorted(by: { $0.key < $1.key }).map { $0.value }
        let headerRow = "                    " + speakers.map { $0.padding(toLength: 10, withPad: " ", startingAt: 0) }.joined()
        print(headerRow)
        
        // Data rows
        for (i, row) in confusionMatrix.enumerated() {
            let predictedLabel = speakerMapping[i] ?? "Cluster \(i)"
            let rowStr = row.map { String(format: "%10d", $0) }.joined()
            print("  \(predictedLabel.padding(toLength: 16, withPad: " ", startingAt: 0))\(rowStr)")
        }
        
        print("")
        print("═══════════════════════════════════════════════════════════")
        
        // Verdict
        printVerdict()
        
        print("═══════════════════════════════════════════════════════════")
    }
    
    private func printVerdict() {
        if accuracy >= 0.75 {
            print("  ✅ PASS - Accuracy >= 75%")
            print("     Swift-only approach is VIABLE for this scenario")
        } else if accuracy >= 0.65 {
            print("  ⚠️  MARGINAL - Accuracy 65-75%")
            print("     Swift-only approach works but may need improvement")
        } else {
            print("  ❌ FAIL - Accuracy < 65%")
            print("     Swift-only approach may not be viable for this scenario")
        }
    }
}
