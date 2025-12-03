//
//  RecordingOverlayWindow.swift
//  WhisperType
//
//  An NSPanel wrapper that displays the waveform visualization
//  as a floating overlay near the menu bar during recording.
//

import AppKit
import SwiftUI
import Combine

// MARK: - Audio Level State

/// Observable state for audio level, shared between the window and SwiftUI view
class RecordingOverlayState: ObservableObject {
    @Published var audioLevel: Float = 0.0
    @Published var isActive: Bool = true
}

// MARK: - Recording Overlay Window

@MainActor
class RecordingOverlayWindow {
    
    // MARK: - Properties
    
    private var panel: NSPanel?
    private var hostingView: NSHostingView<RecordingOverlayContentView>?
    
    /// Shared state for audio level
    let state = RecordingOverlayState()
    
    /// Whether the overlay is currently visible
    private(set) var isVisible = false
    
    // MARK: - Constants
    
    private let overlayWidth: CGFloat = 120
    private let overlayHeight: CGFloat = 32
    private let menuBarOffset: CGFloat = 8 // Distance below menu bar
    
    // MARK: - Initialization
    
    init() {
        setupPanel()
    }
    
    // MARK: - Panel Setup
    
    private func setupPanel() {
        // Create the panel with specific configuration
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: overlayWidth, height: overlayHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Configure panel properties
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        
        // Create the SwiftUI content view with observable state
        let contentView = RecordingOverlayContentView(state: state)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        
        panel.contentView = hostingView
        
        self.panel = panel
        self.hostingView = hostingView
    }
    
    // MARK: - Audio Level Update
    
    /// Update the audio level for waveform visualization
    func updateAudioLevel(_ level: Float) {
        state.audioLevel = level
    }
    
    // MARK: - Show/Hide
    
    /// Show the overlay with fade-in animation
    func show() {
        guard let panel = panel else { return }
        guard !isVisible else { return }
        
        print("RecordingOverlayWindow: Showing overlay")
        
        // Reset state
        state.audioLevel = 0
        state.isActive = true
        
        // Position the panel
        positionPanel()
        
        // Prepare for animation
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        
        // Animate in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
        
        isVisible = true
    }
    
    /// Hide the overlay with fade-out animation
    func hide() {
        guard let panel = panel else { return }
        guard isVisible else { return }
        
        print("RecordingOverlayWindow: Hiding overlay")
        
        isVisible = false
        state.isActive = false
        
        // Animate out
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor [weak self] in
                self?.panel?.orderOut(nil)
            }
        }
    }
    
    // MARK: - Positioning
    
    /// Position the panel centered horizontally below the menu bar
    private func positionPanel() {
        guard let panel = panel else { return }
        
        // Get the screen with the menu bar (primary screen or screen with current focus)
        guard let screen = getMenuBarScreen() else { return }
        
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        
        // Calculate menu bar height (difference between screen frame and visible frame at top)
        let menuBarHeight = screenFrame.maxY - visibleFrame.maxY
        
        // Calculate position: centered horizontally, just below menu bar
        let x = screenFrame.midX - (overlayWidth / 2)
        let y = screenFrame.maxY - menuBarHeight - overlayHeight - menuBarOffset
        
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    /// Get the screen where the menu bar is located
    private func getMenuBarScreen() -> NSScreen? {
        // The menu bar is always on the screen containing the main menu bar
        // For simplicity, use the main screen (where the menu bar is shown)
        return NSScreen.main ?? NSScreen.screens.first
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
    }
    
    deinit {
        print("RecordingOverlayWindow: Deinit")
    }
}
