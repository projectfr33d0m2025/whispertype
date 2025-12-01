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

    // MARK: - Properties

    // Managers (will be initialized in later phases)
    // var modelManager: ModelManager?
    // var hotkeyManager: HotkeyManager?
    // var audioRecorder: AudioRecorder?
    // var whisperWrapper: WhisperWrapper?
    // var textInjector: TextInjector?
    // var menuBarController: MenuBarController?

    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var lastError: String?

    // MARK: - Initialization

    init() {
        print("AppCoordinator: Initializing...")
    }

    // MARK: - Lifecycle

    func start() {
        print("AppCoordinator: Starting app components...")

        // TODO: Initialize managers in later phases
        // Phase 2: ModelManager
        // Phase 3: AudioRecorder
        // Phase 4: WhisperWrapper
        // Phase 5: TextInjector
        // Phase 6: HotkeyManager
        // Phase 7: MenuBarController

        setupNotifications()
    }

    func cleanup() {
        print("AppCoordinator: Cleaning up...")

        // TODO: Cleanup managers
        // Stop recording if active
        // Unregister hotkeys
        // Free whisper context
        // Save settings
    }

    // MARK: - Notifications

    private func setupNotifications() {
        // Listen for model changes, permission updates, etc.
        // Will be expanded in later phases
    }

    // MARK: - Main Workflow (Placeholder)

    func startRecording() {
        guard !isRecording && !isProcessing else {
            print("AppCoordinator: Already recording or processing")
            return
        }

        print("AppCoordinator: Starting recording...")
        isRecording = true

        // TODO: Phase 3 - Start audio recording
    }

    func stopRecording() {
        guard isRecording else {
            print("AppCoordinator: Not currently recording")
            return
        }

        print("AppCoordinator: Stopping recording...")
        isRecording = false
        isProcessing = true

        // TODO: Phase 3 - Stop audio recording
        // TODO: Phase 4 - Transcribe audio
        // TODO: Phase 5 - Inject text

        // Placeholder - mark processing complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.isProcessing = false
        }
    }

    // MARK: - Error Handling

    func handleError(_ error: Error, context: String) {
        print("AppCoordinator: Error in \(context): \(error.localizedDescription)")
        lastError = "\(context): \(error.localizedDescription)"

        // TODO: Show error to user (menu bar notification, alert, etc.)
    }
}
