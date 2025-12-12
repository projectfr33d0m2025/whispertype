//
//  ProcessingMode.swift
//  WhisperType
//
//  Defines the five processing modes for text enhancement.
//  From raw transcription to professionally formatted output.
//

import Foundation

/// Processing modes for text enhancement after transcription.
/// Each mode provides a different level of text cleanup and enhancement.
enum ProcessingMode: String, Codable, CaseIterable, Identifiable {
    case raw
    case clean
    case formatted
    case polished
    case professional
    
    var id: String { rawValue }
    
    // MARK: - Display Properties
    
    /// User-friendly display name
    var displayName: String {
        switch self {
        case .raw: return "Raw"
        case .clean: return "Clean"
        case .formatted: return "Formatted"
        case .polished: return "Polished"
        case .professional: return "Professional"
        }
    }
    
    /// Detailed description of what this mode does
    var description: String {
        switch self {
        case .raw:
            return "Exact Whisper output with no modifications. Best for code dictation or debugging."
        case .clean:
            return "Removes filler words (um, uh, like) and false starts. Keeps your natural tone."
        case .formatted:
            return "Cleans up punctuation and capitalization. Great for everyday use."
        case .polished:
            return "Full grammar and clarity improvements while preserving your meaning."
        case .professional:
            return "Formal tone with complete sentences. Perfect for business communication."
        }
    }
    
    /// Short description for compact UI
    var shortDescription: String {
        switch self {
        case .raw: return "No changes"
        case .clean: return "Remove fillers"
        case .formatted: return "Clean + punctuation"
        case .polished: return "Grammar + clarity"
        case .professional: return "Formal + complete"
        }
    }
    
    /// SF Symbol icon name for this mode
    var icon: String {
        switch self {
        case .raw: return "doc.text"
        case .clean: return "sparkles"
        case .formatted: return "text.alignleft"
        case .polished: return "wand.and.stars"
        case .professional: return "briefcase"
        }
    }
    
    /// Emoji icon alternative
    var emoji: String {
        switch self {
        case .raw: return "📝"
        case .clean: return "✨"
        case .formatted: return "📋"
        case .polished: return "💫"
        case .professional: return "💼"
        }
    }
    
    // MARK: - Processing Requirements
    
    /// Whether this mode requires LLM for full functionality
    var requiresLLM: Bool {
        switch self {
        case .raw, .clean, .formatted:
            return false
        case .polished, .professional:
            return true
        }
    }
    
    /// The fallback mode when LLM is unavailable
    var fallbackMode: ProcessingMode {
        switch self {
        case .raw, .clean, .formatted:
            return self // No fallback needed
        case .polished, .professional:
            return .formatted // Fall back to formatted when LLM unavailable
        }
    }
    
    /// Whether filler removal is applied in this mode
    var removesFiller: Bool {
        switch self {
        case .raw:
            return false
        case .clean, .formatted, .polished, .professional:
            return true
        }
    }
    
    /// Whether formatting rules are applied in this mode
    var appliesFormatting: Bool {
        switch self {
        case .raw, .clean:
            return false
        case .formatted, .polished, .professional:
            return true
        }
    }
    
    // MARK: - UI Helpers
    
    /// Badge text to show in UI (e.g., "Recommended", "AI Required")
    var badge: String? {
        switch self {
        case .formatted:
            return "Recommended"
        case .polished, .professional:
            return "AI Required"
        default:
            return nil
        }
    }
    
    /// Whether this is the recommended default mode
    var isRecommended: Bool {
        self == .formatted
    }
}
