//
//  TextInjector.swift
//  WhisperType
//
//  Handles injecting transcribed text at the current cursor position
//  using CGEvent keyboard simulation or clipboard fallback.
//

import Foundation
import AppKit
import Carbon.HIToolbox

/// Errors that can occur during text injection
enum TextInjectionError: LocalizedError {
    case accessibilityNotGranted
    case eventSourceCreationFailed
    case eventCreationFailed
    case clipboardOperationFailed
    case emptyText
    
    var errorDescription: String? {
        switch self {
        case .accessibilityNotGranted:
            return "Accessibility permission is required to inject text. Please grant permission in System Settings."
        case .eventSourceCreationFailed:
            return "Failed to create event source for keyboard simulation."
        case .eventCreationFailed:
            return "Failed to create keyboard event."
        case .clipboardOperationFailed:
            return "Failed to perform clipboard operation."
        case .emptyText:
            return "No text to inject."
        }
    }
}

/// Injection method preference
enum InjectionMethod {
    case keyboard      // CGEvent keyboard simulation (character by character)
    case clipboard     // Clipboard + Cmd+V (faster for long text)
    case auto          // Automatically choose based on text length
}


/// Manages text injection into any application using keyboard simulation
@MainActor
class TextInjector: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = TextInjector()
    
    // MARK: - Published Properties
    
    @Published var isInjecting = false
    @Published var lastError: TextInjectionError?
    
    // MARK: - Configuration
    
    /// Delay between character injections (in seconds). 0 = no delay.
    /// Increase if target apps drop characters.
    var characterDelay: TimeInterval = 0
    
    /// Text length threshold for auto-switching to clipboard method
    var clipboardThreshold: Int = 50
    
    /// Whether to restore clipboard contents after clipboard injection
    var restoreClipboard: Bool = true
    
    /// Delay before restoring clipboard (in seconds)
    var clipboardRestoreDelay: TimeInterval = 0.1
    
    // MARK: - Private Properties
    
    private let permissions = Permissions.shared
    
    // MARK: - Initialization
    
    private init() {
        print("TextInjector: Initialized")
    }
    
    // MARK: - Permission Checking
    
    /// Check if accessibility permission is granted
    var hasAccessibilityPermission: Bool {
        return AXIsProcessTrusted()
    }
    
    /// Check permission and prompt user if not granted
    /// Returns true if permission is granted, false otherwise
    func checkAndRequestPermission() -> Bool {
        if hasAccessibilityPermission {
            return true
        }
        
        // Prompt system dialog for accessibility permission
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if !trusted {
            // Show our custom alert explaining why permission is needed
            showAccessibilityPermissionAlert()
        }
        
        return trusted
    }

    
    /// Show alert explaining accessibility permission requirement
    private func showAccessibilityPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
            WhisperType needs Accessibility permission to type transcribed text into other applications.
            
            Please grant permission in System Settings → Privacy & Security → Accessibility.
            
            After granting permission, you may need to restart WhisperType.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }
    
    /// Show error alert for injection failures
    func showErrorAlert(error: TextInjectionError) {
        let alert = NSAlert()
        alert.messageText = "Text Injection Failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        
        if case .accessibilityNotGranted = error {
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "OK")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                openAccessibilitySettings()
            }
        } else {
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    /// Open System Settings to Accessibility pane
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    
    // MARK: - Main Injection Interface
    
    /// Inject text at current cursor position
    /// - Parameters:
    ///   - text: The text to inject
    ///   - method: Injection method (.keyboard, .clipboard, or .auto)
    /// - Throws: TextInjectionError if injection fails
    func injectText(_ text: String, method: InjectionMethod = .auto) async throws {
        // Validate input
        guard !text.isEmpty else {
            throw TextInjectionError.emptyText
        }
        
        // Check permission
        guard hasAccessibilityPermission else {
            lastError = .accessibilityNotGranted
            showErrorAlert(error: .accessibilityNotGranted)
            throw TextInjectionError.accessibilityNotGranted
        }
        
        isInjecting = true
        defer { isInjecting = false }
        
        // Choose method
        let selectedMethod: InjectionMethod
        switch method {
        case .auto:
            // Use clipboard for long text, keyboard for short text
            selectedMethod = text.count > clipboardThreshold ? .clipboard : .keyboard
        case .keyboard, .clipboard:
            selectedMethod = method
        }
        
        print("TextInjector: Injecting \(text.count) characters using \(selectedMethod) method")
        
        // Perform injection
        switch selectedMethod {
        case .keyboard:
            try await injectViaKeyboard(text)
        case .clipboard:
            try await injectViaClipboard(text)
        case .auto:
            // Already resolved above, won't reach here
            break
        }
        
        print("TextInjector: Injection complete")
    }

    
    // MARK: - Keyboard Injection (Phase 5.2)
    
    /// Inject text using CGEvent keyboard simulation
    /// - Parameter text: Text to inject character by character
    private func injectViaKeyboard(_ text: String) async throws {
        // Create event source
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            lastError = .eventSourceCreationFailed
            throw TextInjectionError.eventSourceCreationFailed
        }
        
        // Process text, normalizing line endings
        let normalizedText = text
            .replacingOccurrences(of: "\r\n", with: "\n")  // Windows → Unix
            .replacingOccurrences(of: "\r", with: "\n")    // Old Mac → Unix
        
        // Inject each character
        for character in normalizedText {
            try await injectCharacter(character, eventSource: eventSource)
            
            // Optional delay between characters
            if characterDelay > 0 {
                try await Task.sleep(nanoseconds: UInt64(characterDelay * 1_000_000_000))
            }
        }
    }
    
    /// Inject a single character using CGEvent
    /// - Parameters:
    ///   - character: The character to inject
    ///   - eventSource: The CGEventSource to use
    private func injectCharacter(_ character: Character, eventSource: CGEventSource) async throws {
        if character == "\n" {
            // Handle newline as Enter key press
            try await injectKeyPress(keyCode: CGKeyCode(kVK_Return), eventSource: eventSource)
        } else if character == "\t" {
            // Handle tab
            try await injectKeyPress(keyCode: CGKeyCode(kVK_Tab), eventSource: eventSource)
        } else {
            // Handle regular character using Unicode
            try await injectUnicodeCharacter(character, eventSource: eventSource)
        }
    }
    
    /// Inject a key press (keyDown + keyUp) for a specific key code
    /// - Parameters:
    ///   - keyCode: The virtual key code
    ///   - eventSource: The CGEventSource to use
    ///   - modifiers: Optional modifier flags (e.g., for Shift, Cmd)
    private func injectKeyPress(
        keyCode: CGKeyCode,
        eventSource: CGEventSource,
        modifiers: CGEventFlags = []
    ) async throws {
        // Create key down event
        guard let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true) else {
            lastError = .eventCreationFailed
            throw TextInjectionError.eventCreationFailed
        }
        
        // Create key up event
        guard let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false) else {
            lastError = .eventCreationFailed
            throw TextInjectionError.eventCreationFailed
        }
        
        // Apply modifiers if any
        if !modifiers.isEmpty {
            keyDown.flags = modifiers
            keyUp.flags = modifiers
        }
        
        // Post events
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
    
    /// Inject a Unicode character using CGEvent's Unicode input method
    /// - Parameters:
    ///   - character: The character to inject
    ///   - eventSource: The CGEventSource to use
    private func injectUnicodeCharacter(_ character: Character, eventSource: CGEventSource) async throws {
        // Convert character to UTF-16 code units (handles emoji and international chars)
        let utf16Units = Array(String(character).utf16)
        
        // Create key down event (we use a dummy key code, the Unicode data is what matters)
        guard let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: true) else {
            lastError = .eventCreationFailed
            throw TextInjectionError.eventCreationFailed
        }
        
        // Create key up event
        guard let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: false) else {
            lastError = .eventCreationFailed
            throw TextInjectionError.eventCreationFailed
        }
        
        // Set the Unicode string on the key down event
        keyDown.keyboardSetUnicodeString(stringLength: utf16Units.count, unicodeString: utf16Units)
        keyUp.keyboardSetUnicodeString(stringLength: utf16Units.count, unicodeString: utf16Units)
        
        // Post events
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
    
    // MARK: - Clipboard Injection (Phase 5.3)
    
    /// Inject text using clipboard and Cmd+V
    /// - Parameter text: Text to paste
    private func injectViaClipboard(_ text: String) async throws {
        // TODO: Phase 5.3 - Implement clipboard injection
        // Placeholder implementation for testing permission flow
        print("TextInjector: Clipboard injection not yet fully implemented")
        print("TextInjector: Would inject: \"\(text.prefix(50))...\"")
        
        // Small delay to simulate injection
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    // MARK: - Testing
    
    /// Test text injection with a sample string
    /// Use this to verify permissions and basic functionality
    func injectTestString() async {
        let testText = "Hello from WhisperType! 🎤"
        
        print("TextInjector: Starting test injection...")
        print("TextInjector: Test string: \"\(testText)\"")
        print("TextInjector: Accessibility permission: \(hasAccessibilityPermission)")
        
        do {
            try await injectText(testText, method: .auto)
            print("TextInjector: Test injection successful!")
        } catch {
            print("TextInjector: Test injection failed: \(error.localizedDescription)")
        }
    }
    
    /// Check accessibility permission status and print diagnostic info
    func printDiagnostics() {
        print("=== TextInjector Diagnostics ===")
        print("Accessibility Permission: \(hasAccessibilityPermission ? "✅ Granted" : "❌ Not Granted")")
        print("Character Delay: \(characterDelay)s")
        print("Clipboard Threshold: \(clipboardThreshold) characters")
        print("Restore Clipboard: \(restoreClipboard)")
        print("Is Currently Injecting: \(isInjecting)")
        if let error = lastError {
            print("Last Error: \(error.localizedDescription)")
        }
        print("================================")
    }
}
