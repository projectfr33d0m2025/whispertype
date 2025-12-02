//
//  HotkeySettingsView.swift
//  WhisperType
//
//  Hotkey settings tab: recorder, mode toggle, reset to defaults.
//

import SwiftUI
import Carbon.HIToolbox

struct HotkeySettingsView: View {
    
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var hotkeyManager = HotkeyManager.shared
    
    @State private var isRecordingHotkey = false
    @State private var recordedKeyCode: UInt32?
    @State private var recordedModifiers: NSEvent.ModifierFlags?
    @State private var hotkeyError: String?
    
    var body: some View {
        Form {
            // MARK: - Current Hotkey Section
            Section {
                HStack {
                    Text("Current Hotkey")
                    Spacer()
                    HotkeyDisplayView(
                        keyCode: settings.hotkeyKeyCode,
                        modifiers: settings.hotkeyModifierFlags
                    )
                }

                // Hotkey Recorder Button
                HotkeyRecorderButton(
                    isRecording: $isRecordingHotkey,
                    recordedKeyCode: $recordedKeyCode,
                    recordedModifiers: $recordedModifiers,
                    onRecorded: { keyCode, modifiers in
                        applyNewHotkey(keyCode: keyCode, modifiers: modifiers)
                    }
                )
                
                if let error = hotkeyError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Button("Reset to Default (⌥Space)") {
                    resetToDefault()
                }
                .buttonStyle(.link)
                .font(.caption)
            } header: {
                Label("Shortcut", systemImage: "keyboard")
            } footer: {
                Text("Click \"Record New Hotkey\" and press your desired key combination.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // MARK: - Recording Mode Section
            Section {
                Picker("Recording Mode", selection: $settings.hotkeyMode) {
                    ForEach(HotkeyMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: settings.hotkeyMode) { newMode in
                    hotkeyManager.updateHotkeyMode(newMode)
                }
            } header: {
                Label("Mode", systemImage: "hand.tap")
            } footer: {
                Text(settings.hotkeyMode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // MARK: - Status Section
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    if hotkeyManager.isRecording {
                        Label("Recording", systemImage: "mic.fill")
                            .foregroundColor(.red)
                    } else if hotkeyManager.isProcessing {
                        Label("Processing", systemImage: "ellipsis.circle")
                            .foregroundColor(.orange)
                    } else {
                        Label("Ready", systemImage: "checkmark.circle")
                            .foregroundColor(.green)
                    }
                }
            } header: {
                Label("Status", systemImage: "info.circle")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Actions
    
    private func applyNewHotkey(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        hotkeyError = nil
        
        // Validate: require at least one modifier
        if modifiers.isEmpty {
            hotkeyError = "Hotkey must include at least one modifier (⌘, ⌥, ⌃, or ⇧)"
            return
        }
        
        // Apply the new hotkey
        hotkeyManager.updateHotkey(keyCode: keyCode, modifiers: modifiers)
        print("HotkeySettings: Applied new hotkey - keyCode: \(keyCode), modifiers: \(modifiers.rawValue)")
    }
    
    private func resetToDefault() {
        hotkeyError = nil
        hotkeyManager.resetToDefaults()
        print("HotkeySettings: Reset to defaults")
    }
}

// MARK: - Hotkey Display View

struct HotkeyDisplayView: View {
    let keyCode: UInt32
    let modifiers: NSEvent.ModifierFlags
    
    var body: some View {
        HStack(spacing: 4) {
            // Modifier symbols
            if modifiers.contains(.control) {
                KeyCapView(symbol: "⌃")
            }
            if modifiers.contains(.option) {
                KeyCapView(symbol: "⌥")
            }
            if modifiers.contains(.shift) {
                KeyCapView(symbol: "⇧")
            }
            if modifiers.contains(.command) {
                KeyCapView(symbol: "⌘")
            }
            
            // Key name
            KeyCapView(symbol: keyName(for: keyCode))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibleHotkeyDescription)
    }
    
    /// Spoken description of the hotkey for VoiceOver
    private var accessibleHotkeyDescription: String {
        var parts: [String] = []
        
        if modifiers.contains(.control) { parts.append("Control") }
        if modifiers.contains(.option) { parts.append("Option") }
        if modifiers.contains(.shift) { parts.append("Shift") }
        if modifiers.contains(.command) { parts.append("Command") }
        
        parts.append(keyName(for: keyCode))
        
        return parts.joined(separator: " plus ")
    }

    private func keyName(for keyCode: UInt32) -> String {
        switch keyCode {
        case 49: return "Space"
        case 36: return "↩"
        case 48: return "⇥"
        case 51: return "⌫"
        case 53: return "⎋"
        case 0: return "A"
        case 11: return "B"
        case 8: return "C"
        case 2: return "D"
        case 14: return "E"
        case 3: return "F"
        case 5: return "G"
        case 4: return "H"
        case 34: return "I"
        case 38: return "J"
        case 40: return "K"
        case 37: return "L"
        case 46: return "M"
        case 45: return "N"
        case 31: return "O"
        case 35: return "P"
        case 12: return "Q"
        case 15: return "R"
        case 1: return "S"
        case 17: return "T"
        case 32: return "U"
        case 9: return "V"
        case 13: return "W"
        case 7: return "X"
        case 16: return "Y"
        case 6: return "Z"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"
        case 29: return "0"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default: return "?"
        }
    }
}


// MARK: - Key Cap View

struct KeyCapView: View {
    let symbol: String
    
    var body: some View {
        Text(symbol)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.2))
            .cornerRadius(4)
            .accessibilityHidden(true) // Parent view handles accessibility
    }
}

// MARK: - Hotkey Recorder Button

struct HotkeyRecorderButton: View {
    @Binding var isRecording: Bool
    @Binding var recordedKeyCode: UInt32?
    @Binding var recordedModifiers: NSEvent.ModifierFlags?
    
    let onRecorded: (UInt32, NSEvent.ModifierFlags) -> Void
    
    @State private var eventMonitor: Any?
    
    var body: some View {
        Button(action: toggleRecording) {
            HStack {
                Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                Text(isRecording ? "Press your shortcut..." : "Record New Hotkey")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(isRecording ? .red : .accentColor)
        .onDisappear {
            stopRecording()
        }
        .accessibilityLabel(isRecording ? "Recording hotkey. Press your desired shortcut." : "Record New Hotkey")
        .accessibilityHint(isRecording ? "Press any key combination to set as the new hotkey" : "Starts listening for a new keyboard shortcut")
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        recordedKeyCode = nil
        recordedModifiers = nil
        
        // Add local event monitor for key events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            // Capture the key
            let keyCode = UInt32(event.keyCode)
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            
            self.recordedKeyCode = keyCode
            self.recordedModifiers = modifiers
            
            // Stop recording and apply
            self.stopRecording()
            self.onRecorded(keyCode, modifiers)
            
            // Consume the event (don't pass it through)
            return nil
        }
        
        print("HotkeyRecorder: Started recording")
    }
    
    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        isRecording = false
        print("HotkeyRecorder: Stopped recording")
    }
}

// MARK: - Preview

#Preview {
    HotkeySettingsView()
        .frame(width: 450, height: 400)
}
