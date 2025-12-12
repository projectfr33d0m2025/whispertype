//
//  AppInfo.swift
//  WhisperType
//
//  Represents information about a macOS application for app-aware context detection.
//

import Foundation
import AppKit

/// Information about a detected application
struct AppInfo: Codable, Equatable, Hashable, Identifiable {
    /// Bundle identifier (e.g., "com.apple.Terminal")
    let bundleIdentifier: String
    
    /// Localized display name (e.g., "Terminal")
    let name: String
    
    /// Path to the application bundle (optional, for icon retrieval)
    var bundlePath: String?
    
    var id: String { bundleIdentifier }
    
    // MARK: - Initialization
    
    init(bundleIdentifier: String, name: String, bundlePath: String? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.bundlePath = bundlePath
    }
    
    /// Create from a running application
    init?(from app: NSRunningApplication) {
        guard let bundleId = app.bundleIdentifier else { return nil }
        
        self.bundleIdentifier = bundleId
        self.name = app.localizedName ?? bundleId
        self.bundlePath = app.bundleURL?.path
    }
    
    /// Create from a bundle URL
    init?(from bundleURL: URL) {
        guard let bundle = Bundle(url: bundleURL),
              let bundleId = bundle.bundleIdentifier else {
            return nil
        }
        
        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? bundleURL.deletingPathExtension().lastPathComponent
        
        self.bundleIdentifier = bundleId
        self.name = displayName
        self.bundlePath = bundleURL.path
    }
    
    // MARK: - Icon Retrieval
    
    /// Get the application icon (non-Codable, computed at runtime)
    var icon: NSImage? {
        // Try to get icon from bundle path first
        if let path = bundlePath {
            return NSWorkspace.shared.icon(forFile: path)
        }
        
        // Try to find the app by bundle identifier
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        
        // Fallback to generic app icon
        return NSWorkspace.shared.icon(forFile: "/Applications")
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case bundleIdentifier
        case name
        case bundlePath
    }
}

// MARK: - Unknown App

extension AppInfo {
    /// Represents an unknown or undetectable application
    static let unknown = AppInfo(
        bundleIdentifier: "unknown",
        name: "Unknown App",
        bundlePath: nil
    )
    
    /// Check if this is the unknown app placeholder
    var isUnknown: Bool {
        bundleIdentifier == "unknown"
    }
}
