//
//  WhisperTypeApp.swift
//  WhisperType
//
//  Main application entry point.
//

import SwiftUI

@main
struct WhisperTypeApp: App {

    // Use NSApplicationDelegateAdaptor to integrate AppDelegate with SwiftUI lifecycle
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Use ObservedObject for singletons (they're already created elsewhere)
    @ObservedObject private var coordinator = AppCoordinator.shared
    @ObservedObject private var modelManager = ModelManager.shared

    var body: some Scene {
        // Menu Bar Extra - Primary UI for the app
        MenuBarExtra {
            MenuBarView(coordinator: coordinator)
        } label: {
            MenuBarIcon(coordinator: coordinator)
        }
        .menuBarExtraStyle(.window)
        
        // Settings Window
        Settings {
            SettingsContainerView()
        }
    }
}

// MARK: - Menu Bar Icon View

struct MenuBarIcon: View {
    @ObservedObject var coordinator: AppCoordinator
    
    var body: some View {
        Image(systemName: iconName)
            .symbolRenderingMode(.hierarchical)
    }
    
    private var iconName: String {
        if coordinator.isProcessing {
            return "ellipsis.circle"
        } else if coordinator.isRecording {
            return "mic.fill"
        } else {
            return "waveform"
        }
    }
}
