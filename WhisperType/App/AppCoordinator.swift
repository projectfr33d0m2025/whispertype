//
//  AppCoordinator.swift
//  WhisperType
//
//  Coordinates app components and manages the main workflow.
//

import Foundation
import SwiftUI

@MainActor
class AppCoordinator: ObservableObject {

    // MARK: - Singleton
    
    static let shared = AppCoordinator()

    // MARK: - Properties

    // Managers
    // var modelManager: ModelManager?
    var hotkeyManager: HotkeyManager?
    // var audioRecorder: AudioRecorder?
    // var whisperWrapper: WhisperWrapper?
    // var textInjector: TextInjector?
    // var menuBarController: MenuBarController?

    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var lastError: String?

    // MARK: - Initialization

    private init() {
        print("AppCoordinator: Initializing...")
    }

    // MARK: - Lifecycle

    func start() {
        print("AppCoordinator: Starting app components...")

        // Phase 6: Initialize HotkeyManager
        setupHotkeyManager()
        
        // TODO: Initialize other managers in later phases
        // Phase 2: ModelManager
        // Phase 3: AudioRecorder
        // Phase 4: WhisperWrapper
        // Phase 5: TextInjector
        // Phase 7: MenuBarController

        setupNotifications()
        
        print("AppCoordinator: All components started")
    }

    func cleanup() {
        print("AppCoordinator: Cleaning up...")

        // Unregister hotkeys
        hotkeyManager?.unregisterHotkey()
        
        // TODO: Cleanup other managers
        // Stop recording if active
        // Free whisper context
        // Save settings
    }
    
    // MARK: - Hotkey Setup
    
    private func setupHotkeyManager() {
        print("AppCoordinator: Setting up HotkeyManager...")
        
        hotkeyManager = HotkeyManager.shared
        
        // Set callback for when recording is toggled via hotkey
        hotkeyManager?.onRecordingToggle = { [weak self] shouldRecord in
            Task { @MainActor in
                if shouldRecord {
                    self?.startRecording()
                } else {
                    self?.stopRecording()
                }
            }
        }
        
        // Register the hotkey
        hotkeyManager?.registerHotkey()
        hotkeyManager?.printStatus()
    }

    // MARK: - Notifications

    private func setupNotifications() {
        // Listen for model changes, permission updates, etc.
        // Will be expanded in later phases
    }

    // MARK: - Main Workflow

    func startRecording() {
        guard !isRecording && !isProcessing else {
            print("AppCoordinator: Already recording or processing")
            return
        }

        print("AppCoordinator: 🎤 Starting recording...")
        isRecording = true

        // TODO: Phase 3 - Start audio recording
        // audioRecorder?.startRecording()
    }

    func stopRecording() {
        guard isRecording else {
            print("AppCoordinator: Not currently recording")
            return
        }

        print("AppCoordinator: ⏹️ Stopping recording...")
        isRecording = false
        isProcessing = true

        // TODO: Phase 3 - Stop audio recording
        // let audioData = audioRecorder?.stopRecording()
        
        // TODO: Phase 4 - Transcribe audio
        // let text = whisperWrapper?.transcribe(audioData)
        
        // TODO: Phase 5 - Inject text
        // textInjector?.injectText(text)

        // Placeholder - mark processing complete after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.isProcessing = false
            print("AppCoordinator: ✅ Processing complete (placeholder)")
        }
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    // MARK: - Error Handling

    func handleError(_ error: Error, context: String) {
        print("AppCoordinator: Error in \(context): \(error.localizedDescription)")
        lastError = "\(context): \(error.localizedDescription)"

        // TODO: Show error to user (menu bar notification, alert, etc.)
    }
}
