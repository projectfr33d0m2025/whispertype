//
//  AddAppSheet.swift
//  WhisperType
//
//  Sheet for adding a new app rule.
//  Supports selecting from running apps or browsing Applications folder.
//

import SwiftUI
import AppKit

struct AddAppSheet: View {
    
    let onAdd: (AppInfo, ProcessingMode) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab = 0
    @State private var selectedApp: AppInfo?
    @State private var selectedMode: ProcessingMode = .formatted
    @State private var runningApps: [AppInfo] = []
    @State private var installedApps: [AppInfo] = []
    @State private var searchText: String = ""
    @State private var isLoading = false
    
    private let contextDetector = ContextDetector.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Application")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Tab picker
            Picker("Source", selection: $selectedTab) {
                Text("Running Apps").tag(0)
                Text("All Applications").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search apps...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            
            Divider()
                .padding(.top, 8)
            
            // App list
            if isLoading {
                ProgressView("Loading apps...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedApp) {
                    ForEach(filteredApps) { app in
                        AddAppRow(app: app, isSelected: selectedApp?.bundleIdentifier == app.bundleIdentifier)
                            .tag(app)
                            .onTapGesture {
                                selectedApp = app
                            }
                    }
                }
                .listStyle(.plain)
            }
            
            Divider()
            
            // Mode selection
            if selectedApp != nil {
                HStack {
                    Text("Processing Mode:")
                    Picker("", selection: $selectedMode) {
                        ForEach(ProcessingMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                Divider()
            }
            
            // Footer buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Add") {
                    if let app = selectedApp {
                        onAdd(app, selectedMode)
                        dismiss()
                    }
                }
                .keyboardShortcut(.return)
                .disabled(selectedApp == nil)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .onAppear {
            loadApps()
        }
        .onChange(of: selectedTab) { _ in
            loadApps()
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredApps: [AppInfo] {
        let apps = selectedTab == 0 ? runningApps : installedApps
        
        if searchText.isEmpty {
            return apps
        }
        
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Loading
    
    private func loadApps() {
        isLoading = true
        
        Task {
            if selectedTab == 0 {
                // Running apps (fast)
                let apps = contextDetector.getRunningApps()
                await MainActor.run {
                    runningApps = apps
                    isLoading = false
                }
            } else {
                // Installed apps (slower, load in background)
                if installedApps.isEmpty {
                    let apps = contextDetector.getInstalledApps()
                    await MainActor.run {
                        installedApps = apps
                        isLoading = false
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                    }
                }
            }
        }
    }
}

// MARK: - Add App Row

struct AddAppRow: View {
    let app: AppInfo
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // App icon
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "app")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
            }
            
            // App info
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.body)
                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
}

// MARK: - Preview

#Preview {
    AddAppSheet { app, mode in
        print("Added \(app.name) with mode \(mode.displayName)")
    }
}
