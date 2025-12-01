//
//  WhisperTypeApp.swift
//  WhisperType
//
//  Main application entry point.
//

import SwiftUI

@main
struct WhisperTypeApp: App {

    // Use NSApplicationDelegateAdaptor to integrate AppDelegate with SwiftUI lifecycle
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty scene - app runs as menu bar only (LSUIElement = YES)
        // We could add Settings scene here in the future
        Settings {
            EmptyView()
        }
    }
}
