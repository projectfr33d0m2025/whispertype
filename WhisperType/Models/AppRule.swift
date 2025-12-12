//
//  AppRule.swift
//  WhisperType
//
//  User-defined app rules that override default presets.
//

import Foundation

/// A user-defined rule for a specific application
struct AppRule: Codable, Identifiable, Hashable {
    /// Bundle identifier for the app
    let bundleIdentifier: String
    
    /// User's chosen processing mode
    var mode: ProcessingMode
    
    /// Display name (stored for apps not in presets)
    var displayName: String
    
    /// When this rule was created
    let createdAt: Date
    
    /// When this rule was last modified
    var modifiedAt: Date
    
    var id: String { bundleIdentifier }
    
    // MARK: - Initialization
    
    init(
        bundleIdentifier: String,
        mode: ProcessingMode,
        displayName: String,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.mode = mode
        self.displayName = displayName
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
    
    /// Create a rule from an AppInfo
    init(from appInfo: AppInfo, mode: ProcessingMode) {
        self.bundleIdentifier = appInfo.bundleIdentifier
        self.mode = mode
        self.displayName = appInfo.name
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    /// Create a rule from an AppPreset (for overriding)
    init(from preset: AppPreset, mode: ProcessingMode) {
        self.bundleIdentifier = preset.bundleIdentifier
        self.mode = mode
        self.displayName = preset.displayName
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    // MARK: - Mutation
    
    /// Update the mode and modification date
    mutating func updateMode(_ newMode: ProcessingMode) {
        self.mode = newMode
        self.modifiedAt = Date()
    }
}
