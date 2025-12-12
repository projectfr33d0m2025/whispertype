//
//  AppRulesSettingsView.swift
//  WhisperType
//
//  Settings view for managing app-aware processing rules.
//  Part of the v1.2 App-Aware Context feature.
//

import SwiftUI
import AppKit

struct AppRulesSettingsView: View {
    
    @ObservedObject var appAwareManager = AppAwareManager.shared
    @State private var showAddAppSheet = false
    @State private var selectedEntry: AppAwareManager.AppEntry?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with toggle
            headerSection
            
            Divider()
            
            if appAwareManager.isEnabled {
                // App list
                appListSection
            } else {
                // Disabled state
                disabledStateView
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .sheet(isPresented: $showAddAppSheet) {
            AddAppSheet { appInfo, mode in
                appAwareManager.setCustomRule(for: appInfo, mode: mode)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("App-Aware Processing")
                        .font(.headline)
                    Text("Automatically adjust processing mode based on the active application")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $appAwareManager.isEnabled)
                    .toggleStyle(.switch)
            }
            
            if appAwareManager.isEnabled {
                HStack {
                    Text("\(appAwareManager.customRules.count) custom rule(s)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: { showAddAppSheet = true }) {
                        Label("Add App", systemImage: "plus")
                    }
                    
                    if !appAwareManager.customRules.isEmpty {
                        Button(action: resetAllRules) {
                            Text("Reset All")
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
    }
    
    // MARK: - App List Section
    
    private var appListSection: some View {
        List {
            ForEach(appAwareManager.getAppEntriesByCategory(), id: \.category) { group in
                Section(header: categoryHeader(group.category)) {
                    ForEach(group.entries) { entry in
                        AppRuleRow(
                            entry: entry,
                            onModeChange: { newMode in
                                appAwareManager.setCustomRule(
                                    for: entry.bundleIdentifier,
                                    mode: newMode,
                                    displayName: entry.displayName
                                )
                            },
                            onReset: entry.isCustomized ? {
                                appAwareManager.removeCustomRule(for: entry.bundleIdentifier)
                            } : nil
                        )
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
    
    // MARK: - Category Header
    
    private func categoryHeader(_ category: AppCategory) -> some View {
        HStack {
            Image(systemName: category.icon)
            Text(category.displayName)
        }
    }
    
    // MARK: - Disabled State
    
    private var disabledStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "app.dashed")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("App-Aware Processing Disabled")
                .font(.headline)
            
            Text("Enable app-aware processing to automatically adjust\nthe processing mode based on the active application.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Enable App-Aware Processing") {
                appAwareManager.isEnabled = true
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Actions
    
    private func resetAllRules() {
        let alert = NSAlert()
        alert.messageText = "Reset All Custom Rules?"
        alert.informativeText = "This will remove all custom app rules and revert to default presets."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            appAwareManager.resetAllRules()
        }
    }
}

// MARK: - App Rule Row

struct AppRuleRow: View {
    let entry: AppAwareManager.AppEntry
    let onModeChange: (ProcessingMode) -> Void
    let onReset: (() -> Void)?
    
    @State private var selectedMode: ProcessingMode
    
    init(entry: AppAwareManager.AppEntry, onModeChange: @escaping (ProcessingMode) -> Void, onReset: (() -> Void)?) {
        self.entry = entry
        self.onModeChange = onModeChange
        self.onReset = onReset
        self._selectedMode = State(initialValue: entry.currentMode)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // App icon
            AppIconView(bundleIdentifier: entry.bundleIdentifier)
                .frame(width: 24, height: 24)
            
            // App name and info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.displayName)
                        .font(.body)
                    
                    if entry.isCustomized {
                        Text("Custom")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
                    }
                }
                
                if let defaultMode = entry.defaultMode, entry.isCustomized {
                    Text("Default: \(defaultMode.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Mode picker
            Picker("", selection: $selectedMode) {
                ForEach(ProcessingMode.allCases) { mode in
                    HStack {
                        Text(mode.displayName)
                        if mode.requiresLLM {
                            Text("AI")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 130)
            .onChange(of: selectedMode) { newMode in
                onModeChange(newMode)
            }
            
            // Reset button (for customized entries)
            if let onReset = onReset {
                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reset to default")
            } else {
                // Placeholder for alignment
                Color.clear
                    .frame(width: 20)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - App Icon View

struct AppIconView: View {
    let bundleIdentifier: String
    
    @State private var icon: NSImage?
    
    var body: some View {
        Group {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app")
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            loadIcon()
        }
    }
    
    private func loadIcon() {
        // Try to get the app URL from bundle identifier
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            icon = NSWorkspace.shared.icon(forFile: appURL.path)
        }
    }
}
