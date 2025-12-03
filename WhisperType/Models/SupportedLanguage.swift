//
//  SupportedLanguage.swift
//  WhisperType
//
//  Supported languages for Whisper transcription.
//

import Foundation

/// Languages supported by Whisper for transcription.
/// Language codes follow ISO 639-1 standard.
enum SupportedLanguage: String, CaseIterable, Identifiable {
    case auto = "auto"
    case english = "en"
    case chinese = "zh"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case japanese = "ja"
    case korean = "ko"
    case portuguese = "pt"
    case russian = "ru"
    case italian = "it"
    case dutch = "nl"
    case polish = "pl"
    case turkish = "tr"
    case arabic = "ar"
    case hindi = "hi"
    
    var id: String { rawValue }
    
    /// Display name for the language
    var displayName: String {
        switch self {
        case .auto: return "Auto-detect"
        case .english: return "English"
        case .chinese: return "Chinese (Mandarin)"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .portuguese: return "Portuguese"
        case .russian: return "Russian"
        case .italian: return "Italian"
        case .dutch: return "Dutch"
        case .polish: return "Polish"
        case .turkish: return "Turkish"
        case .arabic: return "Arabic"
        case .hindi: return "Hindi"
        }
    }
    
    /// Language code to pass to Whisper (nil for auto-detect)
    var whisperCode: String? {
        switch self {
        case .auto: return nil
        default: return rawValue
        }
    }
    
    /// Initialize from a stored string value
    init(fromStored value: String?) {
        if let value = value, let language = SupportedLanguage(rawValue: value) {
            self = language
        } else {
            self = .english // Default to English
        }
    }
}
