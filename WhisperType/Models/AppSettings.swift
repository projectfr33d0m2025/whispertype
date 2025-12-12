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
    private var _languageHint: String = ""
    
    // MARK: - v1.2 Processing Settings
    
    private var _processingMode: ProcessingMode = .formatted
    private var _fillerRemovalEnabled: Bool = true
    private var _llmPreference: LLMPreference = .localFirst
    private var _ollamaModel: String = "llama3.2:3b"
    private var _ollamaHost: String = "localhost"
    private var _ollamaPort: Int = 11434
    
    // MARK: - v1.2 Cloud Provider Settings
    
    private var _cloudProviderType: CloudProviderType = .openRouter
    private var _cloudModel: String = "openai/gpt-4o-mini"

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

    var languageHint: String {
        get { _languageHint }
        set {
            objectWillChange.send()
            _languageHint = newValue
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaultsKeys.languageHint)
            print("AppSettings: Language hint changed to \(newValue)")
        }
    }
    
    /// Get the language code to pass to Whisper (nil for auto-detect)
    var whisperLanguageCode: String? {
        let language = SupportedLanguage(fromStored: _languageHint)
        return language.whisperCode
    }
    
    // MARK: - v1.2 Processing Settings (Public)
    
    var processingMode: ProcessingMode {
        get { _processingMode }
        set {
            objectWillChange.send()
            _processingMode = newValue
            UserDefaults.standard.set(newValue.rawValue, forKey: Constants.UserDefaultsKeys.processingMode)
            print("AppSettings: Processing mode changed to \(newValue.rawValue)")
        }
    }
    
    var fillerRemovalEnabled: Bool {
        get { _fillerRemovalEnabled }
        set {
            objectWillChange.send()
            _fillerRemovalEnabled = newValue
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaultsKeys.fillerRemovalEnabled)
            print("AppSettings: Filler removal enabled changed to \(newValue)")
        }
    }
    
    var llmPreference: LLMPreference {
        get { _llmPreference }
        set {
            objectWillChange.send()
            _llmPreference = newValue
            UserDefaults.standard.set(newValue.rawValue, forKey: Constants.UserDefaultsKeys.llmPreference)
            print("AppSettings: LLM preference changed to \(newValue.rawValue)")
        }
    }
    
    var ollamaModel: String {
        get { _ollamaModel }
        set {
            objectWillChange.send()
            _ollamaModel = newValue
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaultsKeys.ollamaModel)
            print("AppSettings: Ollama model changed to \(newValue)")
        }
    }
    
    var ollamaHost: String {
        get { _ollamaHost }
        set {
            objectWillChange.send()
            _ollamaHost = newValue
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaultsKeys.ollamaHost)
            print("AppSettings: Ollama host changed to \(newValue)")
        }
    }
    
    var ollamaPort: Int {
        get { _ollamaPort }
        set {
            objectWillChange.send()
            _ollamaPort = newValue
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaultsKeys.ollamaPort)
            print("AppSettings: Ollama port changed to \(newValue)")
        }
    }
    
    /// Computed property for the full Ollama URL
    var ollamaURL: URL {
        URL(string: "http://\(_ollamaHost):\(_ollamaPort)")!
    }
    
    // MARK: - v1.2 Cloud Provider Settings (Public)
    
    var cloudProviderType: CloudProviderType {
        get { _cloudProviderType }
        set {
            objectWillChange.send()
            _cloudProviderType = newValue
            UserDefaults.standard.set(newValue.rawValue, forKey: Constants.UserDefaultsKeys.cloudProviderType)
            print("AppSettings: Cloud provider type changed to \(newValue.rawValue)")
        }
    }
    
    var cloudModel: String {
        get { _cloudModel }
        set {
            objectWillChange.send()
            _cloudModel = newValue
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaultsKeys.cloudModel)
            print("AppSettings: Cloud model changed to \(newValue)")
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
            self._hotkeyMode = HotkeyMode(rawValue: Constants.Defaults.hotkeyMode) ?? .toggle
        }

        self._languageHint = defaults.string(forKey: Constants.UserDefaultsKeys.languageHint)
            ?? Constants.Defaults.languageHint
        
        // Load v1.2 Processing Settings
        if let modeString = defaults.string(forKey: Constants.UserDefaultsKeys.processingMode),
           let mode = ProcessingMode(rawValue: modeString) {
            self._processingMode = mode
        } else {
            self._processingMode = Constants.Defaults.processingMode
        }
        
        self._fillerRemovalEnabled = defaults.object(forKey: Constants.UserDefaultsKeys.fillerRemovalEnabled) as? Bool
            ?? Constants.Defaults.fillerRemovalEnabled
        
        if let prefString = defaults.string(forKey: Constants.UserDefaultsKeys.llmPreference),
           let pref = LLMPreference(rawValue: prefString) {
            self._llmPreference = pref
        } else {
            self._llmPreference = Constants.Defaults.llmPreference
        }
        
        self._ollamaModel = defaults.string(forKey: Constants.UserDefaultsKeys.ollamaModel)
            ?? Constants.Defaults.ollamaModel
        
        self._ollamaHost = defaults.string(forKey: Constants.UserDefaultsKeys.ollamaHost)
            ?? Constants.Defaults.ollamaHost
        
        let savedPort = defaults.integer(forKey: Constants.UserDefaultsKeys.ollamaPort)
        self._ollamaPort = savedPort > 0 ? savedPort : Constants.Defaults.ollamaPort
        
        // Load v1.2 Cloud Provider Settings
        if let providerString = defaults.string(forKey: Constants.UserDefaultsKeys.cloudProviderType),
           let provider = CloudProviderType(rawValue: providerString) {
            self._cloudProviderType = provider
        } else {
            self._cloudProviderType = Constants.Defaults.cloudProviderType
        }
        
        self._cloudModel = defaults.string(forKey: Constants.UserDefaultsKeys.cloudModel)
            ?? Constants.Defaults.cloudModel

        print("AppSettings: Initialized with active model: \(_activeModelId), processing mode: \(_processingMode.rawValue)")
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
        languageHint = Constants.Defaults.languageHint
        
        // v1.2 Processing Settings
        processingMode = Constants.Defaults.processingMode
        fillerRemovalEnabled = Constants.Defaults.fillerRemovalEnabled
        llmPreference = Constants.Defaults.llmPreference
        ollamaModel = Constants.Defaults.ollamaModel
        ollamaHost = Constants.Defaults.ollamaHost
        ollamaPort = Constants.Defaults.ollamaPort
        cloudProviderType = Constants.Defaults.cloudProviderType
        cloudModel = Constants.Defaults.cloudModel

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
