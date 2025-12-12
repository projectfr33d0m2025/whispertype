//
//  FillerRemover.swift
//  WhisperType
//
//  Removes filler words and false starts from transcribed text.
//  Uses regex-based pattern matching for efficient processing.
//

import Foundation

/// Removes filler words, hesitation sounds, and false starts from text.
class FillerRemover {
    
    // MARK: - Singleton
    
    static let shared = FillerRemover()
    
    // MARK: - Filler Patterns
    
    /// Primary filler words that are always removed (case-insensitive)
    private let primaryFillers = [
        "um", "umm", "ummm",
        "uh", "uhh", "uhhh",
        "uhm", "uhmm",
        "er", "err", "errr",
        "erm", "ermm",
        "ah", "ahh", "ahhh",
        "hm", "hmm", "hmmm"
    ]
    
    /// Contextual fillers removed when used as filler (not content)
    private let contextualFillers = [
        "you know",
        "i mean",
        "sort of",
        "kind of",
        "basically",
        "literally",
        "actually",
        "like,"  // "like" followed by comma is usually filler
    ]
    
    /// Words to preserve even if they look like fillers
    private let preserveWords = [
        "umbrella", "humble", "crumble", "tumble", "rumble",
        "error", "errand", "erratic",
        "likeness", "likely", "likewise", "unlike", "dislike"
    ]
    
    // MARK: - Compiled Regex Patterns
    
    private var primaryFillerRegex: NSRegularExpression?
    private var contextualFillerRegex: NSRegularExpression?
    private var falseStartRegex: NSRegularExpression?
    private var likeFillerRegex: NSRegularExpression?
    
    // MARK: - Initialization
    
    private init() {
        compilePatterns()
    }
    
    private func compilePatterns() {
        // Primary fillers: match whole words only
        // Pattern: \b(um|umm|uh|...) followed by optional punctuation
        let primaryPattern = "\\b(" + primaryFillers.joined(separator: "|") + ")\\b[,.]?\\s*"
        primaryFillerRegex = try? NSRegularExpression(
            pattern: primaryPattern,
            options: [.caseInsensitive]
        )
        
        // Contextual fillers: match phrases
        let contextualPattern = "\\b(" + contextualFillers.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|") + ")\\b[,.]?\\s*"
        contextualFillerRegex = try? NSRegularExpression(
            pattern: contextualPattern,
            options: [.caseInsensitive]
        )
        
        // False starts: "word— word" or "word - word" patterns
        // Matches: "I want— I need" → keeps "I need"
        falseStartRegex = try? NSRegularExpression(
            pattern: "\\b(\\w+(?:\\s+\\w+)?)\\s*[—–-]\\s*",
            options: [.caseInsensitive]
        )
        
        // "like" as filler: Match "like" with surrounding commas or at sentence boundaries
        // Pattern 1: ", like," -> replace with single comma and space
        // Pattern 2: "like," at start of sentence -> remove
        // Preserve: "looks like", "feels like", "I like", "would like"
        // The replacement template will add appropriate spacing
        likeFillerRegex = try? NSRegularExpression(
            pattern: ",\\s*like\\s*,\\s*|^like\\s*,\\s*|\\s+like\\s*,\\s*",
            options: [.caseInsensitive]
        )
    }
    
    // MARK: - Public API
    
    /// Remove filler words and false starts from the given text
    /// - Parameter text: The input text to clean
    /// - Returns: Text with fillers removed
    func remove(_ text: String) -> String {
        var result = text
        
        // Step 1: Remove false starts first (they might contain fillers)
        result = removeFalseStarts(result)
        
        // Step 2: Remove primary fillers
        result = removePrimaryFillers(result)
        
        // Step 3: Remove contextual fillers
        result = removeContextualFillers(result)
        
        // Step 4: Remove standalone "like" used as filler
        result = removeLikeFiller(result)
        
        // Step 5: Clean up whitespace
        result = normalizeWhitespace(result)
        
        return result
    }
    
    // MARK: - Private Removal Methods
    
    private func removePrimaryFillers(_ text: String) -> String {
        guard let regex = primaryFillerRegex else { return text }
        
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: ""
        )
    }
    
    private func removeContextualFillers(_ text: String) -> String {
        guard let regex = contextualFillerRegex else { return text }
        
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: ""
        )
    }
    
    private func removeFalseStarts(_ text: String) -> String {
        guard let regex = falseStartRegex else { return text }
        
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: ""
        )
    }
    
    private func removeLikeFiller(_ text: String) -> String {
        guard let regex = likeFillerRegex else { return text }
        
        let range = NSRange(text.startIndex..., in: text)
        // Replace with single space to maintain word separation
        return regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: " "
        )
    }
    
    private func normalizeWhitespace(_ text: String) -> String {
        // Replace multiple spaces with single space
        var result = text.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        
        // Fix spacing after punctuation
        result = result.replacingOccurrences(
            of: "\\s+([.,!?;:])",
            with: "$1",
            options: .regularExpression
        )
        
        // Fix double punctuation
        result = result.replacingOccurrences(
            of: "([.,!?;:])\\s*([.,!?;:])",
            with: "$1",
            options: .regularExpression
        )
        
        // Trim leading/trailing whitespace
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // NOTE: Do NOT capitalize here - that's FormattingRules' job
        // This keeps Clean mode distinct from Formatted mode
        
        return result
    }
}
