//
//  AppDelegate.swift
//  WhisperType
//
//  Application delegate for lifecycle management and coordination.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    var appCoordinator: AppCoordinator {
        AppCoordinator.shared
    }
    
    // Reference to settings window
    private var settingsWindow: NSWindow?
    
    // Shared instance for access from other parts of the app
    static var shared: AppDelegate?

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("WhisperType: Application launched")
        
        // Store shared instance
        AppDelegate.shared = self

        // Configure app as agent (menu bar only, no dock icon)
        // This is also set via LSUIElement in Info.plist, but we can ensure it here
        NSApp.setActivationPolicy(.accessory)

        // Initialize and start the app coordinator asynchronously
        Task { @MainActor in
            await appCoordinator.start()
            
            // Check permissions after coordinator is started
            await checkInitialPermissions()
            
            print("WhisperType: Ready! Press hotkey to toggle recording.")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("WhisperType: Application terminating")

        // Cleanup
        appCoordinator.cleanup()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When the app is activated without visible windows (e.g., clicking dock icon if visible)
        // Just return true to let the menu bar handle it
        return true
    }
    
    // MARK: - Settings Window
    
    func showSettingsWindow() {
        // Bring app to foreground
        NSApp.activate(ignoringOtherApps: true)
        
        // Try to find existing settings window
        if let existingWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        // Create new settings window if it doesn't exist
        if settingsWindow == nil || settingsWindow?.isVisible == false {
            let settingsView = SettingsContainerView()
            let hostingController = NSHostingController(rootView: settingsView)
            
            let window = NSWindow(contentViewController: hostingController)
            window.title = "WhisperType Settings"
            window.identifier = NSUserInterfaceItemIdentifier("settings")
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 550, height: 450))
            window.center()
            
            settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    
    // MARK: - Meeting History Window (Phase 6)
    
    private var meetingHistoryWindow: NSWindow?
    
    func showMeetingHistoryWindow() {
        // Bring app to foreground
        NSApp.activate(ignoringOtherApps: true)
        
        // Try to find existing meeting history window
        if let existingWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "meetingHistory" }) {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        // Create new meeting history window if it doesn't exist
        if meetingHistoryWindow == nil || meetingHistoryWindow?.isVisible == false {
            let historyView = MeetingHistoryView()
            let hostingController = NSHostingController(rootView: historyView)
            
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Meeting History"
            window.identifier = NSUserInterfaceItemIdentifier("meetingHistory")
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 900, height: 600))
            window.minSize = NSSize(width: 700, height: 400)
            window.center()
            
            meetingHistoryWindow = window
        }
        
        meetingHistoryWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Permission Checking

    @MainActor
    private func checkInitialPermissions() async {
        let permissions = Permissions.shared

        // Check microphone permission
        if permissions.microphonePermission == .notDetermined {
            print("WhisperType: Requesting microphone permission...")
            let granted = await permissions.requestMicrophonePermission()
            if granted {
                print("WhisperType: Microphone permission granted")
            } else {
                print("WhisperType: Microphone permission denied")
                appCoordinator.showNotification("Microphone permission denied. Grant access in System Settings.", type: .warning)
            }
        } else if permissions.microphonePermission == .denied {
            print("WhisperType: Microphone permission previously denied")
            appCoordinator.showNotification("Microphone access required. Grant access in System Settings.", type: .warning)
        }

        // Check accessibility permission (just warn, don't block)
        if !permissions.accessibilityPermission.isGranted {
            print("WhisperType: Accessibility permission not granted")
            appCoordinator.showNotification("Accessibility access required for text injection. Grant access in System Settings.", type: .warning, duration: 6.0)
        }
    }
}
