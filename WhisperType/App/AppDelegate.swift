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

    var appCoordinator: AppCoordinator?

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("WhisperType: Application launched")

        // Configure app as agent (menu bar only, no dock icon)
        // This is also set via LSUIElement in Info.plist, but we can ensure it here
        NSApp.setActivationPolicy(.accessory)

        // Initialize the app coordinator
        appCoordinator = AppCoordinator()
        appCoordinator?.start()

        // Check permissions on launch
        Task { @MainActor in
            await checkInitialPermissions()
        }
        
        // Test TextInjector (Phase 5.2 & 5.3 testing)
        Task { @MainActor in
            let injector = TextInjector.shared
            injector.printDiagnostics()
            
            let hasPermission = injector.hasAccessibilityPermission
            print("TextInjector: Permission status: \(hasPermission ? "✅ Granted" : "❌ Not Granted")")
            
            if hasPermission {
                // Test 1: Keyboard method (short text)
                print("\n⏳ TEST 1: Keyboard injection in 3 seconds...")
                print("👆 Click on a text field NOW! (Notes, TextEdit, browser search bar, etc.)")
                
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 second delay
                
                print("🚀 Injecting via KEYBOARD method...")
                await injector.injectTestString()
                
                // Test 2: Clipboard method (longer text)
                print("\n⏳ TEST 2: Clipboard injection in 3 seconds...")
                print("👆 Stay in the same text field or click another one!")
                
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 second delay
                
                print("🚀 Injecting via CLIPBOARD method...")
                await injector.injectTestStringViaClipboard()
                
                print("\n✅ All tests complete!")
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("WhisperType: Application terminating")

        // Cleanup
        appCoordinator?.cleanup()
        appCoordinator = nil
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
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
                showPermissionAlert(for: .microphone)
            }
        } else if permissions.microphonePermission == .denied {
            print("WhisperType: Microphone permission previously denied")
            showPermissionAlert(for: .microphone)
        }

        // Check accessibility permission
        if !permissions.accessibilityPermission.isGranted {
            print("WhisperType: Accessibility permission not granted")
            showPermissionAlert(for: .accessibility)
        }
    }

    // MARK: - Alerts

    @MainActor
    private func showPermissionAlert(for type: Permissions.PermissionType) {
        let alert = NSAlert()
        alert.alertStyle = .warning

        switch type {
        case .microphone:
            alert.messageText = "Microphone Access Required"
            alert.informativeText = "WhisperType needs microphone access to record your voice for transcription. Please grant access in System Settings."
        case .accessibility:
            alert.messageText = "Accessibility Access Required"
            alert.informativeText = "WhisperType needs accessibility access to insert transcribed text into other applications. Please grant access in System Settings."
        }

        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            Permissions.shared.openSystemSettings(for: type)
        }
    }
}
