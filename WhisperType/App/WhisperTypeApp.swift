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
        
        // Settings Window (placeholder for Phase 8)
        Settings {
            SettingsPlaceholderView()
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

// MARK: - Settings Placeholder (Phase 8)

struct SettingsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gear")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Settings")
                .font(.title)
            
            Text("Settings will be implemented in Phase 8")
                .foregroundColor(.secondary)
            
            Divider()
                .padding(.vertical)
            
            // Quick links to test functionality
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Actions:")
                    .font(.headline)
                
                Button("Open Models Folder") {
                    let modelsPath = ModelManager.shared.modelsDirectory
                    NSWorkspace.shared.open(modelsPath)
                }
                
                Button("Check Permissions") {
                    let permissions = Permissions.shared
                    print("Microphone: \(permissions.microphonePermission)")
                    print("Accessibility: \(permissions.accessibilityPermission)")
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
        }
        .padding(40)
        .frame(width: 450, height: 350)
    }
}
