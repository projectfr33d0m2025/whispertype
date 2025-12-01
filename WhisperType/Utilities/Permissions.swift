//
//  Permissions.swift
//  WhisperType
//
//  Handles checking and requesting system permissions.
//

import Foundation
import AVFoundation
import ApplicationServices

@MainActor
class Permissions: ObservableObject {

    static let shared = Permissions()

    @Published var microphonePermission: PermissionStatus = .notDetermined
    @Published var accessibilityPermission: PermissionStatus = .notDetermined

    private init() {
        checkAllPermissions()
    }

    // MARK: - Permission Status

    enum PermissionStatus {
        case notDetermined
        case granted
        case denied

        var isGranted: Bool {
            return self == .granted
        }
    }

    // MARK: - Check Permissions

    func checkAllPermissions() {
        checkMicrophonePermission()
        checkAccessibilityPermission()
    }

    func checkMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            microphonePermission = .granted
        case .denied, .restricted:
            microphonePermission = .denied
        case .notDetermined:
            microphonePermission = .notDetermined
        @unknown default:
            microphonePermission = .notDetermined
        }
    }

    func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        accessibilityPermission = trusted ? .granted : .denied
    }

    // MARK: - Request Permissions

    func requestMicrophonePermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
        checkMicrophonePermission()
        return microphonePermission.isGranted
    }

    func requestAccessibilityPermission() {
        // Open System Settings to Accessibility pane
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)

        // Check again after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkAccessibilityPermission()
        }
    }

    // MARK: - Open System Settings

    func openSystemSettings(for permission: PermissionType) {
        switch permission {
        case .microphone:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        case .accessibility:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    enum PermissionType {
        case microphone
        case accessibility
    }

    // MARK: - Convenience

    var allPermissionsGranted: Bool {
        return microphonePermission.isGranted && accessibilityPermission.isGranted
    }

    var hasAnyPermissionDenied: Bool {
        return microphonePermission == .denied || accessibilityPermission == .denied
    }
}
