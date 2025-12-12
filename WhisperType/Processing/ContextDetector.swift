//
//  ContextDetector.swift
//  WhisperType
//
//  Detects the frontmost application for app-aware context.
//  Uses NSWorkspace for reliable app detection on macOS.
//

import Foundation
import AppKit

/// Detects the current application context for app-aware processing
class ContextDetector {
    
    // MARK: - Singleton
    
    static let shared = ContextDetector()
    
    private init() {}
    
    // MARK: - Detection
    
    /// Detect the currently frontmost application
    /// - Returns: AppInfo for the frontmost app, or .unknown if detection fails
    func detectFrontmostApp() -> AppInfo {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            print("ContextDetector: No frontmost application detected")
            return .unknown
        }
        
        guard let appInfo = AppInfo(from: frontApp) else {
            print("ContextDetector: Could not create AppInfo from frontmost app")
            return .unknown
        }
        
        print("ContextDetector: Detected frontmost app: \(appInfo.name) (\(appInfo.bundleIdentifier))")
        return appInfo
    }
    
    /// Get all currently running applications (excluding background/system apps)
    /// - Returns: Array of AppInfo for user-facing running applications
    func getRunningApps() -> [AppInfo] {
        let runningApps = NSWorkspace.shared.runningApplications
        
        return runningApps.compactMap { app -> AppInfo? in
            // Filter to only regular (user-facing) applications
            guard app.activationPolicy == .regular else { return nil }
            return AppInfo(from: app)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    /// Get applications from /Applications folder
    /// - Returns: Array of AppInfo for installed applications
    func getInstalledApps() -> [AppInfo] {
        let fileManager = FileManager.default
        var apps: [AppInfo] = []
        
        // Search in /Applications
        let applicationsURL = URL(fileURLWithPath: "/Applications")
        if let contents = try? fileManager.contentsOfDirectory(
            at: applicationsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for url in contents where url.pathExtension == "app" {
                if let appInfo = AppInfo(from: url) {
                    apps.append(appInfo)
                }
            }
        }
        
        // Search in ~/Applications
        if let userAppsURL = fileManager.urls(for: .applicationDirectory, in: .userDomainMask).first {
            if let contents = try? fileManager.contentsOfDirectory(
                at: userAppsURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) {
                for url in contents where url.pathExtension == "app" {
                    if let appInfo = AppInfo(from: url) {
                        apps.append(appInfo)
                    }
                }
            }
        }
        
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    /// Find an app by bundle identifier from installed apps
    /// - Parameter bundleIdentifier: The bundle ID to search for
    /// - Returns: AppInfo if found, nil otherwise
    func findApp(byBundleIdentifier bundleIdentifier: String) -> AppInfo? {
        // First try to get URL from workspace
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return AppInfo(from: appURL)
        }
        
        // Search in running apps
        if let runningApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == bundleIdentifier
        }) {
            return AppInfo(from: runningApp)
        }
        
        return nil
    }
}
