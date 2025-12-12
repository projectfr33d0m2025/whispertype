//
//  ProcessingSettingsView.swift
//  WhisperType
//
//  Settings tab for configuring text processing options.
//  Part of the v1.2 Processing Modes feature.
//

import SwiftUI

struct ProcessingSettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var llmStatus: LLMEngineStatus = .unavailable(reason: "Checking...")
    
    var body: some View {
        Form {
            // MARK: - Processing Mode Selection
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Processing Mode")
                        .font(.headline)
                    
                    Text("Choose how WhisperType enhances your transcriptions.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        ForEach(ProcessingMode.allCases) { mode in
                            ProcessingModeCard(
                                mode: mode,
                                isSelected: settings.processingMode == mode,
                                llmAvailable: llmStatus.isAvailable
                            ) {
                                settings.processingMode = mode
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            // MARK: - Filler Removal Toggle
            Section {
                Toggle(isOn: $settings.fillerRemovalEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remove Filler Words")
                            .font(.body)
                        Text("Removes um, uh, like, you know, and other hesitation sounds")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .disabled(settings.processingMode == .raw)
            }
            
            // MARK: - AI Enhancement Engine
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("AI Enhancement Engine")
                            .font(.headline)
                        Spacer()
                        LLMStatusBadge(status: llmStatus)
                    }
                    
                    Text("AI features will be available in a future update.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Placeholder for Phase 2 configuration
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Local AI (Ollama)", systemImage: "lock.shield")
                                .foregroundColor(.secondary)
                            Text("Run AI models locally for complete privacy.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Divider()
                            
                            Label("Cloud AI (OpenAI)", systemImage: "cloud")
                                .foregroundColor(.secondary)
                            Text("Faster processing with cloud-based models.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .opacity(0.6)
                }
            }
            
            // MARK: - Navigation Placeholders
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    NavigationPlaceholder(
                        title: "Custom Vocabulary",
                        subtitle: "Add names, terms, and jargon",
                        icon: "textformat.abc"
                    )
                    
                    NavigationPlaceholder(
                        title: "App Rules",
                        subtitle: "Set different modes per app",
                        icon: "app.badge"
                    )
                }
            } header: {
                Text("Advanced")
            }
        }
        .formStyle(.grouped)
        .task {
            await updateLLMStatus()
        }
    }
    
    private func updateLLMStatus() async {
        llmStatus = await PostProcessor.shared.llmStatus
    }
}

// MARK: - Processing Mode Card

struct ProcessingModeCard: View {
    let mode: ProcessingMode
    let isSelected: Bool
    let llmAvailable: Bool
    let onSelect: () -> Void
    
    private var isDisabled: Bool {
        mode.requiresLLM && !llmAvailable
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.title2)
                
                // Mode icon
                Image(systemName: mode.icon)
                    .foregroundColor(isDisabled ? .secondary : .primary)
                    .font(.title3)
                    .frame(width: 24)
                
                // Mode info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(mode.displayName)
                            .font(.body)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .foregroundColor(isDisabled ? .secondary : .primary)
                        
                        if let badge = mode.badge {
                            BadgeView(text: badge, isWarning: mode.requiresLLM && !llmAvailable)
                        }
                    }
                    
                    Text(mode.shortDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

// MARK: - Badge View

struct BadgeView: View {
    let text: String
    let isWarning: Bool
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(isWarning ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
            )
            .foregroundColor(isWarning ? .orange : .blue)
    }
}

// MARK: - LLM Status Badge

struct LLMStatusBadge: View {
    let status: LLMEngineStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.1))
        )
    }
    
    private var statusColor: Color {
        switch status {
        case .available:
            return .green
        case .connecting, .processing:
            return .yellow
        case .unavailable:
            return .red
        }
    }
    
    private var statusText: String {
        switch status {
        case .available(let provider):
            return provider
        case .unavailable:
            return "Not Configured"
        case .processing:
            return "Processing"
        case .connecting:
            return "Connecting"
        }
    }
}

// MARK: - Navigation Placeholder

struct NavigationPlaceholder: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.secondary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
            }
            
            Spacer()
            
            Text("Coming Soon")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(.vertical, 4)
        .opacity(0.6)
    }
}

// MARK: - Preview

#Preview {
    ProcessingSettingsView()
        .frame(width: 500, height: 700)
}
