//
//  AppAwareManager.swift
//  WhisperType
//
//  Manages app-aware processing mode selection.
//  Combines default presets with user-defined rules.
//

import Foundation
import Combine

/// Manages app-aware context and processing mode selection
@MainActor
class AppAwareManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = AppAwareManager()
    
    // MARK: - Published Properties
    
    /// User-defined custom rules
    @Published private(set) var customRules: [AppRule] = []
    
    /// Whether app-awareness is enabled
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "appAwarenessEnabled")
        }
    }
    
    /// The currently detected app (updated on each recording)
    @Published private(set) var currentApp: AppInfo = .unknown
    
    // MARK: - Private Properties
    
    private let contextDetector = ContextDetector.shared
    private let storageURL: URL
    
    // MARK: - Initialization
    
    private init() {
        // Set up storage path
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let whisperTypeDir = appSupport.appendingPathComponent("WhisperType")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: whisperTypeDir, withIntermediateDirectories: true)
        
        self.storageURL = whisperTypeDir.appendingPathComponent("app-rules.json")
        
        // Load settings
        self.isEnabled = UserDefaults.standard.object(forKey: "appAwarenessEnabled") as? Bool ?? true
        
        // Load custom rules
        loadRules()
        
        print("AppAwareManager: Initialized with \(customRules.count) custom rules, enabled: \(isEnabled)")
    }
    
    // MARK: - Mode Determination
    
    /// Get the processing mode for a specific app
    /// Priority: custom rule > default preset > global default
    func getModeForApp(_ bundleIdentifier: String) -> ProcessingMode {
        // 1. Check custom rules first
        if let rule = customRules.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            print("AppAwareManager: Using custom rule for \(bundleIdentifier): \(rule.mode.displayName)")
            return rule.mode
        }
        
        // 2. Check default presets
        if let preset = DefaultAppPresets.preset(for: bundleIdentifier) {
            print("AppAwareManager: Using preset for \(bundleIdentifier): \(preset.defaultMode.displayName)")
            return preset.defaultMode
        }
        
        // 3. Fall back to global default
        let globalDefault = AppSettings.shared.processingMode
        print("AppAwareManager: Using global default for \(bundleIdentifier): \(globalDefault.displayName)")
        return globalDefault
    }
    
    /// Get the processing mode for the current frontmost app
    /// Returns global default if app-awareness is disabled
    func getModeForCurrentApp() -> ProcessingMode {
        guard isEnabled else {
            return AppSettings.shared.processingMode
        }
        
        currentApp = contextDetector.detectFrontmostApp()
        
        guard !currentApp.isUnknown else {
            return AppSettings.shared.processingMode
        }
        
        return getModeForApp(currentApp.bundleIdentifier)
    }
    
    /// Detect and cache the current frontmost app
    func detectCurrentApp() {
        currentApp = contextDetector.detectFrontmostApp()
    }
    
    /// Detect the current app and return the appropriate mode
    /// - Parameter globalDefault: The global default processing mode
    /// - Returns: Tuple of detected app (if any) and the effective processing mode
    func detectCurrentAppAndMode(globalDefault: ProcessingMode) -> (app: AppInfo?, mode: ProcessingMode) {
        guard isEnabled else {
            return (nil, globalDefault)
        }
        
        currentApp = contextDetector.detectFrontmostApp()
        
        guard !currentApp.isUnknown else {
            return (nil, globalDefault)
        }
        
        let mode = getModeForApp(currentApp.bundleIdentifier)
        return (currentApp, mode)
    }
    
    /// Clear the current app context (after transcription completes)
    func clearCurrentContext() {
        currentApp = .unknown
    }

    
    // MARK: - Rule Source
    
    /// Describes the source of a mode for a given app
    enum RuleSource {
        case customRule
        case defaultPreset
        case globalDefault
        
        var displayName: String {
            switch self {
            case .customRule: return "Custom"
            case .defaultPreset: return "Default"
            case .globalDefault: return "Global"
            }
        }
    }
    
    /// Get the source of the mode for a given app
    func getRuleSource(for bundleIdentifier: String) -> RuleSource {
        if customRules.contains(where: { $0.bundleIdentifier == bundleIdentifier }) {
            return .customRule
        }
        if DefaultAppPresets.preset(for: bundleIdentifier) != nil {
            return .defaultPreset
        }
        return .globalDefault
    }
    
    // MARK: - Custom Rule Management
    
    /// Set a custom rule for an app
    func setCustomRule(for bundleIdentifier: String, mode: ProcessingMode, displayName: String) {
        if let index = customRules.firstIndex(where: { $0.bundleIdentifier == bundleIdentifier }) {
            // Update existing rule
            customRules[index].updateMode(mode)
        } else {
            // Create new rule
            let rule = AppRule(
                bundleIdentifier: bundleIdentifier,
                mode: mode,
                displayName: displayName
            )
            customRules.append(rule)
        }
        
        saveRules()
        print("AppAwareManager: Set custom rule for \(bundleIdentifier): \(mode.displayName)")
    }
    
    /// Set a custom rule from AppInfo
    func setCustomRule(for appInfo: AppInfo, mode: ProcessingMode) {
        setCustomRule(for: appInfo.bundleIdentifier, mode: mode, displayName: appInfo.name)
    }
    
    /// Remove a custom rule (reverts to preset or global default)
    func removeCustomRule(for bundleIdentifier: String) {
        customRules.removeAll { $0.bundleIdentifier == bundleIdentifier }
        saveRules()
        print("AppAwareManager: Removed custom rule for \(bundleIdentifier)")
    }
    
    /// Reset all custom rules
    func resetAllRules() {
        customRules.removeAll()
        saveRules()
        print("AppAwareManager: Reset all custom rules")
    }
    
    /// Check if an app has a custom rule
    func hasCustomRule(for bundleIdentifier: String) -> Bool {
        customRules.contains { $0.bundleIdentifier == bundleIdentifier }
    }
    
    // MARK: - Combined App List for UI
    
    /// An app entry combining preset and custom rule info
    struct AppEntry: Identifiable {
        let bundleIdentifier: String
        let displayName: String
        let currentMode: ProcessingMode
        let defaultMode: ProcessingMode?
        let source: RuleSource
        let category: AppCategory?
        
        var id: String { bundleIdentifier }
        
        var isCustomized: Bool { source == .customRule }
    }
    
    /// Get all apps (presets + custom rules) for display in settings
    func getAllAppEntries() -> [AppEntry] {
        var entries: [AppEntry] = []
        var seenBundleIds: Set<String> = []
        
        // Add all presets first
        for preset in DefaultAppPresets.all {
            let customMode = customRules.first { $0.bundleIdentifier == preset.bundleIdentifier }?.mode
            let currentMode = customMode ?? preset.defaultMode
            let source: RuleSource = customMode != nil ? .customRule : .defaultPreset
            
            entries.append(AppEntry(
                bundleIdentifier: preset.bundleIdentifier,
                displayName: preset.displayName,
                currentMode: currentMode,
                defaultMode: preset.defaultMode,
                source: source,
                category: preset.category
            ))
            seenBundleIds.insert(preset.bundleIdentifier)
        }
        
        // Add custom rules for apps not in presets
        for rule in customRules where !seenBundleIds.contains(rule.bundleIdentifier) {
            entries.append(AppEntry(
                bundleIdentifier: rule.bundleIdentifier,
                displayName: rule.displayName,
                currentMode: rule.mode,
                defaultMode: nil,
                source: .customRule,
                category: .other
            ))
        }
        
        return entries.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
    
    /// Get app entries grouped by category
    func getAppEntriesByCategory() -> [(category: AppCategory, entries: [AppEntry])] {
        let allEntries = getAllAppEntries()
        var grouped: [AppCategory: [AppEntry]] = [:]
        
        for entry in allEntries {
            let category = entry.category ?? .other
            grouped[category, default: []].append(entry)
        }
        
        return AppCategory.allCases.compactMap { category in
            guard let entries = grouped[category], !entries.isEmpty else { return nil }
            return (category: category, entries: entries)
        }
    }
    
    // MARK: - Persistence
    
    private func loadRules() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            print("AppAwareManager: No rules file found, starting fresh")
            return
        }
        
        do {
            let data = try Data(contentsOf: storageURL)
            customRules = try JSONDecoder().decode([AppRule].self, from: data)
            print("AppAwareManager: Loaded \(customRules.count) custom rules")
        } catch {
            print("AppAwareManager: Failed to load rules: \(error)")
        }
    }
    
    private func saveRules() {
        do {
            let data = try JSONEncoder().encode(customRules)
            try data.write(to: storageURL, options: .atomic)
            print("AppAwareManager: Saved \(customRules.count) custom rules")
        } catch {
            print("AppAwareManager: Failed to save rules: \(error)")
        }
    }
}
