//
//  AppSettings.swift
//  WhisperType
//
//  Observable app settings persisted to UserDefaults.
//

import Foundation
import SwiftUI
import AppKit
import Combine

class AppSettings: ObservableObject {

    // MARK: - Singleton

    static let shared = AppSettings()

    // MARK: - Settings Properties

    @Published var activeModelId: String {
        didSet {
            UserDefaults.standard.set(activeModelId, forKey: Constants.UserDefaultsKeys.activeModelId)
            print("AppSettings: Active model changed to \(activeModelId)")
        }
    }

    @Published var hotkeyKeyCode: UInt32 {
        didSet {
            UserDefaults.standard.set(hotkeyKeyCode, forKey: Constants.UserDefaultsKeys.hotkeyKeyCode)
            print("AppSettings: Hotkey key code changed to \(hotkeyKeyCode)")
        }
    }

    @Published var hotkeyModifierFlags: NSEvent.ModifierFlags {
        didSet {
            UserDefaults.standard.set(hotkeyModifierFlags.rawValue, forKey: Constants.UserDefaultsKeys.hotkeyModifierFlags)
            print("AppSettings: Hotkey modifier flags changed")
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Constants.UserDefaultsKeys.launchAtLogin)
            print("AppSettings: Launch at login changed to \(launchAtLogin)")
            // TODO: Update launch at login preference using SMAppService
        }
    }

    @Published var selectedMicrophoneId: String? {
        didSet {
            UserDefaults.standard.set(selectedMicrophoneId, forKey: Constants.UserDefaultsKeys.selectedMicrophoneId)
            print("AppSettings: Selected microphone changed to \(selectedMicrophoneId ?? "default")")
        }
    }

    @Published var keepAudioRecordings: Bool {
        didSet {
            UserDefaults.standard.set(keepAudioRecordings, forKey: Constants.UserDefaultsKeys.keepAudioRecordings)
            print("AppSettings: Keep audio recordings changed to \(keepAudioRecordings)")
        }
    }

    @Published var audioRetentionDays: Int {
        didSet {
            UserDefaults.standard.set(audioRetentionDays, forKey: Constants.UserDefaultsKeys.audioRetentionDays)
            print("AppSettings: Audio retention days changed to \(audioRetentionDays)")
        }
    }

    @Published var playAudioFeedback: Bool {
        didSet {
            UserDefaults.standard.set(playAudioFeedback, forKey: Constants.UserDefaultsKeys.playAudioFeedback)
            print("AppSettings: Play audio feedback changed to \(playAudioFeedback)")
        }
    }

    @Published var hotkeyMode: HotkeyMode {
        didSet {
            UserDefaults.standard.set(hotkeyMode.rawValue, forKey: Constants.UserDefaultsKeys.hotkeyMode)
            print("AppSettings: Hotkey mode changed to \(hotkeyMode.rawValue)")
        }
    }

    // MARK: - Initialization

    private init() {
        // Load from UserDefaults or use defaults
        let defaults = UserDefaults.standard

        self.activeModelId = defaults.string(forKey: Constants.UserDefaultsKeys.activeModelId)
            ?? Constants.Defaults.defaultModelId

        self.hotkeyKeyCode = UInt32(defaults.integer(forKey: Constants.UserDefaultsKeys.hotkeyKeyCode))
        if self.hotkeyKeyCode == 0 {
            self.hotkeyKeyCode = Constants.Defaults.hotkeyKeyCode
        }

        let modifierRawValue = defaults.integer(forKey: Constants.UserDefaultsKeys.hotkeyModifierFlags)
        if modifierRawValue == 0 {
            self.hotkeyModifierFlags = Constants.Defaults.hotkeyModifierFlags
        } else {
            self.hotkeyModifierFlags = NSEvent.ModifierFlags(rawValue: UInt(modifierRawValue))
        }

        self.launchAtLogin = defaults.bool(forKey: Constants.UserDefaultsKeys.launchAtLogin)

        self.selectedMicrophoneId = defaults.string(forKey: Constants.UserDefaultsKeys.selectedMicrophoneId)

        self.keepAudioRecordings = defaults.object(forKey: Constants.UserDefaultsKeys.keepAudioRecordings) as? Bool
            ?? Constants.Defaults.keepAudioRecordings

        self.audioRetentionDays = defaults.integer(forKey: Constants.UserDefaultsKeys.audioRetentionDays)
        if self.audioRetentionDays == 0 {
            self.audioRetentionDays = Constants.Defaults.audioRetentionDays
        }

        self.playAudioFeedback = defaults.object(forKey: Constants.UserDefaultsKeys.playAudioFeedback) as? Bool
            ?? Constants.Defaults.playAudioFeedback

        if let modeString = defaults.string(forKey: Constants.UserDefaultsKeys.hotkeyMode),
           let mode = HotkeyMode(rawValue: modeString) {
            self.hotkeyMode = mode
        } else {
            self.hotkeyMode = .hold
        }

        print("AppSettings: Initialized with active model: \(activeModelId)")
    }

    // MARK: - Reset

    func resetToDefaults() {
        activeModelId = Constants.Defaults.defaultModelId
        hotkeyKeyCode = Constants.Defaults.hotkeyKeyCode
        hotkeyModifierFlags = Constants.Defaults.hotkeyModifierFlags
        launchAtLogin = false
        selectedMicrophoneId = nil
        keepAudioRecordings = Constants.Defaults.keepAudioRecordings
        audioRetentionDays = Constants.Defaults.audioRetentionDays
        playAudioFeedback = Constants.Defaults.playAudioFeedback
        hotkeyMode = .hold

        print("AppSettings: Reset to defaults")
    }
}

// MARK: - Hotkey Mode

enum HotkeyMode: String, CaseIterable {
    case hold = "hold"     // Press and hold to record, release to stop
    case toggle = "toggle" // Press once to start, press again to stop

    var displayName: String {
        switch self {
        case .hold:
            return "Hold to Record"
        case .toggle:
            return "Toggle Recording"
        }
    }

    var description: String {
        switch self {
        case .hold:
            return "Press and hold the hotkey to record. Release to stop and transcribe."
        case .toggle:
            return "Press the hotkey once to start recording. Press again to stop and transcribe."
        }
    }
}
