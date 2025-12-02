//
//  MenuBarView.swift
//  WhisperType
//
//  SwiftUI view for the menu bar popover/menu content.
//

import SwiftUI

struct MenuBarView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var modelManager = ModelManager.shared
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status Section
            statusSection
            
            Divider()
                .padding(.vertical, 8)
            
            // Model Section
            modelSection
            
            Divider()
                .padding(.vertical, 8)
            
            // Actions Section
            actionsSection
        }
        .padding(12)
        .frame(width: 260)
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        HStack(spacing: 12) {
            // Status Icon
            statusIcon
                .font(.system(size: 24))
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.headline)
                
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Recording toggle button
            if !coordinator.isProcessing {
                Button(action: {
                    coordinator.toggleRecording()
                }) {
                    Image(systemName: coordinator.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 16))
                        .foregroundColor(coordinator.isRecording ? .red : .accentColor)
                }
                .buttonStyle(.plain)
                .help(coordinator.isRecording ? "Stop Recording" : "Start Recording")
            }
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        if coordinator.isProcessing {
            // Processing state - orange ellipsis
            Image(systemName: "ellipsis.circle")
                .foregroundColor(.orange)
        } else if coordinator.isRecording {
            // Recording state - red mic
            Image(systemName: "mic.fill")
                .foregroundColor(.red)
        } else {
            // Idle state - accent waveform
            Image(systemName: "waveform")
                .foregroundColor(.accentColor)
        }
    }
    
    private var statusTitle: String {
        if coordinator.isProcessing {
            return "Processing..."
        } else if coordinator.isRecording {
            return "Recording..."
        } else {
            return "Ready"
        }
    }
    
    private var statusSubtitle: String {
        if coordinator.isProcessing {
            return "Transcribing audio"
        } else if coordinator.isRecording {
            return "Press ⌥Space to stop"
        } else {
            return "Press ⌥Space to start"
        }
    }
    
    // MARK: - Model Section
    
    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MODEL")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            if let activeModel = modelManager.activeModel {
                HStack {
                    Image(systemName: "cpu")
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(activeModel.displayName)
                            .font(.system(.body, design: .default))
                        
                        Text(activeModel.shortDescription)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Speed indicator
                    speedIndicator(for: activeModel)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    
                    Text("No model loaded")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private func speedIndicator(for model: WhisperModelType) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Rectangle()
                    .fill(index < model.speedRating ? Color.green : Color.secondary.opacity(0.3))
                    .frame(width: 3, height: 8 + CGFloat(index) * 2)
            }
        }
        .help("Speed: \(model.speedRating)/5")
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 4) {
            // Settings Button - Use openWindow to open the settings window
            Button(action: openSettings) {
                settingsButtonContent
            }
            .buttonStyle(.plain)
            
            // Quit Button
            MenuBarButton(
                title: "Quit WhisperType",
                icon: "power",
                shortcut: "⌘Q"
            ) {
                NSApplication.shared.terminate(nil)
            }
        }
    }
    
    private var settingsButtonContent: some View {
        HStack {
            Image(systemName: "gear")
                .frame(width: 20)
                .foregroundColor(.secondary)
            
            Text("Settings...")
            
            Spacer()
            
            Text("⌘,")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
    
    private func openSettings() {
        // Use SwiftUI's openWindow environment action
        openWindow(id: "settings")
    }
}

// MARK: - Menu Bar Button Component

struct MenuBarButton: View {
    let title: String
    let icon: String
    var shortcut: String? = nil
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                    .foregroundColor(.secondary)
                
                Text(title)
                
                Spacer()
                
                if let shortcut = shortcut {
                    Text(shortcut)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isHovered ? Color.secondary.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Preview

#Preview {
    MenuBarView(coordinator: AppCoordinator.shared)
        .frame(width: 260)
}
