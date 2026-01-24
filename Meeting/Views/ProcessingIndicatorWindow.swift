//
//  ProcessingIndicatorWindow.swift
//  WhisperType
//
//  Shows a processing indicator while the final transcript is being generated.
//

import AppKit
import SwiftUI

/// Observable state for the processing indicator
/// Using ObservableObject allows us to update content without recreating the SwiftUI view,
/// which prevents autorelease pool crashes from zombie objects during view teardown (especially with .repeatForever animations).
@MainActor
class ProcessingIndicatorState: ObservableObject {
    @Published var duration: String = ""
    @Published var chunkCount: Int = 0
    @Published var isVisible: Bool = false
    
    func update(duration: String, chunkCount: Int) {
        self.duration = duration
        self.chunkCount = chunkCount
        self.isVisible = true
    }
    
    func reset() {
        self.isVisible = false
    }
}

/// Manages the processing indicator window shown during final transcription
/// SINGLETON: This class is reused across sessions to prevent autorelease pool crashes.
@MainActor
class ProcessingIndicatorWindow {
    
    // MARK: - Properties
    
    private var window: NSWindow?
    
    /// Shared state - persists across sessions
    private let state = ProcessingIndicatorState()
    
    // MARK: - Singleton
    
    static let shared = ProcessingIndicatorWindow()
    
    private init() {
        // Initialize window immediately
        setupWindow()
    }
    
    // MARK: - Setup
    
    private func setupWindow() {
        // Create SwiftUI view with persistent state
        let view = ProcessingIndicatorView(state: state)
        
        // Create window
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 150),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        newWindow.title = "Processing Recording"
        newWindow.titlebarAppearsTransparent = true
        newWindow.isMovableByWindowBackground = true
        newWindow.contentView = NSHostingView(rootView: view)
        newWindow.center()
        newWindow.level = .floating
        newWindow.isReleasedWhenClosed = false
        
        self.window = newWindow
    }
    
    // MARK: - Show/Hide
    
    /// Show the processing indicator
    func show(duration: String, chunkCount: Int) {
        // Update state (triggers SwiftUI update)
        state.update(duration: duration, chunkCount: chunkCount)
        
        guard let window = window else { return }
        
        // Show window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        print("ProcessingIndicatorWindow: Showing")
    }
    
    /// Hide the processing indicator (keeps window alive to avoid animation teardown crash)
    func hide() {
        // Update state
        state.reset()
        
        guard let window = window else { return }
        
        // Just hide the window - never close or deallocate it
        window.orderOut(nil)
        
        print("ProcessingIndicatorWindow: Hidden")
    }
}

// MARK: - SwiftUI View

struct ProcessingIndicatorView: View {
    @ObservedObject var state: ProcessingIndicatorState
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Processing Recording...")
                .font(.headline)
            
            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.small)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duration: \(state.duration)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if state.chunkCount > 1 {
                        Text("Processing \(state.chunkCount) chunks...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 320, height: 150)
        .background(.regularMaterial)
    }
}
