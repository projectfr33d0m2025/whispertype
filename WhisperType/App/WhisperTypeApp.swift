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
        
        // Settings Window - Use Window instead of Settings for better control
        Window("WhisperType Settings", id: "settings") {
            SettingsContainerView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

// MARK: - Menu Bar Icon View

struct MenuBarIcon: View {
    @ObservedObject var coordinator: AppCoordinator
    
    var body: some View {
        Image(systemName: iconName)
            .symbolRenderingMode(.hierarchical)
            .foregroundColor(iconColor)
    }
    
    private var iconName: String {
        switch coordinator.state {
        case .idle:
            return "waveform"
        case .loading:
            return "ellipsis.circle"
        case .ready:
            return "waveform"
        case .recording:
            return "mic.fill"
        case .processing:
            return "ellipsis.circle"
        case .error:
            return "exclamationmark.triangle"
        }
    }
    
    private var iconColor: Color {
        switch coordinator.state {
        case .idle:
            return .secondary
        case .loading:
            return .orange
        case .ready:
            return .primary
        case .recording:
            return .red
        case .processing:
            return .orange
        case .error:
            return .red
        }
    }
}
