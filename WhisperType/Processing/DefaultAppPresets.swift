//
//  DefaultAppPresets.swift
//  WhisperType
//
//  Contains the 18 default app presets that ship with WhisperType.
//  These provide sensible defaults for common applications.
//

import Foundation

/// Default app presets for common applications
enum DefaultAppPresets {
    
    /// All default presets
    static let all: [AppPreset] = development + email + messaging + browsers + documents + spreadsheets
    
    /// Get a preset by bundle identifier
    static func preset(for bundleIdentifier: String) -> AppPreset? {
        all.first { $0.bundleIdentifier == bundleIdentifier }
    }
    
    /// Get all presets for a category
    static func presets(for category: AppCategory) -> [AppPreset] {
        all.filter { $0.category == category }
    }
    
    // MARK: - Development Apps (Raw/Clean)
    
    static let development: [AppPreset] = [
        AppPreset(
            bundleIdentifier: "com.apple.Terminal",
            displayName: "Terminal",
            defaultMode: .raw,
            category: .development,
            rationale: "Commands need exact input without any modifications"
        ),
        AppPreset(
            bundleIdentifier: "com.microsoft.VSCode",
            displayName: "Visual Studio Code",
            defaultMode: .clean,
            category: .development,
            rationale: "Minimal interference with code, just remove fillers"
        ),
        AppPreset(
            bundleIdentifier: "com.apple.dt.Xcode",
            displayName: "Xcode",
            defaultMode: .clean,
            category: .development,
            rationale: "Minimal interference with code, just remove fillers"
        ),
        AppPreset(
            bundleIdentifier: "com.sublimetext.4",
            displayName: "Sublime Text",
            defaultMode: .clean,
            category: .development,
            rationale: "Minimal interference with code, just remove fillers"
        )
    ]
    
    // MARK: - Email Apps (Professional)
    
    static let email: [AppPreset] = [
        AppPreset(
            bundleIdentifier: "com.apple.mail",
            displayName: "Mail",
            defaultMode: .professional,
            category: .email,
            rationale: "Emails need polished, professional language"
        ),
        AppPreset(
            bundleIdentifier: "com.microsoft.Outlook",
            displayName: "Outlook",
            defaultMode: .professional,
            category: .email,
            rationale: "Business email requires formal communication"
        )
    ]
    
    // MARK: - Messaging Apps (Formatted/Clean)
    
    static let messaging: [AppPreset] = [
        AppPreset(
            bundleIdentifier: "com.tinyspeck.slackmacgap",
            displayName: "Slack",
            defaultMode: .formatted,
            category: .messaging,
            rationale: "Work chat should be punctuated but casual"
        ),
        AppPreset(
            bundleIdentifier: "com.hnc.Discord",
            displayName: "Discord",
            defaultMode: .clean,
            category: .messaging,
            rationale: "Very casual messaging, minimal processing"
        ),
        AppPreset(
            bundleIdentifier: "com.microsoft.teams2",
            displayName: "Microsoft Teams",
            defaultMode: .formatted,
            category: .messaging,
            rationale: "Semi-formal work chat"
        ),
        AppPreset(
            bundleIdentifier: "net.whatsapp.WhatsApp",
            displayName: "WhatsApp",
            defaultMode: .clean,
            category: .messaging,
            rationale: "Casual personal messaging"
        )
    ]
    
    // MARK: - Browser Apps (Formatted)
    
    static let browsers: [AppPreset] = [
        AppPreset(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            defaultMode: .formatted,
            category: .browsers,
            rationale: "General web forms benefit from clean formatting"
        ),
        AppPreset(
            bundleIdentifier: "com.google.Chrome",
            displayName: "Google Chrome",
            defaultMode: .formatted,
            category: .browsers,
            rationale: "General web forms benefit from clean formatting"
        )
    ]
    
    // MARK: - Document Apps (Polished/Formatted)
    
    static let documents: [AppPreset] = [
        AppPreset(
            bundleIdentifier: "com.apple.Notes",
            displayName: "Notes",
            defaultMode: .formatted,
            category: .documents,
            rationale: "Clean personal notes with proper punctuation"
        ),
        AppPreset(
            bundleIdentifier: "com.microsoft.Word",
            displayName: "Microsoft Word",
            defaultMode: .polished,
            category: .documents,
            rationale: "Documents need grammar and clarity improvements"
        ),
        AppPreset(
            bundleIdentifier: "com.apple.iWork.Pages",
            displayName: "Pages",
            defaultMode: .polished,
            category: .documents,
            rationale: "Documents need grammar and clarity improvements"
        ),
        AppPreset(
            bundleIdentifier: "com.apple.TextEdit",
            displayName: "TextEdit",
            defaultMode: .formatted,
            category: .documents,
            rationale: "General text editing with clean formatting"
        )
    ]
    
    // MARK: - Spreadsheet Apps (Raw)
    
    static let spreadsheets: [AppPreset] = [
        AppPreset(
            bundleIdentifier: "com.microsoft.Excel",
            displayName: "Microsoft Excel",
            defaultMode: .raw,
            category: .spreadsheets,
            rationale: "Data entry must be precise, no modifications"
        ),
        AppPreset(
            bundleIdentifier: "com.apple.iWork.Numbers",
            displayName: "Numbers",
            defaultMode: .raw,
            category: .spreadsheets,
            rationale: "Data entry must be precise, no modifications"
        )
    ]
}
