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
    @ObservedObject var whisperWrapper = WhisperWrapper.shared
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Notification Banner (if present)
            if let notification = coordinator.notification {
                notificationBanner(notification)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
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
        .frame(width: 280)
        .animation(.easeInOut(duration: 0.2), value: coordinator.notification)
    }
    
    // MARK: - Notification Banner
    
    private func notificationBanner(_ notification: NotificationMessage) -> some View {
        HStack(spacing: 8) {
            Image(systemName: notification.type.iconName)
                .foregroundColor(notification.type.color)
            
            Text(notification.message)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            Button(action: { coordinator.dismissNotification() }) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(notification.type.color.opacity(0.15))
        .cornerRadius(8)
        .padding(.bottom, 8)
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        HStack(spacing: 12) {
            // Status Icon with animation
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
            
            // Recording toggle button (when ready)
            if case .ready = coordinator.state {
                recordButton
            } else if coordinator.isRecording {
                stopButton
            }
        }
    }
    
    private var recordButton: some View {
        Button(action: {
            Task {
                await coordinator.startRecording()
            }
        }) {
            Image(systemName: "mic.fill")
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
        }
        .buttonStyle(.plain)
        .help("Start Recording (⌥Space)")
    }
    
    private var stopButton: some View {
        Button(action: {
            Task {
                await coordinator.stopRecordingAndTranscribe()
            }
        }) {
            Image(systemName: "stop.fill")
                .font(.system(size: 16))
                .foregroundColor(.red)
        }
        .buttonStyle(.plain)
        .help("Stop Recording (⌥Space)")
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch coordinator.state {
        case .idle:
            Image(systemName: "waveform")
                .foregroundColor(.secondary)
        case .loading:
            Image(systemName: "ellipsis.circle")
                .foregroundColor(.orange)
                .symbolEffect(.pulse)
        case .ready:
            Image(systemName: "waveform")
                .foregroundColor(.accentColor)
        case .recording:
            Image(systemName: "mic.fill")
                .foregroundColor(.red)
                .symbolEffect(.pulse)
        case .processing:
            Image(systemName: "ellipsis.circle")
                .foregroundColor(.orange)
                .symbolEffect(.pulse)
        case .error:
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
        }
    }
    
    private var statusTitle: String {
        switch coordinator.state {
        case .idle:
            return "Idle"
        case .loading:
            return "Loading..."
        case .ready:
            return "Ready"
        case .recording:
            return "Recording..."
        case .processing:
            return "Processing..."
        case .error:
            return "Error"
        }
    }
    
    private var statusSubtitle: String {
        switch coordinator.state {
        case .idle:
            return "No model loaded"
        case .loading(let message):
            return message
        case .ready:
            let hotkeyText = hotkeyDescription
            return "Press \(hotkeyText) to start"
        case .recording:
            let duration = coordinator.recordingDuration
            let hotkeyText = hotkeyDescription
            return String(format: "%.1fs • Release \(hotkeyText) to stop", duration)
        case .processing:
            return "Transcribing audio..."
        case .error(let message):
            return message
        }
    }
    
    private var hotkeyDescription: String {
        let flags = settings.hotkeyModifierFlags
        var parts: [String] = []
        
        if flags.contains(.command) { parts.append("⌘") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.shift) { parts.append("⇧") }
        
        // Get key name from keycode (simplified)
        let keyName = keyNameForCode(settings.hotkeyKeyCode)
        parts.append(keyName)
        
        return parts.joined()
    }
    
    private func keyNameForCode(_ keyCode: UInt32) -> String {
        switch keyCode {
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 51: return "Delete"
        case 53: return "Escape"
        default:
            // For letter keys, convert to character
            if let scalar = UnicodeScalar(keyCode) {
                return String(Character(scalar)).uppercased()
            }
            return "Key\(keyCode)"
        }
    }
    
    // MARK: - Model Section
    
    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MODEL")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            modelCard
        }
    }
    
    @ViewBuilder
    private var modelCard: some View {
        if let activeModel = whisperWrapper.loadedModelType {
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.green)
                
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
        } else if let selectedModel = modelManager.activeModel {
            // Model selected but not loaded
            HStack {
                if case .loading = coordinator.state {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(selectedModel.displayName)
                        .font(.system(.body, design: .default))
                    
                    if case .loading = coordinator.state {
                        Text("Loading...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Not loaded")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
            }
            .padding(8)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        } else {
            // No model selected
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
                
                Text("No model selected")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Select") {
                    openSettings()
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
            .padding(8)
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
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
            // Settings Button
            MenuBarButton(
                title: "Settings...",
                icon: "gear",
                shortcut: "⌘,"
            ) {
                openSettings()
            }
            
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
    
    private func openSettings() {
        // Dismiss the menu bar popover first
        dismiss()
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

// MARK: - Audio Level Indicator

struct AudioLevelIndicator: View {
    let level: Float
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.2))
                
                // Level indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(levelColor)
                    .frame(width: geometry.size.width * CGFloat(level))
            }
        }
        .frame(height: 4)
    }
    
    private var levelColor: Color {
        if level > 0.8 {
            return .red
        } else if level > 0.5 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Preview

#Preview {
    MenuBarView(coordinator: AppCoordinator.shared)
        .frame(width: 280)
}
