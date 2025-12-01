//
//  HotkeyManager.swift
//  WhisperType
//
//  Manages global hotkey registration and handling using the HotKey library.
//

import Foundation
import AppKit
import HotKey
import UserNotifications

@MainActor
class HotkeyManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = HotkeyManager()
    
    // MARK: - Properties
    
    private var hotKey: HotKey?
    private var isRegistered = false
    
    @Published var isRecording = false
    @Published var isProcessing = false  // Prevents re-trigger while transcribing
    @Published var lastError: String?
    
    // Callback for when recording should start/stop
    var onRecordingToggle: ((Bool) -> Void)?
    
    // MARK: - Initialization
    
    private init() {
        print("HotkeyManager: Initializing...")
        requestNotificationPermission()
    }
    
    // MARK: - Setup
    
    /// Register the hotkey based on current AppSettings
    func registerHotkey() {
        let settings = AppSettings.shared
        
        print("HotkeyManager: Registering hotkey...")
        print("  KeyCode: \(settings.hotkeyKeyCode)")
        print("  Modifiers: \(settings.hotkeyModifierFlags.rawValue)")
        print("  Mode: \(settings.hotkeyMode.displayName)")
        
        // Unregister existing hotkey first
        unregisterHotkey()
        
        // Convert NSEvent.ModifierFlags to HotKey's expected format
        guard let key = keyFromKeyCode(settings.hotkeyKeyCode) else {
            let errorMsg = "Invalid key code: \(settings.hotkeyKeyCode)"
            print("HotkeyManager: \(errorMsg)")
            showError(errorMsg)
            return
        }
        
        let modifiers = convertModifiers(settings.hotkeyModifierFlags)
        
        // Create the hotkey
        hotKey = HotKey(key: key, modifiers: modifiers)
        
        // Set up handlers based on mode
        setupHandlers(mode: settings.hotkeyMode)
        
        isRegistered = true
        print("HotkeyManager: Hotkey registered successfully (\(key) + modifiers)")
    }
    
    /// Unregister the current hotkey
    func unregisterHotkey() {
        if hotKey != nil {
            hotKey?.keyDownHandler = nil
            hotKey?.keyUpHandler = nil
            hotKey = nil
            isRegistered = false
            print("HotkeyManager: Hotkey unregistered")
        }
    }
    
    // MARK: - Handler Setup
    
    private func setupHandlers(mode: HotkeyMode) {
        guard let hotKey = hotKey else { return }
        
        switch mode {
        case .toggle:
            setupToggleMode(hotKey)
        case .hold:
            setupHoldMode(hotKey)
        }
    }
    
    private func setupToggleMode(_ hotKey: HotKey) {
        print("HotkeyManager: Setting up toggle mode handlers")
        
        hotKey.keyDownHandler = { [weak self] in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.toggleRecording()
            }
        }
        
        // No key up handler needed for toggle mode
        hotKey.keyUpHandler = nil
    }
    
    private func setupHoldMode(_ hotKey: HotKey) {
        print("HotkeyManager: Setting up hold mode handlers")
        
        hotKey.keyDownHandler = { [weak self] in
            guard let self = self else { return }
            
            Task { @MainActor in
                if !self.isRecording {
                    self.startRecording()
                }
            }
        }
        
        hotKey.keyUpHandler = { [weak self] in
            guard let self = self else { return }
            
            Task { @MainActor in
                if self.isRecording {
                    self.stopRecording()
                }
            }
        }
    }
    
    // MARK: - Recording Control
    
    private func toggleRecording() {
        // Prevent re-trigger while processing
        if isProcessing {
            print("HotkeyManager: ⚠️ Ignoring hotkey - still processing previous transcription")
            return
        }
        
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        // Prevent starting while processing
        if isProcessing {
            print("HotkeyManager: ⚠️ Cannot start recording - still processing")
            return
        }
        
        print("HotkeyManager: 🎤 Starting recording...")
        isRecording = true
        
        // Show notification for testing
        showNotification(title: "WhisperType", body: "🎤 Recording started...")
        
        // Notify callback
        onRecordingToggle?(true)
    }
    
    private func stopRecording() {
        print("HotkeyManager: ⏹️ Stopping recording...")
        isRecording = false
        isProcessing = true  // Mark as processing until transcription completes
        
        // Show notification for testing
        showNotification(title: "WhisperType", body: "⏹️ Recording stopped, transcribing...")
        
        // Notify callback
        onRecordingToggle?(false)
    }
    
    /// Called when transcription is complete (from AppCoordinator)
    func transcriptionDidComplete() {
        print("HotkeyManager: ✅ Transcription complete, ready for next recording")
        isProcessing = false
    }
    
    // MARK: - Hotkey Update
    
    /// Update the hotkey configuration
    func updateHotkey(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        print("HotkeyManager: Updating hotkey to keyCode=\(keyCode), modifiers=\(modifiers.rawValue)")
        
        // Update settings
        let settings = AppSettings.shared
        settings.hotkeyKeyCode = keyCode
        settings.hotkeyModifierFlags = modifiers
        
        // Re-register with new settings
        registerHotkey()
    }
    
    /// Update the hotkey mode
    func updateHotkeyMode(_ mode: HotkeyMode) {
        print("HotkeyManager: Updating hotkey mode to \(mode.displayName)")
        
        let settings = AppSettings.shared
        settings.hotkeyMode = mode
        
        // Re-setup handlers with new mode
        if let hotKey = hotKey {
            setupHandlers(mode: mode)
        }
    }
    
    /// Reset hotkey to defaults
    func resetToDefaults() {
        print("HotkeyManager: Resetting hotkey to defaults")
        updateHotkey(
            keyCode: Constants.Defaults.hotkeyKeyCode,
            modifiers: Constants.Defaults.hotkeyModifierFlags
        )
    }
    
    // MARK: - Key Conversion Helpers
    
    /// Convert a virtual key code to HotKey's Key enum
    private func keyFromKeyCode(_ keyCode: UInt32) -> Key? {
        // Common key codes (macOS virtual key codes)
        switch keyCode {
        case 49: return .space
        case 36: return .return
        case 48: return .tab
        case 51: return .delete
        case 53: return .escape
        case 0: return .a
        case 11: return .b
        case 8: return .c
        case 2: return .d
        case 14: return .e
        case 3: return .f
        case 5: return .g
        case 4: return .h
        case 34: return .i
        case 38: return .j
        case 40: return .k
        case 37: return .l
        case 46: return .m
        case 45: return .n
        case 31: return .o
        case 35: return .p
        case 12: return .q
        case 15: return .r
        case 1: return .s
        case 17: return .t
        case 32: return .u
        case 9: return .v
        case 13: return .w
        case 7: return .x
        case 16: return .y
        case 6: return .z
        case 18: return .one
        case 19: return .two
        case 20: return .three
        case 21: return .four
        case 23: return .five
        case 22: return .six
        case 26: return .seven
        case 28: return .eight
        case 25: return .nine
        case 29: return .zero
        case 122: return .f1
        case 120: return .f2
        case 99: return .f3
        case 118: return .f4
        case 96: return .f5
        case 97: return .f6
        case 98: return .f7
        case 100: return .f8
        case 101: return .f9
        case 109: return .f10
        case 103: return .f11
        case 111: return .f12
        default:
            print("HotkeyManager: Unknown key code: \(keyCode)")
            return nil
        }
    }
    
    /// Convert NSEvent.ModifierFlags to HotKey's NSEvent.ModifierFlags
    /// (They're the same type, but we filter to only relevant modifiers)
    private func convertModifiers(_ flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        var result: NSEvent.ModifierFlags = []
        
        if flags.contains(.command) {
            result.insert(.command)
        }
        if flags.contains(.option) {
            result.insert(.option)
        }
        if flags.contains(.control) {
            result.insert(.control)
        }
        if flags.contains(.shift) {
            result.insert(.shift)
        }
        
        return result
    }
    
    // MARK: - Notifications (for testing feedback)
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("HotkeyManager: Notification permission granted")
            } else if let error = error {
                print("HotkeyManager: Notification permission error: \(error)")
            }
        }
    }
    
    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil // No sound for quick feedback
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("HotkeyManager: Failed to show notification: \(error)")
            }
        }
    }
    
    // MARK: - Error Handling
    
    private func showError(_ message: String) {
        lastError = message
        
        // Show alert on main thread
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Hotkey Registration Failed"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Open Settings")
            
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                // TODO: Open settings window to hotkey tab
                print("HotkeyManager: User requested to open settings")
            }
        }
    }
    
    // MARK: - Status
    
    var hotkeyDescription: String {
        let settings = AppSettings.shared
        var parts: [String] = []
        
        let modifiers = settings.hotkeyModifierFlags
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        
        if let key = keyFromKeyCode(settings.hotkeyKeyCode) {
            parts.append(keyDisplayName(key))
        } else {
            parts.append("?")
        }
        
        return parts.joined(separator: "")
    }
    
    private func keyDisplayName(_ key: Key) -> String {
        switch key {
        case .space: return "Space"
        case .return: return "↩"
        case .tab: return "⇥"
        case .delete: return "⌫"
        case .escape: return "⎋"
        default: return key.description.uppercased()
        }
    }
    
    // MARK: - Debug
    
    func printStatus() {
        print("=== HotkeyManager Status ===")
        print("  Registered: \(isRegistered)")
        print("  Recording: \(isRecording)")
        print("  Hotkey: \(hotkeyDescription)")
        print("  Mode: \(AppSettings.shared.hotkeyMode.displayName)")
        print("============================")
    }
}
