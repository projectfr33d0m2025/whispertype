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
    @ObservedObject var llmEngine = LLMEngine.shared
    @ObservedObject var appAwareManager = AppAwareManager.shared
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
            
            // Audio Level Indicator (visible when recording)
            if coordinator.isRecording {
                AudioLevelIndicator(level: coordinator.audioLevel)
                    .padding(.horizontal, 4)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Model Section
            modelSection
            
            Divider()
                .padding(.vertical, 8)
            
            // Processing Mode & AI Engine Section
            processingSection
            
            Divider()
                .padding(.vertical, 8)
            
            // Actions Section
            actionsSection
        }
        .padding(12)
        .frame(width: 280)
        .animation(.easeInOut(duration: 0.2), value: coordinator.notification)
        .animation(.easeInOut(duration: 0.15), value: coordinator.isRecording)
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
        .accessibilityLabel("Start Recording")
        .accessibilityHint("Press to begin voice transcription")
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
        .accessibilityLabel("Stop Recording")
        .accessibilityHint("Press to stop recording and transcribe")
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch coordinator.state {
        case .idle:
            Image(systemName: "waveform")
                .foregroundColor(.secondary)
                .accessibilityLabel("Idle")
        case .loading:
            ProgressView()
                .scaleEffect(0.7)
                .accessibilityLabel("Loading")
        case .ready:
            if #available(macOS 14.0, *) {
                Image(systemName: "waveform")
                    .foregroundColor(.accentColor)
                    .symbolEffect(.pulse, options: .repeating.speed(0.5), value: false)
                    .accessibilityLabel("Ready")
            } else {
                Image(systemName: "waveform")
                    .foregroundColor(.accentColor)
                    .accessibilityLabel("Ready")
            }
        case .recording:
            if #available(macOS 14.0, *) {
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
                    .symbolEffect(.pulse, options: .repeating, value: coordinator.isRecording)
                    .accessibilityLabel("Recording")
            } else {
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
                    .accessibilityLabel("Recording")
            }
        case .processing:
            ProgressView()
                .scaleEffect(0.7)
                .accessibilityLabel("Processing")
        case .error:
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
                .accessibilityLabel("Error")
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Active model: \(activeModel.displayName). \(activeModel.shortDescription). Speed rating \(activeModel.speedRating) out of 5.")
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Model \(selectedModel.displayName) is \(coordinator.state == .loading(message: "") ? "loading" : "not loaded")")
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
                .accessibilityLabel("Select a model")
                .accessibilityHint("Opens settings to download and select a transcription model")
            }
            .padding(8)
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("No model selected. Select a model to begin.")
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
    
    // MARK: - Processing Section
    
    private var processingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PROCESSING")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            // Processing Mode Row
            processingModeRow
            
            // AI Engine Row
            aiEngineRow
        }
    }
    
    private var processingModeRow: some View {
        HStack {
            Image(systemName: effectiveProcessingMode.icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(effectiveProcessingMode.displayName)
                        .font(.system(.body, design: .default))
                    
                    if appAwareManager.isEnabled && !appAwareManager.currentApp.isUnknown {
                        Text("(\(appAwareManager.currentApp.name))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if appAwareManager.isEnabled {
                    Text("App-aware")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Mode submenu
            Menu {
                // App-aware toggle
                Toggle(isOn: $appAwareManager.isEnabled) {
                    Label("Use App-Aware Mode", systemImage: "app.badge.checkmark")
                }
                
                Divider()
                
                // Mode selection
                ForEach(ProcessingMode.allCases) { mode in
                    Button(action: {
                        settings.processingMode = mode
                    }) {
                        HStack {
                            if settings.processingMode == mode {
                                Image(systemName: "checkmark")
                            }
                            Label(mode.displayName, systemImage: mode.icon)
                            if mode.requiresLLM {
                                Text("(AI)")
                            }
                        }
                    }
                    .disabled(mode.requiresLLM && !llmEngine.currentStatus.isAvailable)
                }
            } label: {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 20)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    /// Get the effective processing mode (considering app-aware settings)
    private var effectiveProcessingMode: ProcessingMode {
        if appAwareManager.isEnabled && !appAwareManager.currentApp.isUnknown {
            return appAwareManager.getModeForApp(appAwareManager.currentApp.bundleIdentifier)
        }
        return settings.processingMode
    }
    
    private var aiEngineRow: some View {
        HStack {
            Image(systemName: aiEngineIcon)
                .foregroundColor(aiEngineStatusColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(aiEngineTitle)
                    .font(.system(.body, design: .default))
                
                Text(aiEngineSubtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status indicator dot
            Circle()
                .fill(aiEngineStatusColor)
                .frame(width: 8, height: 8)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var aiEngineIcon: String {
        switch settings.llmPreference {
        case .disabled:
            return "xmark.circle"
        case .localOnly, .localFirst:
            return "lock.shield"
        case .cloudFirst, .cloudOnly:
            return "cloud"
        }
    }
    
    private var aiEngineTitle: String {
        switch llmEngine.currentStatus {
        case .available(let provider):
            return provider
        case .unavailable:
            return settings.llmPreference == .disabled ? "Disabled" : "Not Available"
        case .connecting:
            return "Connecting..."
        case .processing:
            return "Processing..."
        }
    }
    
    private var aiEngineSubtitle: String {
        switch settings.llmPreference {
        case .disabled:
            return "AI enhancement off"
        case .localOnly:
            return "Local only (private)"
        case .localFirst:
            return "Local preferred"
        case .cloudFirst:
            return "Cloud preferred"
        case .cloudOnly:
            return "Cloud only"
        }
    }
    
    private var aiEngineStatusColor: Color {
        switch llmEngine.currentStatus {
        case .available:
            return .green
        case .unavailable:
            return settings.llmPreference == .disabled ? .secondary : .red
        case .connecting:
            return .orange
        case .processing:
            return .yellow
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 4) {
            // Meeting Recording Button
            if !MeetingCoordinator.shared.isRecording {
                MenuBarButton(
                    title: "Start Meeting Recording",
                    icon: "record.circle",
                    shortcut: nil
                ) {
                    startMeetingRecording()
                }
            } else {
                MenuBarButton(
                    title: "Stop Meeting Recording",
                    icon: "stop.circle.fill",
                    shortcut: nil
                ) {
                    stopMeetingRecording()
                }
            }
            
            // Show Live Transcript (when recording)
            if MeetingCoordinator.shared.isRecording {
                MenuBarButton(
                    title: "Show Live Transcript",
                    icon: "text.bubble",
                    shortcut: nil
                ) {
                    showLiveTranscript()
                }
            }
            
            // Meeting History (Phase 6)
            MenuBarButton(
                title: "Meeting History...",
                icon: "clock.arrow.circlepath",
                shortcut: nil
            ) {
                openMeetingHistory()
            }
            
            Divider()
                .padding(.vertical, 4)
            
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
    
    private func startMeetingRecording() {
        dismiss()
        Task {
            do {
                try await MeetingCoordinator.shared.startRecording()
            } catch {
                print("Failed to start meeting recording: \(error)")
            }
        }
    }
    
    private func stopMeetingRecording() {
        dismiss()
        Task {
            do {
                _ = try await MeetingCoordinator.shared.stopRecording()
            } catch {
                print("Failed to stop meeting recording: \(error)")
            }
        }
    }
    
    private func showLiveTranscript() {
        print("MenuBarView: showLiveTranscript called")
        print("MenuBarView: MeetingCoordinator.isRecording = \(MeetingCoordinator.shared.isRecording)")
        
        dismiss()
        
        // Call toggleSubtitleWindow which is a public method
        DispatchQueue.main.async {
            MeetingCoordinator.shared.toggleSubtitleWindow()
        }
    }
    
    private func openSettings() {
        // Dismiss the menu bar popover first
        dismiss()
        
        // Use AppDelegate's method to show settings window (more reliable for menu bar apps)
        DispatchQueue.main.async {
            AppDelegate.shared?.showSettingsWindow()
        }
    }
    
    private func openMeetingHistory() {
        // Dismiss the menu bar popover first
        dismiss()
        
        // Use AppDelegate's method to show meeting history window
        DispatchQueue.main.async {
            AppDelegate.shared?.showMeetingHistoryWindow()
        }
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
        .accessibilityLabel(title)
        .accessibilityHint(shortcut != nil ? "Keyboard shortcut: \(shortcut!)" : "")
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
                
                // Level indicator with smooth animation
                RoundedRectangle(cornerRadius: 2)
                    .fill(levelColor)
                    .frame(width: geometry.size.width * CGFloat(min(max(level, 0), 1)))
                    .animation(.easeOut(duration: 0.05), value: level)
            }
        }
        .frame(height: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Audio level")
        .accessibilityValue("\(Int(level * 100)) percent")
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
