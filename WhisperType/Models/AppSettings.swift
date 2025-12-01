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

    // MARK: - Private Backing Storage

    private var _activeModelId: String = ""
    private var _hotkeyKeyCode: UInt32 = 0
    private var _hotkeyModifierFlags: NSEvent.ModifierFlags = []
    private var _launchAtLogin: Bool = false
    private var _selectedMicrophoneId: String? = nil
    private var _keepAudioRecordings: Bool = false
    private var _audioRetentionDays: Int = 0
    private var _playAudioFeedback: Bool = false
    private var _hotkeyMode: HotkeyMode = .hold

    // MARK: - Public Computed Properties

    var activeModelId: String {
        get { _activeModelId }
        set {
            objectWillChange.send()
            _activeModelId = newValue
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaultsKeys.activeModelId)
            print("AppSettings: Active model changed to \(newValue)")
        }
    }

    var hotkeyKeyCode: UInt32 {
        get { _hotkeyKeyCode }
        set {
            objectWillChange.send()
            _hotkeyKeyCode = newValue
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaultsKeys.hotkeyKeyCode)
            print("AppSettings: Hotkey key code changed to \(newValue)")
        }
    }

    var hotkeyModifierFlags: NSEvent.ModifierFlags {
        get { _hotkeyModifierFlags }
        set {
            objectWillChange.send()
            _hotkeyModifierFlags = newValue
            UserDefaults.standard.set(newValue.rawValue, forKey: Constants.UserDefaultsKeys.hotkeyModifierFlags)
            print("AppSettings: Hotkey modifier flags changed")
        }
    }

    var launchAtLogin: Bool {
        get { _launchAtLogin }
        set {
            objectWillChange.send()
            _launchAtLogin = newValue
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaultsKeys.launchAtLogin)
            print("AppSettings: Launch at login changed to \(newValue)")
            // TODO: Update launch at login preference using SMAppService
        }
    }

    var selectedMicrophoneId: String? {
        get { _selectedMicrophoneId }
        set {
            objectWillChange.send()
            _selectedMicrophoneId = newValue
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaultsKeys.selectedMicrophoneId)
            print("AppSettings: Selected microphone changed to \(newValue ?? "default")")
        }
    }

    var keepAudioRecordings: Bool {
        get { _keepAudioRecordings }
        set {
            objectWillChange.send()
            _keepAudioRecordings = newValue
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaultsKeys.keepAudioRecordings)
            print("AppSettings: Keep audio recordings changed to \(newValue)")
        }
    }

    var audioRetentionDays: Int {
        get { _audioRetentionDays }
        set {
            objectWillChange.send()
            _audioRetentionDays = newValue
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaultsKeys.audioRetentionDays)
            print("AppSettings: Audio retention days changed to \(newValue)")
        }
    }

    var playAudioFeedback: Bool {
        get { _playAudioFeedback }
        set {
            objectWillChange.send()
            _playAudioFeedback = newValue
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaultsKeys.playAudioFeedback)
            print("AppSettings: Play audio feedback changed to \(newValue)")
        }
    }

    var hotkeyMode: HotkeyMode {
        get { _hotkeyMode }
        set {
            objectWillChange.send()
            _hotkeyMode = newValue
            UserDefaults.standard.set(newValue.rawValue, forKey: Constants.UserDefaultsKeys.hotkeyMode)
            print("AppSettings: Hotkey mode changed to \(newValue.rawValue)")
        }
    }

    // MARK: - Initialization

    private init() {
        // Load from UserDefaults or use defaults
        let defaults = UserDefaults.standard

        self._activeModelId = defaults.string(forKey: Constants.UserDefaultsKeys.activeModelId)
            ?? Constants.Defaults.defaultModelId

        self._hotkeyKeyCode = UInt32(defaults.integer(forKey: Constants.UserDefaultsKeys.hotkeyKeyCode))
        if self._hotkeyKeyCode == 0 {
            self._hotkeyKeyCode = Constants.Defaults.hotkeyKeyCode
        }

        let modifierRawValue = defaults.integer(forKey: Constants.UserDefaultsKeys.hotkeyModifierFlags)
        if modifierRawValue == 0 {
            self._hotkeyModifierFlags = Constants.Defaults.hotkeyModifierFlags
        } else {
            self._hotkeyModifierFlags = NSEvent.ModifierFlags(rawValue: UInt(modifierRawValue))
        }

        self._launchAtLogin = defaults.bool(forKey: Constants.UserDefaultsKeys.launchAtLogin)

        self._selectedMicrophoneId = defaults.string(forKey: Constants.UserDefaultsKeys.selectedMicrophoneId)

        self._keepAudioRecordings = defaults.object(forKey: Constants.UserDefaultsKeys.keepAudioRecordings) as? Bool
            ?? Constants.Defaults.keepAudioRecordings

        self._audioRetentionDays = defaults.integer(forKey: Constants.UserDefaultsKeys.audioRetentionDays)
        if self._audioRetentionDays == 0 {
            self._audioRetentionDays = Constants.Defaults.audioRetentionDays
        }

        self._playAudioFeedback = defaults.object(forKey: Constants.UserDefaultsKeys.playAudioFeedback) as? Bool
            ?? Constants.Defaults.playAudioFeedback

        if let modeString = defaults.string(forKey: Constants.UserDefaultsKeys.hotkeyMode),
           let mode = HotkeyMode(rawValue: modeString) {
            self._hotkeyMode = mode
        } else {
            self._hotkeyMode = .hold
        }

        print("AppSettings: Initialized with active model: \(_activeModelId)")
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
