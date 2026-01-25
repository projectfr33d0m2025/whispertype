//
//  SummaryValidator.swift
//  WhisperType
//
//  Validates generated meeting summaries.
//

import Foundation

// MARK: - Summary Validation Result

/// Result of validating a generated summary
struct SummaryValidationResult {
    
    /// Whether all template variables were filled
    let allVariablesFilled: Bool
    
    /// Variables that were not filled (still contain {{var}})
    let unfilledVariables: [String]
    
    /// Whether all required sections are present
    let requiredSectionsPresent: Bool
    
    /// Missing required sections
    let missingSections: [String]
    
    /// Keyword coverage (0.0 to 1.0)
    let keywordCoverage: Double
    
    /// Keywords from transcript found in summary
    let matchedKeywords: [String]
    
    /// Keywords from transcript NOT found in summary
    let missedKeywords: [String]
    
    /// Overall validation passed
    var isValid: Bool {
        allVariablesFilled && requiredSectionsPresent && keywordCoverage >= 0.5
    }
    
    /// Human-readable validation summary
    var summary: String {
        var messages: [String] = []
        
        if !allVariablesFilled {
            messages.append("Unfilled variables: \(unfilledVariables.joined(separator: ", "))")
        }
        
        if !requiredSectionsPresent {
            messages.append("Missing sections: \(missingSections.joined(separator: ", "))")
        }
        
        messages.append(String(format: "Keyword coverage: %.0f%%", keywordCoverage * 100))
        
        return messages.joined(separator: "; ")
    }
}

// MARK: - Summary Validator

/// Validates generated meeting summaries
enum SummaryValidator {
    
    // MARK: - Validation
    
    /// Validate a generated summary
    /// - Parameters:
    ///   - summary: The generated summary text
    ///   - template: The template used to generate the summary
    ///   - transcript: The original transcript text
    /// - Returns: Validation result
    static func validate(
        summary: String,
        template: SummaryTemplate,
        transcript: String
    ) -> SummaryValidationResult {
        
        // Check for unfilled variables
        let unfilledVariables = findUnfilledVariables(in: summary)
        let allVariablesFilled = unfilledVariables.isEmpty
        
        // Check required sections
        let (sectionsPresent, missingSections) = checkRequiredSections(
            in: summary,
            template: template
        )
        
        // Calculate keyword coverage
        let (coverage, matched, missed) = calculateKeywordCoverage(
            summary: summary,
            transcript: transcript
        )
        
        return SummaryValidationResult(
            allVariablesFilled: allVariablesFilled,
            unfilledVariables: unfilledVariables,
            requiredSectionsPresent: sectionsPresent,
            missingSections: missingSections,
            keywordCoverage: coverage,
            matchedKeywords: matched,
            missedKeywords: missed
        )
    }
    
    // MARK: - Variable Check
    
    /// Find any unfilled template variables in the summary
    static func findUnfilledVariables(in text: String) -> [String] {
        let pattern = "\\{\\{([a-zA-Z_][a-zA-Z0-9_]*)\\}\\}"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        
        var variables: [String] = []
        for match in matches {
            if let varRange = Range(match.range(at: 1), in: text) {
                let variable = String(text[varRange])
                if !variables.contains(variable) {
                    variables.append(variable)
                }
            }
        }
        
        return variables
    }
    
    // MARK: - Section Check
    
    /// Check if required sections are present based on template
    static func checkRequiredSections(
        in summary: String,
        template: SummaryTemplate
    ) -> (allPresent: Bool, missing: [String]) {
        
        // Extract expected section headers from template
        let headerPattern = "##\\s+(.+)"
        guard let regex = try? NSRegularExpression(pattern: headerPattern) else {
            return (true, [])
        }
        
        let templateRange = NSRange(template.content.startIndex..., in: template.content)
        let templateMatches = regex.matches(in: template.content, range: templateRange)
        
        var expectedSections: [String] = []
        for match in templateMatches {
            if let headerRange = Range(match.range(at: 1), in: template.content) {
                let header = String(template.content[headerRange])
                    .trimmingCharacters(in: .whitespaces)
                // Skip headers that are just template variables
                if !header.hasPrefix("{{") {
                    expectedSections.append(header)
                }
            }
        }
        
        // Check which sections are present in summary
        var missingSections: [String] = []
        let summaryLower = summary.lowercased()
        
        for section in expectedSections {
            // Check for the section header (case insensitive)
            let sectionLower = section.lowercased()
            if !summaryLower.contains("## \(sectionLower)") &&
               !summaryLower.contains("##\(sectionLower)") {
                missingSections.append(section)
            }
        }
        
        return (missingSections.isEmpty, missingSections)
    }
    
    // MARK: - Keyword Coverage
    
    /// Calculate keyword coverage between transcript and summary
    static func calculateKeywordCoverage(
        summary: String,
        transcript: String
    ) -> (coverage: Double, matched: [String], missed: [String]) {
        
        // Extract significant keywords from transcript
        let keywords = extractKeywords(from: transcript)
        
        guard !keywords.isEmpty else {
            return (1.0, [], [])
        }
        
        // Check which keywords appear in summary
        let summaryLower = summary.lowercased()
        var matched: [String] = []
        var missed: [String] = []
        
        for keyword in keywords {
            if summaryLower.contains(keyword.lowercased()) {
                matched.append(keyword)
            } else {
                missed.append(keyword)
            }
        }
        
        let coverage = Double(matched.count) / Double(keywords.count)
        return (coverage, matched, missed)
    }
    
    /// Extract significant keywords from text
    private static func extractKeywords(from text: String) -> [String] {
        // Common stop words to ignore
        let stopWords: Set<String> = [
            "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
            "of", "with", "by", "from", "as", "is", "was", "are", "were", "been",
            "be", "have", "has", "had", "do", "does", "did", "will", "would",
            "could", "should", "may", "might", "must", "can", "that", "this",
            "these", "those", "it", "its", "we", "they", "you", "i", "he", "she",
            "all", "each", "every", "both", "few", "more", "most", "other",
            "some", "such", "no", "not", "only", "own", "same", "so", "than",
            "too", "very", "just", "about", "also", "into", "over", "after",
            "before", "between", "during", "through", "until", "while", "what",
            "which", "who", "whom", "whose", "when", "where", "why", "how",
            "going", "think", "know", "want", "need", "get", "got", "make",
            "made", "let", "like", "say", "said", "see", "look", "come", "came"
        ]
        
        // Tokenize and filter
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { word in
                word.count >= 4 &&
                !stopWords.contains(word) &&
                !word.allSatisfy { $0.isNumber }
            }
        
        // Count word frequencies
        var frequencies: [String: Int] = [:]
        for word in words {
            frequencies[word, default: 0] += 1
        }
        
        // Return top keywords (words appearing 2+ times, or top 20)
        let significantWords = frequencies
            .filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
            .prefix(20)
            .map { $0.key }
        
        // If not enough frequent words, add some single-occurrence words
        if significantWords.count < 10 {
            let additionalWords = frequencies
                .filter { $0.value == 1 }
                .sorted { $0.key < $1.key }
                .prefix(10 - significantWords.count)
                .map { $0.key }
            
            return Array(significantWords) + Array(additionalWords)
        }
        
        return Array(significantWords)
    }
}
