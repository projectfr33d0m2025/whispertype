//
//  VocabularyCorrector.swift
//  WhisperType
//
//  Post-processing fuzzy matching to correct transcribed text using vocabulary.
//  Part of the v1.2 Vocabulary System feature.
//

import Foundation

/// Corrects transcribed text using custom vocabulary with fuzzy matching
class VocabularyCorrector {
    
    // MARK: - Singleton
    
    static let shared = VocabularyCorrector()
    
    // MARK: - Constants
    
    /// Maximum Levenshtein distance for a match
    private let maxDistance = 2
    
    /// Minimum word length to consider for correction
    private let minWordLength = 3
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public API
    
    /// Correct text using vocabulary entries
    /// - Parameters:
    ///   - text: Text to correct
    ///   - vocabulary: Vocabulary entries to match against
    /// - Returns: Corrected text with vocabulary terms applied
    func correct(_ text: String, vocabulary: [VocabularyEntry]) -> CorrectionResult {
        guard !text.isEmpty, !vocabulary.isEmpty else {
            return CorrectionResult(text: text, corrections: [])
        }
        
        var correctedText = text
        var corrections: [VocabularyCorrection] = []
        
        // Build lookup dictionary for faster matching
        let lookup = buildLookup(from: vocabulary)
        
        // Tokenize text into words while preserving structure
        let tokens = tokenize(text)
        
        // Process each token
        var offset = 0
        for token in tokens {
            guard token.isWord, token.text.count >= minWordLength else { continue }
            
            // Try exact match first (case-insensitive)
            if let match = findExactMatch(token.text, in: lookup) {
                if token.text != match.term {
                    let replacement = preserveCase(original: token.text, replacement: match.term)
                    let correction = VocabularyCorrection(
                        original: token.text,
                        corrected: replacement,
                        term: match.term,
                        matchType: .exact
                    )
                    corrections.append(correction)
                    
                    // Replace in text
                    let range = correctedText.index(correctedText.startIndex, offsetBy: token.range.lowerBound + offset)..<correctedText.index(correctedText.startIndex, offsetBy: token.range.upperBound + offset)
                    correctedText.replaceSubrange(range, with: replacement)
                    offset += replacement.count - token.text.count
                }
            }
            // Try fuzzy match
            else if let match = findFuzzyMatch(token.text, in: lookup, vocabulary: vocabulary) {
                let replacement = preserveCase(original: token.text, replacement: match.term)
                let correction = VocabularyCorrection(
                    original: token.text,
                    corrected: replacement,
                    term: match.term,
                    matchType: .fuzzy(distance: match.distance)
                )
                corrections.append(correction)
                
                // Replace in text
                let range = correctedText.index(correctedText.startIndex, offsetBy: token.range.lowerBound + offset)..<correctedText.index(correctedText.startIndex, offsetBy: token.range.upperBound + offset)
                correctedText.replaceSubrange(range, with: replacement)
                offset += replacement.count - token.text.count
            }
        }
        
        return CorrectionResult(text: correctedText, corrections: corrections)
    }
    
    // MARK: - Lookup Building
    
    private struct LookupEntry {
        let term: String
        let entryId: UUID
    }
    
    private func buildLookup(from vocabulary: [VocabularyEntry]) -> [String: LookupEntry] {
        var lookup: [String: LookupEntry] = [:]
        
        for entry in vocabulary {
            // Add main term
            lookup[entry.term.lowercased()] = LookupEntry(term: entry.term, entryId: entry.id)
            
            // Add aliases
            for alias in entry.aliases {
                lookup[alias.lowercased()] = LookupEntry(term: entry.term, entryId: entry.id)
            }
        }
        
        return lookup
    }
    
    // MARK: - Matching
    
    private func findExactMatch(_ word: String, in lookup: [String: LookupEntry]) -> LookupEntry? {
        lookup[word.lowercased()]
    }
    
    private struct FuzzyMatch {
        let term: String
        let distance: Int
    }
    
    private func findFuzzyMatch(_ word: String, in lookup: [String: LookupEntry], vocabulary: [VocabularyEntry]) -> FuzzyMatch? {
        let lowercased = word.lowercased()
        var bestMatch: FuzzyMatch?
        var bestDistance = maxDistance + 1
        
        // Check against all vocabulary terms and aliases
        for entry in vocabulary {
            // Check main term
            let termDistance = levenshteinDistance(lowercased, entry.term.lowercased())
            if termDistance <= maxDistance && termDistance < bestDistance {
                bestMatch = FuzzyMatch(term: entry.term, distance: termDistance)
                bestDistance = termDistance
            }
            
            // Check aliases
            for alias in entry.aliases {
                let aliasDistance = levenshteinDistance(lowercased, alias.lowercased())
                if aliasDistance <= maxDistance && aliasDistance < bestDistance {
                    bestMatch = FuzzyMatch(term: entry.term, distance: aliasDistance)
                    bestDistance = aliasDistance
                }
            }
        }
        
        return bestMatch
    }
    
    // MARK: - Levenshtein Distance
    
    /// Calculate Levenshtein (edit) distance between two strings
    func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1 = Array(s1.lowercased())
        let s2 = Array(s2.lowercased())
        
        // Early exit for empty strings
        if s1.isEmpty { return s2.count }
        if s2.isEmpty { return s1.count }
        
        // Early exit if difference in length exceeds max distance
        if abs(s1.count - s2.count) > maxDistance {
            return maxDistance + 1
        }
        
        var dist = [[Int]](repeating: [Int](repeating: 0, count: s2.count + 1), count: s1.count + 1)
        
        for i in 0...s1.count { dist[i][0] = i }
        for j in 0...s2.count { dist[0][j] = j }
        
        for i in 1...s1.count {
            for j in 1...s2.count {
                let cost = s1[i-1] == s2[j-1] ? 0 : 1
                dist[i][j] = min(
                    dist[i-1][j] + 1,      // deletion
                    dist[i][j-1] + 1,      // insertion
                    dist[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return dist[s1.count][s2.count]
    }
    
    // MARK: - Tokenization
    
    private struct Token {
        let text: String
        let range: Range<Int>
        let isWord: Bool
    }
    
    private func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var currentWord = ""
        var wordStart = 0
        
        for (index, char) in text.enumerated() {
            if char.isLetter || char.isNumber || char == "'" || char == "-" {
                if currentWord.isEmpty {
                    wordStart = index
                }
                currentWord.append(char)
            } else {
                if !currentWord.isEmpty {
                    tokens.append(Token(
                        text: currentWord,
                        range: wordStart..<(wordStart + currentWord.count),
                        isWord: true
                    ))
                    currentWord = ""
                }
            }
        }
        
        // Don't forget last word
        if !currentWord.isEmpty {
            tokens.append(Token(
                text: currentWord,
                range: wordStart..<(wordStart + currentWord.count),
                isWord: true
            ))
        }
        
        return tokens
    }
    
    // MARK: - Case Preservation
    
    /// Preserve the case pattern from original when applying replacement
    private func preserveCase(original: String, replacement: String) -> String {
        guard !original.isEmpty, !replacement.isEmpty else { return replacement }
        
        // Check if original is all uppercase
        if original == original.uppercased() && original != original.lowercased() {
            return replacement.uppercased()
        }
        
        // Check if original is all lowercase
        if original == original.lowercased() {
            return replacement.lowercased()
        }
        
        // Check if original is title case (first letter uppercase, rest lowercase)
        if original.first?.isUppercase == true && 
           original.dropFirst() == original.dropFirst().lowercased() {
            return replacement.prefix(1).uppercased() + replacement.dropFirst().lowercased()
        }
        
        // Default: return replacement as-is (preserve vocabulary casing)
        return replacement
    }
}

// MARK: - Result Types

struct CorrectionResult {
    let text: String
    let corrections: [VocabularyCorrection]
    
    var hadCorrections: Bool { !corrections.isEmpty }
    var correctionCount: Int { corrections.count }
}

struct VocabularyCorrection {
    let original: String
    let corrected: String
    let term: String
    let matchType: VocabularyCorrectionMatchType
}

enum VocabularyCorrectionMatchType {
    case exact
    case fuzzy(distance: Int)
    
    var description: String {
        switch self {
        case .exact: return "exact"
        case .fuzzy(let distance): return "fuzzy (distance: \(distance))"
        }
    }
}
