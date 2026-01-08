//
//  PermissionStatusView.swift
//  WhisperType
//
//  View for displaying and managing Screen Recording permission status.
//  Required for system audio capture in meeting recording.
//

import SwiftUI

/// View displaying Screen Recording permission status with action button
@available(macOS 12.3, *)
struct PermissionStatusView: View {
    
    @StateObject private var permissionManager = ScreenRecordingPermissionManager()
    
    var body: some View {
        Section {
            HStack {
                statusIcon
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Screen Recording Permission")
                        .font(.body)
                    
                    Text(statusDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                actionButton
            }
            .padding(.vertical, 4)
            
            if permissionManager.permissionState == .denied {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Required to capture audio from meetings, calls, and other apps.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Label("Meeting Recording", systemImage: "rectangle.inset.filled.and.person.filled")
        }
        .onAppear {
            Task {
                await permissionManager.checkPermission()
            }
        }
    }
    
    // MARK: - Status Icon
    
    @ViewBuilder
    private var statusIcon: some View {
        switch permissionManager.permissionState {
        case .granted:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
        case .denied:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.title2)
        case .notDetermined:
            Image(systemName: "questionmark.circle.fill")
                .foregroundColor(.orange)
                .font(.title2)
        }
    }
    
    // MARK: - Status Description
    
    private var statusDescription: String {
        switch permissionManager.permissionState {
        case .granted:
            return "Enabled - System audio capture is available"
        case .denied:
            return "Disabled - Click to enable in System Settings"
        case .notDetermined:
            return "Not configured - Grant permission to capture system audio"
        }
    }
    
    // MARK: - Action Button
    
    @ViewBuilder
    private var actionButton: some View {
        switch permissionManager.permissionState {
        case .granted:
            Text("Enabled")
                .font(.caption)
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.15))
                .cornerRadius(6)
        case .denied, .notDetermined:
            Button(action: openSystemSettings) {
                Text("Open Settings")
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
    
    // MARK: - Actions
    
    private func openSystemSettings() {
        permissionManager.openSettings()
    }
}

// MARK: - Permission Manager

@available(macOS 12.3, *)
@MainActor
class ScreenRecordingPermissionManager: ObservableObject {
    
    @Published var permissionState: ScreenRecordingPermission = .notDetermined
    @Published var isChecking: Bool = false
    
    private var systemAudioCapture: SystemAudioCapture?
    
    init() {
        systemAudioCapture = SystemAudioCapture()
    }
    
    func checkPermission() async {
        isChecking = true
        defer { isChecking = false }
        
        guard let capture = systemAudioCapture else {
            permissionState = .notDetermined
            return
        }
        
        permissionState = await capture.checkPermission()
    }
    
    func openSettings() {
        systemAudioCapture?.openSystemSettings()
    }
}

// MARK: - Compact Permission Badge

/// Smaller inline permission indicator for use in other views
@available(macOS 12.3, *)
struct PermissionBadge: View {
    
    let state: ScreenRecordingPermission
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(badgeColor)
                .frame(width: 8, height: 8)
            
            Text(badgeText)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var badgeColor: Color {
        switch state {
        case .granted: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        }
    }
    
    private var badgeText: String {
        switch state {
        case .granted: return "Screen Recording Enabled"
        case .denied: return "Screen Recording Disabled"
        case .notDetermined: return "Screen Recording Not Set"
        }
    }
}

// MARK: - Preview

@available(macOS 12.3, *)
#Preview {
    Form {
        PermissionStatusView()
    }
    .formStyle(.grouped)
    .frame(width: 450, height: 200)
}
