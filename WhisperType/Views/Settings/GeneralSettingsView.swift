//
//  GeneralSettingsView.swift
//  WhisperType
//
//  General settings tab: launch at login, microphone, audio feedback, about.
//

import SwiftUI
import AVFoundation
import ServiceManagement

struct GeneralSettingsView: View {
    
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var microphoneManager = MicrophoneManager()
    
    @State private var launchAtLoginEnabled: Bool = false
    @State private var launchAtLoginError: String?
    
    var body: some View {
        Form {
            // MARK: - Startup Section
            Section {
                Toggle("Launch WhisperType at login", isOn: $launchAtLoginEnabled)
                    .onChange(of: launchAtLoginEnabled) { newValue in
                        updateLaunchAtLogin(newValue)
                    }
                
                if let error = launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            } header: {
                Label("Startup", systemImage: "power")
            }

            // MARK: - Audio Input Section
            Section {
                Picker("Microphone", selection: $settings.selectedMicrophoneId) {
                    Text("System Default")
                        .tag(nil as String?)
                    
                    ForEach(microphoneManager.availableMicrophones, id: \.uniqueID) { device in
                        Text(device.localizedName)
                            .tag(device.uniqueID as String?)
                    }
                }
                .pickerStyle(.menu)
                
                if microphoneManager.availableMicrophones.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("No microphones found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button("Refresh Microphones") {
                    microphoneManager.refreshDevices()
                }
                .buttonStyle(.link)
                .font(.caption)
            } header: {
                Label("Audio Input", systemImage: "mic")
            }

            // MARK: - Audio Feedback Section
            Section {
                Toggle("Play sound when recording starts/stops", isOn: $settings.playAudioFeedback)
            } header: {
                Label("Feedback", systemImage: "speaker.wave.2")
            }
            
            // MARK: - About Section
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Constants.appVersion)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.buildNumber)
                        .foregroundColor(.secondary)
                }
                
                Link(destination: Constants.URLs.githubRepo) {
                    HStack {
                        Text("GitHub Repository")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                }
                
                Link(destination: Constants.URLs.documentation) {
                    HStack {
                        Text("Documentation")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Label("About", systemImage: "info.circle")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadLaunchAtLoginStatus()
        }
    }

    // MARK: - Launch at Login
    
    private func loadLaunchAtLoginStatus() {
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        settings.launchAtLogin = launchAtLoginEnabled
    }
    
    private func updateLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        
        do {
            if enabled {
                try SMAppService.mainApp.register()
                print("GeneralSettings: Launch at login enabled")
            } else {
                try SMAppService.mainApp.unregister()
                print("GeneralSettings: Launch at login disabled")
            }
            settings.launchAtLogin = enabled
        } catch {
            launchAtLoginError = "Failed to update: \(error.localizedDescription)"
            print("GeneralSettings: Launch at login error: \(error)")
            // Revert the toggle
            launchAtLoginEnabled = !enabled
        }
    }
}

// MARK: - Microphone Manager

class MicrophoneManager: ObservableObject {
    @Published var availableMicrophones: [AVCaptureDevice] = []
    
    init() {
        refreshDevices()
    }
    
    func refreshDevices() {
        // Request permission if needed
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            loadDevices()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.loadDevices()
                    }
                }
            }
        default:
            print("MicrophoneManager: Audio permission denied")
        }
    }
    
    private func loadDevices() {
        // Use the simpler devices(for:) method which works on macOS 13.0+
        let devices = AVCaptureDevice.devices(for: .audio)
        
        DispatchQueue.main.async {
            self.availableMicrophones = devices
            print("MicrophoneManager: Found \(self.availableMicrophones.count) microphones")
            for mic in self.availableMicrophones {
                print("  - \(mic.localizedName) (\(mic.uniqueID))")
            }
        }
    }
}


// MARK: - Bundle Extension

extension Bundle {
    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Preview

#Preview {
    GeneralSettingsView()
        .frame(width: 450, height: 400)
}
