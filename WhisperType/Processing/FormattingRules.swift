//
//  FormattingRules.swift
//  WhisperType
//
//  Rule-based text formatting for capitalization and punctuation.
//  Applied after filler removal in the processing pipeline.
//

import Foundation

/// Applies rule-based formatting to text: capitalization, punctuation, whitespace.
class FormattingRules {
    
    // MARK: - Singleton
    
    static let shared = FormattingRules()
    
    // MARK: - Configuration
    
    /// Characters that end a sentence
    private let sentenceEnders: CharacterSet = CharacterSet(charactersIn: ".!?")
    
    /// Words that should always be capitalized (proper nouns, etc.)
    private var alwaysCapitalize: Set<String> = [
        "i",  // Standalone "i" should be "I"
        "i'm", "i'll", "i've", "i'd"  // Contractions with "I"
    ]
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public API
    
    /// Apply all formatting rules to the given text
    /// - Parameter text: The input text to format
    /// - Returns: Formatted text
    func apply(_ text: String) -> String {
        var result = text
        
        // Step 1: Normalize whitespace first
        result = normalizeWhitespace(result)
        
        // Step 2: Fix standalone "i" → "I"
        result = capitalizeI(result)
        
        // Step 3: Capitalize after sentence-ending punctuation
        result = capitalizeAfterPunctuation(result)
        
        // Step 4: Capitalize first letter of the text
        result = capitalizeFirstLetter(result)
        
        // Step 5: Normalize ellipsis
        result = normalizeEllipsis(result)
        
        // Step 6: Add ending punctuation if missing
        result = addEndingPunctuation(result)
        
        // Step 7: Final whitespace cleanup
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return result
    }
    
    // MARK: - Individual Formatting Rules
    
    /// Capitalize the first letter of the text
    func capitalizeFirstLetter(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        
        // Find the first letter
        var result = text
        if let firstLetterIndex = result.firstIndex(where: { $0.isLetter }) {
            let char = result[firstLetterIndex]
            if char.isLowercase {
                result.replaceSubrange(firstLetterIndex...firstLetterIndex, with: String(char).uppercased())
            }
        }
        
        return result
    }
    
    /// Capitalize the first letter after sentence-ending punctuation
    func capitalizeAfterPunctuation(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        
        var result = ""
        var capitalizeNext = false
        var previousChar: Character? = nil
        
        for char in text {
            if capitalizeNext && char.isLetter {
                result.append(char.uppercased())
                capitalizeNext = false
            } else {
                result.append(char)
            }
            
            // Check if this character ends a sentence
            if sentenceEnders.contains(char.unicodeScalars.first!) {
                capitalizeNext = true
            } else if !char.isWhitespace && char != "\"" && char != "'" && char != ")" {
                // Reset if we hit a non-whitespace, non-quote character
                // (allows for ." or ?) patterns)
                if previousChar != nil && !sentenceEnders.contains(previousChar!.unicodeScalars.first!) {
                    capitalizeNext = false
                }
            }
            
            previousChar = char
        }
        
        return result
    }
    
    /// Capitalize standalone "i" to "I" and "i'm", "i'll", etc.
    func capitalizeI(_ text: String) -> String {
        var result = text
        
        // Replace standalone "i" with "I"
        // Use word boundary matching
        result = result.replacingOccurrences(
            of: "\\bi\\b",
            with: "I",
            options: .regularExpression
        )
        
        // Also handle contractions
        result = result.replacingOccurrences(
            of: "\\bi'm\\b",
            with: "I'm",
            options: [.regularExpression, .caseInsensitive]
        )
        
        result = result.replacingOccurrences(
            of: "\\bi'll\\b",
            with: "I'll",
            options: [.regularExpression, .caseInsensitive]
        )
        
        result = result.replacingOccurrences(
            of: "\\bi've\\b",
            with: "I've",
            options: [.regularExpression, .caseInsensitive]
        )
        
        result = result.replacingOccurrences(
            of: "\\bi'd\\b",
            with: "I'd",
            options: [.regularExpression, .caseInsensitive]
        )
        
        return result
    }
    
    /// Normalize whitespace: collapse multiple spaces, fix spacing around punctuation
    func normalizeWhitespace(_ text: String) -> String {
        var result = text
        
        // Collapse multiple spaces into one
        result = result.replacingOccurrences(
            of: " +",
            with: " ",
            options: .regularExpression
        )
        
        // Remove space before punctuation
        result = result.replacingOccurrences(
            of: " +([.,!?;:)])",
            with: "$1",
            options: .regularExpression
        )
        
        // Ensure space after punctuation (except for abbreviations like "Dr.")
        result = result.replacingOccurrences(
            of: "([.,!?;:])([A-Za-z])",
            with: "$1 $2",
            options: .regularExpression
        )
        
        // Remove space after opening brackets/quotes
        result = result.replacingOccurrences(
            of: "([\\(\\[\"']) +",
            with: "$1",
            options: .regularExpression
        )
        
        return result
    }
    
    /// Normalize ellipsis: "..." should be consistent
    func normalizeEllipsis(_ text: String) -> String {
        var result = text
        
        // Convert various ellipsis forms to standard "..."
        // Two dots followed by optional spaces and more dots
        result = result.replacingOccurrences(
            of: "\\.{2,}",
            with: "...",
            options: .regularExpression
        )
        
        // Unicode ellipsis character to three dots
        result = result.replacingOccurrences(of: "…", with: "...")
        
        return result
    }
    
    /// Add ending punctuation if the text doesn't end with one
    func addEndingPunctuation(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return text }
        
        // Check if already ends with punctuation
        if let lastChar = trimmed.last {
            let endingPunctuation = CharacterSet(charactersIn: ".!?")
            if lastChar.unicodeScalars.allSatisfy({ endingPunctuation.contains($0) }) {
                return text
            }
        }
        
        // Add a period at the end
        return trimmed + "."
    }
    
    // MARK: - Utility Methods
    
    /// Add a word to always capitalize
    func addAlwaysCapitalize(_ word: String) {
        alwaysCapitalize.insert(word.lowercased())
    }
    
    /// Remove a word from always capitalize list
    func removeAlwaysCapitalize(_ word: String) {
        alwaysCapitalize.remove(word.lowercased())
    }
}
