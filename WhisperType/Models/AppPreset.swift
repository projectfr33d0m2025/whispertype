//
//  AppPreset.swift
//  WhisperType
//
//  Defines default app presets for app-aware processing.
//  These are the built-in defaults that ship with WhisperType.
//

import Foundation

/// A default preset for a known application
struct AppPreset: Codable, Identifiable, Hashable {
    /// Bundle identifier (e.g., "com.apple.Terminal")
    let bundleIdentifier: String
    
    /// Display name for the app
    let displayName: String
    
    /// Default processing mode for this app
    let defaultMode: ProcessingMode
    
    /// Category this app belongs to
    let category: AppCategory
    
    /// Rationale for why this mode was chosen
    let rationale: String
    
    var id: String { bundleIdentifier }
    
    // MARK: - Initialization
    
    init(
        bundleIdentifier: String,
        displayName: String,
        defaultMode: ProcessingMode,
        category: AppCategory,
        rationale: String
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.defaultMode = defaultMode
        self.category = category
        self.rationale = rationale
    }
}

// MARK: - App Category

/// Categories for organizing app presets
enum AppCategory: String, Codable, CaseIterable {
    case development
    case email
    case messaging
    case browsers
    case documents
    case spreadsheets
    case other
    
    var displayName: String {
        switch self {
        case .development: return "Development"
        case .email: return "Email"
        case .messaging: return "Messaging"
        case .browsers: return "Browsers"
        case .documents: return "Documents"
        case .spreadsheets: return "Spreadsheets"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .development: return "terminal"
        case .email: return "envelope"
        case .messaging: return "bubble.left.and.bubble.right"
        case .browsers: return "globe"
        case .documents: return "doc.text"
        case .spreadsheets: return "tablecells"
        case .other: return "app"
        }
    }
}
