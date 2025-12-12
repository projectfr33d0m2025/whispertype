//
//  LLMPreference.swift
//  WhisperType
//
//  Defines the user's preference for LLM provider selection.
//

import Foundation

/// User preference for LLM provider selection and fallback behavior.
enum LLMPreference: String, Codable, CaseIterable, Identifiable {
    case localOnly = "localOnly"
    case localFirst = "localFirst"
    case cloudFirst = "cloudFirst"
    case cloudOnly = "cloudOnly"
    case disabled = "disabled"
    
    var id: String { rawValue }
    
    // MARK: - Display Properties
    
    var displayName: String {
        switch self {
        case .localOnly: return "Local Only"
        case .localFirst: return "Local First"
        case .cloudFirst: return "Cloud First"
        case .cloudOnly: return "Cloud Only"
        case .disabled: return "Disabled"
        }
    }
    
    var description: String {
        switch self {
        case .localOnly:
            return "Use only local AI (Ollama). Never send data to cloud."
        case .localFirst:
            return "Try local AI first, fall back to cloud if unavailable."
        case .cloudFirst:
            return "Try cloud AI first for speed, fall back to local."
        case .cloudOnly:
            return "Use only cloud AI (OpenAI). Requires API key."
        case .disabled:
            return "Disable AI enhancement. Use basic processing only."
        }
    }
    
    var icon: String {
        switch self {
        case .localOnly: return "lock.shield"
        case .localFirst: return "shield.checkered"
        case .cloudFirst: return "cloud"
        case .cloudOnly: return "cloud.fill"
        case .disabled: return "xmark.circle"
        }
    }
    
    // MARK: - Provider Logic
    
    /// Whether local provider should be tried
    var usesLocal: Bool {
        switch self {
        case .localOnly, .localFirst:
            return true
        case .cloudFirst:
            return true // As fallback
        case .cloudOnly, .disabled:
            return false
        }
    }
    
    /// Whether cloud provider should be tried
    var usesCloud: Bool {
        switch self {
        case .localOnly, .disabled:
            return false
        case .localFirst:
            return true // As fallback
        case .cloudFirst, .cloudOnly:
            return true
        }
    }
    
    /// Whether any LLM is enabled
    var isEnabled: Bool {
        self != .disabled
    }
    
    /// Whether this preference prioritizes privacy
    var prioritizesPrivacy: Bool {
        switch self {
        case .localOnly, .localFirst:
            return true
        case .cloudFirst, .cloudOnly, .disabled:
            return false
        }
    }
}
