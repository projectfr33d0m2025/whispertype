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
    @ObservedObject var llmEngine = LLMEngine.shared
    @ObservedObject var ollamaModelManager = OllamaModelManager.shared
    
    @State private var ollamaStatus: LLMProviderStatus = .connecting
    @State private var cloudStatus: LLMProviderStatus = .connecting
    @State private var showAPIKeySheet = false
    @State private var isRefreshingOllama = false
    
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
                                llmAvailable: llmEngine.currentStatus.isAvailable
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
                        LLMStatusBadge(status: llmEngine.currentStatus)
                    }
                    
                    // Provider Preference
                    Picker("Provider Preference", selection: $settings.llmPreference) {
                        ForEach(LLMPreference.allCases) { pref in
                            Label(pref.displayName, systemImage: pref.icon)
                                .tag(pref)
                        }
                    }
                    .onChange(of: settings.llmPreference) { _ in
                        llmEngine.reconfigure()
                    }
                    
                    Text(settings.llmPreference.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // MARK: - Local AI (Ollama) Configuration
            if settings.llmPreference.usesLocal {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Local AI (Ollama)", systemImage: "lock.shield")
                                .font(.headline)
                            Spacer()
                            ProviderStatusIndicator(status: ollamaStatus)
                        }
                        
                        // Connection status
                        if case .unavailable(let reason) = ollamaStatus {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(reason)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(6)
                        }
                        
                        // Model picker
                        if ollamaModelManager.hasModels {
                            Picker("Model", selection: $settings.ollamaModel) {
                                ForEach(ollamaModelManager.installedModels) { model in
                                    Text(model.name).tag(model.name)
                                }
                            }
                            .onChange(of: settings.ollamaModel) { _ in
                                llmEngine.reconfigure()
                            }
                        } else {
                            HStack {
                                Text("Model:")
                                TextField("Model name", text: $settings.ollamaModel)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 200)
                            }
                        }
                        
                        // Refresh button
                        HStack {
                            Button(action: refreshOllamaStatus) {
                                Label(
                                    isRefreshingOllama ? "Checking..." : "Refresh Status",
                                    systemImage: "arrow.clockwise"
                                )
                            }
                            .disabled(isRefreshingOllama)
                            
                            Spacer()
                            
                            Link("Install Ollama", destination: URL(string: "https://ollama.ai")!)
                                .font(.caption)
                        }
                    }
                }
            }
            
            // MARK: - Cloud AI Configuration
            if settings.llmPreference.usesCloud {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Cloud AI", systemImage: "cloud")
                                .font(.headline)
                            Spacer()
                            ProviderStatusIndicator(status: cloudStatus)
                        }
                        
                        // Provider selection
                        Picker("Provider", selection: $settings.cloudProviderType) {
                            ForEach(CloudProviderType.allCases) { provider in
                                Text(provider.displayName).tag(provider)
                            }
                        }
                        .onChange(of: settings.cloudProviderType) { newValue in
                            // Update model to default for selected provider
                            settings.cloudModel = newValue.defaultModel
                            llmEngine.reconfigure()
                            Task { await updateCloudStatus() }
                        }
                        
                        // Model input
                        HStack {
                            Text("Model:")
                            TextField("Model name", text: $settings.cloudModel)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 200)
                        }
                        
                        // API Key configuration
                        HStack {
                            if hasCloudAPIKey {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("API Key: \(maskedAPIKey)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("API key not configured")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            Spacer()
                            
                            Button(hasCloudAPIKey ? "Change API Key" : "Add API Key") {
                                showAPIKeySheet = true
                            }
                        }
                        
                        // Privacy notice
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                            Text("Cloud AI sends your transcribed text (not audio) to external servers for processing.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            }
            
            // MARK: - Advanced Navigation
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    // Vocabulary - links to the Vocabulary tab
                    VocabularyNavigationLink()
                    
                    // App Rules - links to the App Rules tab
                    AppRulesNavigationLink()
                }
            } header: {
                Text("Advanced")
            }
        }
        .formStyle(.grouped)
        .task {
            await loadInitialStatus()
        }
        .sheet(isPresented: $showAPIKeySheet) {
            APIKeyInputSheet(
                providerType: settings.cloudProviderType,
                onSave: { key in
                    saveAPIKey(key)
                }
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadInitialStatus() async {
        ollamaStatus = await llmEngine.getOllamaStatus()
        cloudStatus = await llmEngine.getCloudStatus()
        await ollamaModelManager.detectInstalledModels()
    }
    
    private func refreshOllamaStatus() {
        isRefreshingOllama = true
        Task {
            ollamaStatus = await llmEngine.refreshOllamaStatus()
            await ollamaModelManager.detectInstalledModels()
            llmEngine.reconfigure()
            await MainActor.run {
                isRefreshingOllama = false
            }
        }
    }
    
    private func updateCloudStatus() async {
        cloudStatus = await llmEngine.getCloudStatus()
    }
    
    private var hasCloudAPIKey: Bool {
        switch settings.cloudProviderType {
        case .openAI:
            return KeychainManager.shared.hasOpenAIKey
        case .openRouter:
            return KeychainManager.shared.hasOpenRouterKey
        }
    }
    
    private var maskedAPIKey: String {
        switch settings.cloudProviderType {
        case .openAI:
            return KeychainManager.shared.getMaskedAPIKey(for: CloudProviderType.openAI.keychainAccount) ?? "****"
        case .openRouter:
            return KeychainManager.shared.getMaskedAPIKey(for: CloudProviderType.openRouter.keychainAccount) ?? "****"
        }
    }
    
    private func saveAPIKey(_ key: String) {
        switch settings.cloudProviderType {
        case .openAI:
            KeychainManager.shared.saveOpenAIKey(key)
        case .openRouter:
            KeychainManager.shared.saveOpenRouterKey(key)
        }
        llmEngine.reconfigure()
        Task { await updateCloudStatus() }
    }
}


// MARK: - Provider Status Indicator

struct ProviderStatusIndicator: View {
    let status: LLMProviderStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(status.displayText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .available:
            return .green
        case .unavailable:
            return .red
        case .connecting:
            return .orange
        case .rateLimited:
            return .yellow
        }
    }
}

// MARK: - API Key Input Sheet

struct APIKeyInputSheet: View {
    let providerType: CloudProviderType
    let onSave: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var validationError: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: providerType.icon)
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)
                
                Text("\(providerType.displayName) API Key")
                    .font(.headline)
                
                Text(providerType.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // API Key input
            VStack(alignment: .leading, spacing: 8) {
                SecureField("Enter API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                
                if let error = validationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                // Help link
                if providerType == .openRouter {
                    Link("Get an OpenRouter API key →", destination: URL(string: "https://openrouter.ai/keys")!)
                        .font(.caption)
                } else {
                    Link("Get an OpenAI API key →", destination: URL(string: "https://platform.openai.com/api-keys")!)
                        .font(.caption)
                }
            }
            
            // Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Save") {
                    saveKey()
                }
                .keyboardShortcut(.return)
                .disabled(apiKey.isEmpty || isValidating)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
    
    private func saveKey() {
        // Basic validation
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedKey.isEmpty else {
            validationError = "API key cannot be empty"
            return
        }
        
        // Save the key
        onSave(trimmedKey)
        dismiss()
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

// MARK: - Vocabulary Navigation Link

struct VocabularyNavigationLink: View {
    @ObservedObject var vocabularyManager = VocabularyManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "textformat.abc")
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Custom Vocabulary")
                Text("Add names, terms, and jargon")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Entry count badge
            Text("\(vocabularyManager.entryCount)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.secondary.opacity(0.1)))
            
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            NotificationCenter.default.post(name: .switchToVocabularyTab, object: nil)
        }
    }
}

// MARK: - App Rules Navigation Link

struct AppRulesNavigationLink: View {
    @ObservedObject var appAwareManager = AppAwareManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "app.badge.checkmark")
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("App Rules")
                Text("Set different modes per app")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Custom rules count badge
            if appAwareManager.customRulesCount > 0 {
                Text("\(appAwareManager.customRulesCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.1)))
            }
            
            // Status indicator
            if appAwareManager.isEnabled {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
            }
            
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            NotificationCenter.default.post(name: .switchToAppRulesTab, object: nil)
        }
    }
}

// MARK: - Preview

#Preview {
    ProcessingSettingsView()
        .frame(width: 500, height: 800)
}
