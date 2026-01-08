//
//  WERCalculator.swift
//  WhisperType
//
//  Word Error Rate calculator using Levenshtein distance.
//  Used to measure transcription accuracy against ground truth.
//

import Foundation

/// Word Error Rate calculator for transcription accuracy measurement
struct WERCalculator {
    
    // MARK: - Public API
    
    /// Calculate Word Error Rate between reference and hypothesis
    /// - Parameters:
    ///   - reference: The ground truth text
    ///   - hypothesis: The transcribed text to evaluate
    /// - Returns: WER as a value between 0.0 (perfect) and 1.0+ (poor)
    static func calculate(reference: String, hypothesis: String) -> Double {
        let refWords = normalizeAndTokenize(reference)
        let hypWords = normalizeAndTokenize(hypothesis)
        
        guard !refWords.isEmpty else {
            return hypWords.isEmpty ? 0.0 : 1.0
        }
        
        let distance = levenshteinDistance(refWords, hypWords)
        return Double(distance) / Double(refWords.count)
    }
    
    /// Calculate Levenshtein distance between two word arrays
    /// - Parameters:
    ///   - s1: First word array
    ///   - s2: Second word array
    /// - Returns: Minimum edit distance (insertions, deletions, substitutions)
    static func levenshteinDistance(_ s1: [String], _ s2: [String]) -> Int {
        let m = s1.count
        let n = s2.count
        
        // Handle edge cases
        if m == 0 { return n }
        if n == 0 { return m }
        
        // Create distance matrix
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        
        // Initialize first row and column
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }
        
        // Fill in the matrix
        for i in 1...m {
            for j in 1...n {
                let cost = s1[i - 1].lowercased() == s2[j - 1].lowercased() ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // Deletion
                    matrix[i][j - 1] + 1,      // Insertion
                    matrix[i - 1][j - 1] + cost // Substitution
                )
            }
        }
        
        return matrix[m][n]
    }
    
    // MARK: - Text Normalization
    
    /// Normalize and tokenize text for comparison
    /// - Parameter text: Input text
    /// - Returns: Array of normalized words
    static func normalizeAndTokenize(_ text: String) -> [String] {
        // Convert to lowercase
        var normalized = text.lowercased()
        
        // Remove punctuation (except apostrophes in contractions)
        let punctuation = CharacterSet.punctuationCharacters.subtracting(CharacterSet(charactersIn: "'"))
        normalized = normalized.components(separatedBy: punctuation).joined()
        
        // Split into words and filter empty
        let words = normalized.split(separator: " ")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        return words
    }
    
    // MARK: - Detailed Results
    
    /// Detailed WER calculation result
    struct WERResult {
        let wer: Double
        let referenceWordCount: Int
        let hypothesisWordCount: Int
        let editDistance: Int
        let insertions: Int
        let deletions: Int
        let substitutions: Int
        
        var formattedWER: String {
            String(format: "%.1f%%", wer * 100)
        }
        
        var isPassing: Bool {
            wer < 0.20 // Less than 20% is considered passing
        }
    }
    
    /// Calculate detailed WER with breakdown of error types
    /// - Parameters:
    ///   - reference: The ground truth text
    ///   - hypothesis: The transcribed text
    /// - Returns: Detailed WER result
    static func calculateDetailed(reference: String, hypothesis: String) -> WERResult {
        let refWords = normalizeAndTokenize(reference)
        let hypWords = normalizeAndTokenize(hypothesis)
        
        let distance = levenshteinDistance(refWords, hypWords)
        let wer = refWords.isEmpty ? (hypWords.isEmpty ? 0.0 : 1.0) : Double(distance) / Double(refWords.count)
        
        // Approximate error breakdown (simplified)
        let insertions = max(0, hypWords.count - refWords.count)
        let deletions = max(0, refWords.count - hypWords.count)
        let substitutions = distance - insertions - deletions
        
        return WERResult(
            wer: wer,
            referenceWordCount: refWords.count,
            hypothesisWordCount: hypWords.count,
            editDistance: distance,
            insertions: insertions,
            deletions: deletions,
            substitutions: max(0, substitutions)
        )
    }
}
